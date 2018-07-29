# Java进程内存结构

参考：<http://markshow.iteye.com/blog/2020516?utm_source=jiancool>  

## 总述

**堆、方法区(持久代)、直接内存、JAVA栈、代码缓冲区**、程序计数器、本地方法栈、运行时常量池。重点关注一下**加粗**部分。  

## 堆

是被所有线程共享的一块内存区域，在虚拟机启动时创建。此内存区域的唯一目的就是存放对象实例，由-Xms和-Xmx参数指定初始化值和最大值。堆内存分为：Young(年轻代、PSYoungGen)和Tenured(年老代、PSOldGen)。Young(年轻代、PSYoungGen)分为eden space、survivor space。survivor space分为：from space、to space。大部分对象在eden space中生成。当eden space满时，还存活的对象将被复制到survivor space。当survivor space满时，还存活的对象将被复制Tenured(年老代、PSOldGen)。survivor space中把空的命名为：to space，另一个命名为：from space。**如果这部分不够用，会向错误流输出提示：java.lang.OutOfMemoryError: Java heap space。**  

## 方法区(持久代)

也叫PSPermGen，是各个线程共享的内存区域，它用于存储已被虚拟机加载的类信息、常量、静态变量、即时编译器编译后的代码等数据。虽然Java虚拟机规范把方法区描述为堆的一个逻辑部分，但是它却有一个别名叫做Non-Heap(非堆)，目的应该是与Java堆区分开来。使用-XX:PermSize和-XX:MaxPermSize指定初始化值和最大值。**如果这部分不够用，会向错误流输出：java.lang.OutOfMemoryError: PermGen space。注意：动态代理创建出来的类信息也会放入此内存空间。**  

## 直接内存

并不是虚拟机运行时数据区的一部分，也不是Java虚拟机规范中定义的内存区域，但是这部分内存也被频繁地使用。在JDK 1.4 中新加入了NIO(New Input/Output)类，引入了一种基于通道(Channel)与缓冲区(Buffer)的I/O方式，它可以使用Native函数库直接分配堆外内存，然后通过一个存储在Java堆里面的DirectByteBuffer对象作为这块内存的引用进行操作。这样能在一些场景中显著提高性能，因为避免了在Java堆和Native堆中来回复制数据。显然，本机直接内存的分配不会受到Java堆大小的限制，但是，既然是内存，则肯定还是会受到本机总内存(包括RAM及SWAP区或者分页文件)的大小及处理器寻址空间的限制。使用-XX:MaxDirectMemorySize配置最终大小。**如果有文件句柄打开忘记关闭此处内存会不断上涨，使用top命令查看时体现在VIRT内存不断上涨。**  

## JAVA栈

是线程私有的，用于存储局部变量表、操作栈、动态链接、方法出口等信息。每一个方法被调用直至执行完成的过程，就对应着一个栈帧在虚拟机栈中从入栈到出栈的过程。使用-Xss配置大小。**如果这个栈内存不够用，会有异常抛出：java.lang.StackOverflowError。**  

## 代码缓冲区(Code Cache)

主要用于存放JIT所编译的代码，使用-XX:ReservedCodeCacheSize配置大小。这个很少会不够使用，而且运行时很固定。一般使用jconsole观察这部分内存实际大小，然后配置-XX:ReservedCodeCacheSize，避免内存浪费。**如果不够用会提示：Java HotSpot(TM) Client VM warning: CodeCache is full. Compiler has been disabled.**  

## top命令中的RES为什么明显大于Xms设置的值？

总内存 ≈ Xmx + Metaspace使用量(受MaxMetaspaceSize限制) + CodeCache(受ReservedCodeCacheSize限制) + Xss*线程数 + NIO(受MaxDirectMemorySize限制，著名的Netty框架就基于NIO实现的)  
