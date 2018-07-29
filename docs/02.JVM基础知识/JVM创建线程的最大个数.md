# JVM创建线程的最大个数

摘自：<http://sesame.iteye.com/blog/622670>  
参考：<http://blog.sina.com.cn/s/blog_660503910101auh3.html>  

## 公式

Number of threads = (MaxProcessMemory - JVMMemory - ReservedOsMemory) / (ThreadStackSize)  

## 解释

| 名称             | 解释                                           |
| ---------------- | ---------------------------------------------- |
| MaxProcessMemory | 指的是一个进程的最大内存，也就是OS的最大内存。 |
| JVMMemory        | Java虚拟机占用内存(包括堆内内存、堆外内存)。   |
| ReservedOsMemory | 保留的操作系统内存。                           |
| ThreadStackSize  | 线程栈的大小。                                 |

## 提示

在Java语言里，当你创建一个线程的时候，虚拟机会在JVM内存创建一个Thread对象同时创建一个操作系统线程，而这个系统线程的内存用的不是JVMMemory，而是系统中剩下的内存(MaxProcessMemory - JVMMemory - ReservedOsMemory)。  

## 注意

除了内存的限制，操作系统也是有限制的：<http://www.2cto.com/os/201405/305281.html>  
