# Java内存溢出异常

在Sun JDK中运行时，Java程序有可能出现如下几种OOM错误：  

1. java.lang.OutOfMemoryError: unable to create new native thread  

   当调用new Thread时，如已创建不了线程了，则会抛出此错误，如果是JDK内部必须创建成功的线程，那么会造成Java进程退出，如果是用户线程，则仅抛出OOM，创建不了的原因通常是创建了太多线程，耗尽了内存，通常可通过减少创建的线程数，或通过-Xss调小线程所占用的栈大小来减少对Java对外内存的消耗。  

2. java.lang.OutOfMemoryError: request bytes for . Out of swap space?  

   当JNI模块或JVM内部进行malloc操作(例如GC时做mark)时，需要消耗堆外的内存，如此时Java进程所占用的地址空间超过限制(例如windows: 2G，Linux: 3G)，或物理内存、swap区均使用完毕，那么则会出现此错误，当出现此错误时，Java进程将会退出。  

3. java.lang.OutOfMemoryError: Java heap space  

   这是**最常见的OOM错误**，当通过new创建对象或数组时，如Java Heap空间不足(新生代不足，触发minor GC，还是不够，触发Full GC，还是不够)，则抛出此错误。  

4. java.lang.OutOfMemoryError: GC overhead limit execeeded  

   当通过new创建对象或数组时，如Java Heap空间不足，且GC所使用的时间占了程序总时间的98%，且Heap剩余空间小于2%，则抛出此错误，以避免Full GC一直执行，可通过-XX:UseGCOverheadLimit来决定是否开启这种策略，可通过-XX:GCTimeLimit和-XX:GCHeapFreeLimit来控制百分比。  

5. java.lang.OutOfMemoryError: PermGen space  

   当加载class时，在进行了Full GC后如PermGen空间仍然不足，则抛出此错误。  

对于以上几种OOM错误，其中容易造成严重后果的是Out of swap space这种，因为这种会造成Java进程退出，而其他几种只要不是在main线程抛出的，就不会造成Java进程退出。  
