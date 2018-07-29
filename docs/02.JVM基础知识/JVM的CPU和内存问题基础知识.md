# JVM的CPU和内存问题基础知识

## Thread Dump和Heap Dump的概念

在故障定位(尤其是Out of Memory)和性能分析的时候，经常会用到一些文件来帮助我们排除问题。这些文件记录了JVM运行期间的线程执行、内存占用等情况，这就是我们常说的dump文件(中文翻译为转储文件)。常用的有Thread Dump和Heap Dump。Thread Dump也叫Javacore，或Java Dump，或Thread Stack。我们可以这么理解：Thread Dump是记录CPU信息的，Heap Dump是记录内存信息的。  

1. **Thread Dump**：Thread Dump文件主要保存的是Java应用中各线程在某一时刻的运行的位置，即执行到哪一个类的哪一个方法哪一个行上。Thread Dump是一个文本文件，打开后可以看到每一个线程的执行栈，以stacktrace的方式显示。通过对Thread Dump的分析可以得到应用是否“卡”在某一点上，即在某一点运行的时间太长，如数据库查询，长期得不到响应，最终导致系统崩溃。单个的Thread Dump文件一般来说是没有什么用处的，因为它只是记录了某一个绝对时间点的情况。比较有用的是，线程在一个时间段内的执行情况。两个以上Thread Dump文件在分析时特别有效，因为它可以看出在先后时间点上，线程执行的位置，如果发现先后同一线程都执行在同一位置，则说明此处可能有问题，因为程序运行是极快的，如果两次以上均在某一点上，说明这一点的耗时是很大的。通过对Thread Dump进行分析，查出原因，进而解决问题。在实际应用过程中，建议产生三次Thread Dump信息。  
2. **Heap Dump**：Heap Dump文件是一个二进制文件，它保存了某一时刻JVM堆中对象使用情况。HeapDump文件是指定时刻的Java堆栈的快照，是一种镜像文件，这个文件最重要的作用就是分析系统是否存在堆栈溢出的情况。Heap Analyzer工具通过分析HeapDump文件，确定哪些对象占用了太多的堆栈空间，进而发现导致内存泄露或者可能引起内存泄露的对象。  

## Thread Dump和Heap Dump的获取

1. 获取Thread Dump文件  

   - 使用$JDK_HOME/bin/jstack -l <pid> >thread_dump.txt  

   - 使用$JDK_HOME/bin/jcosole或$JDK_HOME/bin/jvisualvm。  

   - 通过向Java进程发送一个QUIT信号，Java虚拟机收到该信号之后，将系统当前的Java线程调用堆栈打印出来。  

     - Windows：在运行Java的控制台窗口上按Ctrl+Break组合键。  
     - Linux：执行kill -3 <pid>或在控制台中敲：Ctrl-\。在Linux下如果是以后台方式启动的Java进程，打印的线程堆栈会和其它屏幕输出一样，在控制台已经被关闭的情况下，这些信息你无法"捡"回它们。因此为了避免这种情况，在启动时系统时最好做一下重定向。除了重定向，下面的参数也可以达到同样的效果：-XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=$APP_HOME/logs/jvm.log  

2. 获取Heap Dump文件  

   - 使用$JDK_HOME/bin/jmap -dump:format=b,file=heap_dump.hprof <pid>  
   - 使用$JDK_HOME/bin/jcosole中的MBean，位置jcosole>MBean>com.sun.management>HotSpotDiagnostic>操作>dumpHeap，点击dumpHeap按钮。生成的Heap Dump文件在Java应用的根目录下面。  
   - 使用$JDK_HOME/bin/jvisualvm，位置jvisualvm>线程>线程Dmup  
   - 配置应用的启动参数：-XX:+HeapDumpOnOutOfMemoryError -XX:ErrorFile=$APP_HOME/serviceability/error.log -XX:HeapDumpPath=$APP_HOME/serviceability/heap_dump.hprof，当应用抛出OutOfMemoryError时生成Heap Dump文件。  

## Thread Dump和Heap Dump的分析

1. 分析Thread Dump文件  

   Thread Dump文件是文本文件，无需工具，直接打开查看。  

2. 分析Heap Dump文件  

   Heap Dump文件是一个二进制文件，需要借助工具分析，常见的分析工具有：  

   - jhat: JDK自带工具，工具比较简陋，不推荐使用。  
   - Eclipse Memory Analyzer Tool(简称MAT): MAT是一款优秀的Heap Dump分析工具，能够帮我们快速定位内存泄露问题, 推荐使用。  
   - IBM HeapAnalyzer：听说跟MAT一样强大，没用过。  

   注意事项：  

   1. 大多数情况下JVM Crash之后生成的Heap Dump非常大，1G-4G不等，打开Heap Dump要求机器性能较好，并且机器的内存大小不能小于Heap Dump文件的大小。  

   2. 使用IBM HeapAnalyzer分析时分配的内存最好为Heap Dump文件的1.5-2倍。另外如果Heap Dump大于2G，必须使用64位的机器打开，32位最大只能分配2G的内存。  
      Tips: 64位机器确定方法：CPU，OS，JDK均为64位才能确定是64位机器。  

