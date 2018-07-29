package com.xdc.basic.api.jvm.test.stub;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import com.xdc.basic.api.json.jsonsmart.Student;

public class OutOfMemoryTestStub
{
    public static final List<Student> STUDENTS = new ArrayList<Student>();

    public static void main(String[] args) throws InterruptedException
    {
        Thread.sleep(10 * 1000);

        ExecutorService newFixedThreadPool = Executors.newFixedThreadPool(2);
        newFixedThreadPool.execute(new Runnable()
        {
            @Override
            public void run()
            {
                creatStudentWithCache();
            }
        });

        newFixedThreadPool.execute(new Runnable()
        {
            @Override
            public void run()
            {
                createStudentWithNoCache();
            }
        });
    }

    public static void creatStudentWithCache()
    {
        for (int i = 0; i < Integer.MAX_VALUE; i++)
        {
            if (i % 1000000 == 0)
            {
                try
                {
                    Thread.sleep(1);
                }
                catch (InterruptedException e)
                {
                    e.printStackTrace();
                }
            }

            STUDENTS.add(new Student());
        }
    }

    public static void createStudentWithNoCache()
    {
        for (int i = 0; i < Integer.MAX_VALUE; i++)
        {
            if (i % 1000000 == 0)
            {
                try
                {
                    Thread.sleep(1);
                }
                catch (InterruptedException e)
                {
                    e.printStackTrace();
                }
            }

            new Student();
        }
    }
}
