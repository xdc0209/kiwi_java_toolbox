# Kiwi Java 工具箱

![kiwi and kiwi bird](images/kiwi_and_kiwi_bird.png)  

## 工具简介

Kiwi Java 工具箱。  

本工具用于定位**内存泄漏**、**CPU占用过高**等问题。  

## 功能说明

1. 一键式收集Java进程的问题定位信息，包括：Thread Stack和Heap Dump等。  
2. 监控Java进程使用的CPU，当占用率过高时，自动收集Top信息和Thread Stack。  
3. 启动、停止、查询、导出飞行记录。  

## 使用方法

将工具上传到Linux服务器的任意目录，并进行解压。  

注意：须确保Java进程用户有权限访问此工具目录。推荐放在/home目录，这个目录一般是满足权限要求的。  

1. 解压：unzip -o kiwi_java_toolbox-*.zip -d /home  
2. 收集信息：sh /home/kiwi_java_toolbox/java_info_collect.sh  
3. 监控进程：sh /home/kiwi_java_toolbox/java_cpu_monitor.sh.sh  
4. 飞行记录：sh /home/kiwi_java_toolbox/java_flight_recorder.sh  

## 后续步骤

1. 内存泄露：使用工具分析Head Dump，[本地工具MemoryAnalyzer](http://www.eclipse.org/mat)。  
2. CPU过高：使用工具分析Thread Stack，[在线工具](http://gceasy.io/index.jsp)，[本地工具IBM_Thread_and_Monitor_Dump_Analyzer_for_Java](https://www.ibm.com/developerworks/community/groups/service/html/communitystart?communityUuid=2245aa39-fa5c-4475-b891-14c205f7333c)。  
3. 性能优化：使用工具分析飞行记录，[本地工具Java Mission Control](http://www.oracle.com/technetwork/java/javaseproducts/mission-control/index.html)。  

## Java常见问题

1. 是否存在线程的占用cpu过高。根据jstack和top的结果判断。  
2. 是否存在多线程使用HashMap而导致的死循环。查看不同时间的多个线程堆栈，是否存在相同的java.util.HashMap堆栈。  
3. 是否存在数据库连接池枯竭的问题。查看堆栈中org.apache.commons.pool.impl.GenericObjectPool.borrowObject的数量是否大于5个(不绝对，只是参考值)。  
4. 是否存在死锁。查看堆栈中是否包含deadlock关键字。  
5. 是否存在内存溢出。查看GC信息中老年代Old区占用百分比是否维持在95%以上(不绝对，只是初步判断)。  

## 附1：核心原理

本工具底层仍然是Jdk的工具，只是对常见的手工的操作流程的自动化封装。  

很多公司的产品是跑在Jre上的，而不是Jdk上。定位问题的时候需要上传Jdk。  

由于Jdk的文件体积比较大，而且包含了很多定位问题不需要的东西，本工具对Jdk进行了提取：  

1. libattach.so：连接Java进程使用的类库。  
2. tools.jar：Jdk中工具包。  

为了达到最大兼容性，本工具对Jdk的使用采用如下逻辑：  

1. 如果Java进程是Jdk，则使用Java进程的Jdk。  
2. 如果Java进程是Jre，则使用本工具内置的Jdk。另外，本工具也进行版本校验，如果Java进程和内置的Jdk的大版本不一致，则直接提示并退出。  

## 附2：JDK工具使用注意事项

1. 常见错误1：  

   问题原因：当前操作系统用户与Java进程用户不一致，导致权限不够。  
   解决方案：请合理修改工具目录的属主和权限，并且切换用户。  

   ```java
   java.io.IOException: well-known file is not secure
       at sun.tools.attach.LinuxVirtualMachine.checkPermissions(Native Method)
       at sun.tools.attach.LinuxVirtualMachine.<init>(LinuxVirtualMachine.java:117)
       at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:63)
       at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:213)
       at sun.tools.jcmd.JCmd.executeCommandForPid(JCmd.java:140)
       at sun.tools.jcmd.JCmd.main(JCmd.java:129)
   ```

2. 常见错误2：  

   问题原因：Jdk工具的的版本与Java进程的版本不一致。  
   解决方案：请使用匹配版本的Jdk。一般情况下，大版本匹配就可以了(如1.8.0_111与1.8.0_162的大版本都是1.8.0)，不行的话就要精确匹配。  
   更新本工具的Jdk库：sh kiwi_java_toolbox/lib/jdk_lib_extract.sh <jdk_path>  
   查询本工具的Jdk库：vi kiwi_java_toolbox/lib/jdk-*/tools.jar --> com\sun\tools\javac\resources\version.class  

   ```java
   com.sun.tools.attach.AttachNotSupportedException: Unable to open socket file: target process not responding or HotSpot VM not loaded
       at sun.tools.attach.LinuxVirtualMachine.<init>(LinuxVirtualMachine.java:106)
       at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:63)
       at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:213)
       at sun.tools.jcmd.JCmd.executeCommandForPid(JCmd.java:140)
       at sun.tools.jcmd.JCmd.main(JCmd.java:129)
   ```

3. 常见错误3：  

   问题原因：在java.library.path未找到libattach.so。  
   解决方案：正确设置java的启动参数：-Djava.library.path=<java_library_path>。  

   ```java
   java.lang.UnsatisfiedLinkError: no attach in java.library.path
       at java.lang.ClassLoader.loadLibrary(Unknown Source)
       at java.lang.Runtime.loadLibrary0(Unknown Source)
       at java.lang.System.loadLibrary(Unknown Source)
       at sun.tools.attach.LinuxVirtualMachine.<clinit>(LinuxVirtualMachine.java:336)
       at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:63)
       at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:213)
       at sun.tools.jstack.JStack.runThreadDump(JStack.java:159)
       at sun.tools.jstack.JStack.main(JStack.java:112)
   ```

## 捐赠

如果你觉得Kiwi对你有帮助，或者想对我微小工作的一点资瓷，欢迎给我捐赠。  

<img src="images/qrcode_alipay.jpg"><img src="images/qrcode_wechat.jpg">  