## Thread Dump的详解

Java线程堆栈是一个给定时间的线程快照，它能向你提供了Java线程的完整清单。  

1. JVM线程  

   在线程中，有一些JVM内部的后台线程，来执行譬如垃圾回收，或者低内存的检测等等任务，这些线程往往在JVM初始化的时候就存在，如下所示：  

   ```java
   "Low Memory Detector" daemon prio=10 tid=0x081465f8 nid=0x7 runnable [0x00000000..0x00000000]
   "CompilerThread0" daemon prio=10 tid=0x08143c58 nid=0x6 waiting on condition [0x00000000..0xfb5fd798]
   "Signal Dispatcher" daemon prio=10 tid=0x08142f08 nid=0x5 waiting on condition [0x00000000..0x00000000]

   "Finalizer" daemon prio=10 tid=0x08137ca0 nid=0x4 in Object.wait() [0xfbeed000..0xfbeeddb8]
   at java.lang.Object.wait(Native Method)
   - waiting on <0xef600848> (a java.lang.ref.ReferenceQueue$Lock)
   at java.lang.ref.ReferenceQueue.remove(ReferenceQueue.java:116)
   - locked <0xef600848> (a java.lang.ref.ReferenceQueue$Lock)
   at java.lang.ref.ReferenceQueue.remove(ReferenceQueue.java:132)
   at java.lang.ref.Finalizer$FinalizerThread.run(Finalizer.java:159)

   "Reference Handler" daemon prio=10 tid=0x081370f0 nid=0x3 in Object.wait() [0xfbf4a000..0xfbf4aa38]
   at java.lang.Object.wait(Native Method)
   - waiting on <0xef600758> (a java.lang.ref.Reference$Lock)
   at java.lang.Object.wait(Object.java:474)
   at java.lang.ref.Reference$ReferenceHandler.run(Reference.java:116)
   - locked <0xef600758> (a java.lang.ref.Reference$Lock)

   "VM Thread" prio=10 tid=0x08134878 nid=0x2 runnable
   "VM Periodic Task Thread" prio=10 tid=0x08147768 nid=0x8 waiting on condition
   ```

2. 用户线程  

   我们更多的是要观察用户级别的线程(我们的业务线程)。  

3. 线程详解  

   每一个Java线程都会给你如下信息:  

   | 名称                   | 说明                                                                                                                                                    | 举例                                                                                               |
   | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
   | 线程的名称             | 经常被中间件厂商用来识别线程的标识，一般还会带上被分配的线程池名称以及状态(运行，阻塞等等)。                                                            |                                                                                                    |
   | 线程类型&优先级        | 中间件程序一般以后台守护的形式创建他们的线程，这意味着这些线程是在后台运行的，它们会向它们的用户提供服务。                                              | daemon prio=3                                                                                      |
   | Java线程ID             | 这是通过java.lang.Thread.getId()获得的Java线程ID，它常常用自增长的长整形1..N实现。                                                                      | tid=0x000000011e52a800                                                                             |
   | 原生线程ID             | 之所以关键是因为原生线程ID可以让你获得诸如从操作系统的角度来看那个线程在你的JVM中使用了大部分的CPU时间等这样的相关信息。                                | nid=0x251c                                                                                         |
   | Java线程状态和详细信息 | 可以快速的了解到线程状态及其当前阻塞的可能原因。                                                                                                        | waiting for monitor entry [0xfffffffea5afb000] java.lang.Thread.State: BLOCKED (on object monitor) |
   | Java线程栈跟踪         | 这是目前为止你能从线程堆栈中找到的最重要的数据。这也是你花费最多分析时间的地方，因为Java栈跟踪向提供了导致诸多类型的问题的根本原因，所需要的90%的信息。 |                                                                                                    |

## 线程中锁的问题

1. 死锁  

   在多线程程序的编写中，如果不适当的运用同步机制，则有可能造成程序的死锁，经常表现为程序的停顿，或者不再响应用户的请求。  

2. 热锁  

   热锁，也往往是导致系统性能瓶颈的主要因素。其表现特征为，多个线程对临界区或者锁的竞争。可能出现：  

   - 频繁的线程的上下文切换：从操作系统对线程的调度来看，当线程在等待资源而阻塞的时候，操作系统会将之切换出来，放到等待的队列，当线程获得资源之后，调度算法会将这个线程切换进去，放到执行队列中。  
   - 大量的系统调用：因为线程的上下文切换，以及热锁的竞争，或者临界区的频繁的进出，都可能导致大量的系统调用。  
   - 大部分CPU开销用在"系统态"：线程上下文切换，和系统调用，都会导致CPU在"系统态"运行，换而言之，虽然系统很忙碌，但是CPU用在"用户态"的比例较小，应用程序得不到充分的CPU资源。  
   - 随着CPU数目的增多，系统的性能反而下降。因为CPU数目多，同时运行的线程就越多，可能就会造成更频繁的线程上下文切换和系统态的CPU开销，从而导致更糟糕的性能。  

   上面的描述，都是一个scalability(可扩展性)很差的系统的表现。从整体的性能指标看，由于线程热锁的存在，程序的响应时间会变长，吞吐量会降低。  

   那么，怎么去了解"热锁"出现在什么地方呢？一个重要的方法还是结合操作系统的各种工具观察系统资源使用状况，以及收集Java线程的dump信息，看线程都阻塞在什么方法上，了解原因，才能找到对应的解决方法。  

   我们曾经遇到过这样的例子，程序运行时，出现了以上指出的各种现象，通过观察操作系统的资源使用统计信息，以及线程dump信息，确定了程序中热锁的存在，并发现大多数的线程状态都是Waiting for monitor entry或者Wait on monitor，且是阻塞在压缩和解压缩的方法上。后来采用第三方的压缩包javalib替代JDK自带的压缩包后，系统的性能提高了几倍。  

3. 查看锁状态  

   cat jstack.log | grep -inr --color -e "tid=" -e "java.lang.Thread.State" -e "- locked" -e "- waiting on" -e "- waiting to lock"  

## Java进程内存结构

JVM区域总体分两类，Heap区和非Heap区：  

- Heap区又分：Eden Space(伊甸园)、Survivor Space(幸存者区)、Tenured Gen(老年代-养老区)。  

- 非heap区又分：Code Cache(代码缓存区)、Perm Gen(永久代或叫方法区)、直接内存、JVM Stack(Java虚拟机栈)、Local Method Statck(本地方法栈)。  

  - Perm Gen中放着类、方法的定义。  
  - JVM Stack中放着方法参数、局域变量等的引用，方法执行顺序按照栈的先入后出方式。  

HotSpot虚拟机GC算法采用分代收集算法：  

1. 一个人(对象)出来(new 出来)后会在Eden Space(伊甸园)无忧无虑的生活，直到GC到来打破了他们平静的生活。GC会逐一问清楚每个对象的情况，有没有钱(此对象的引用)啊，因为GC想赚钱呀，有钱的才可以敲诈嘛。然后富人就会进入Survivor Space(幸存者区)，穷人的就直接kill掉。  
2. 并不是进入Survivor Space(幸存者区)后就保证人身是安全的，但至少可以活段时间。GC会定期(可以自定义)会对这些人进行敲诈，亿万富翁每次都给钱，GC很满意，就让其进入了Genured Gen(养老区)。万元户经不住几次敲诈就没钱了，GC看没有啥价值啦，就直接kill掉了。  
3. 进入到养老区的人基本就可以保证人身安全啦，但是亿万富豪有的也会挥霍成穷光蛋，只要钱没了，GC还是kill掉。  

分区的目的：新生区由于对象产生的比较多并且大都是朝生夕灭的，所以直接采用标记-清理算法。养老区生命力很强，则采用复制算法。分区可以针对不同情况使用不同算法。  

## 什么叫Java的内存泄露？

在Java中，内存泄漏是指存在以下两个特点的对象：  

1. 对象是可达的，即在有向图中，存在通路可以与其相连(也就是说该对象被其他所引用)。  
2. 对象是无用的，即程序以后不会再使用这些对象。  

如果对象满足这两个条件，这些对象就可以判定为Java中的内存泄漏，这些对象不会被GC所回收，依然占用内存。  

## 内存泄漏(Memory Leak)还是内存溢出(Memory Overflow)？

内存泄露会导致内存溢出，但内存溢出不一定是内存泄露导致的。区分的关键在于导致内存溢出的对象是否是必要的。  

1. 如果是内存泄漏，可进一步通过工具查看泄漏对象到GC Roots的引用链。于是就能找到泄漏对象是通过怎样的路径与GC Roots相关联，并导致垃圾收集器无法自动回收它们的。掌握了泄漏对象的类型信息，以及GC Roots引用链的信息，就可以比较准确地定位出泄漏代码的位置。  
2. 如果不存在泄漏，换句话说就是内存中的对象确实都还必须存活着，那就应当检查虚拟机的堆参数(-Xmx与-Xms)，与机器物理内存，看看是否还可以调大，再从代码上检查是否存在某些对象生命周期过长、持有状态时间过长的情况，尝试减少程序运行期的内存消耗。  
