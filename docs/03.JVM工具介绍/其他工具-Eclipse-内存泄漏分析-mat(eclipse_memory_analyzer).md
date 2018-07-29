# MAT的使用

参考：<https://my.oschina.net/shaorongjie/blog/161385>  
参考：<http://tivan.iteye.com/blog/1487855>  
参考：<http://www.jianshu.com/p/c8e0f8748ac0>  
参考：<http://www.importnew.com/2433.html>  
参考：<http://chiyx.iteye.com/blog/1528782>  
参考：<http://wensong.iteye.com/blog/1986449>  
参考：<http://www.blogjava.net/rosen/archive/2010/05/21/321575.html>  
参考：<http://www.blogjava.net/rosen/archive/2010/06/13/323522.html>  
参考：<http://blog.csdn.net/aaa2832/article/details/19419679/>  
参考：<http://www.tuicool.com/articles/i2iqQ3>  
参考：<http://www.linuxidc.com/Linux/2015-08/122103.htm>  

## 1. MAT场景介绍

### 1.1 MAT的作用？

分析Java的Heap Dump的工具，定位Java虚拟机的堆内存泄露的问题。  

### 1.2 MAT能帮我们做到什么地步？

MAT只可以定位出是哪个类的哪个属性发生了泄露，但是无法定位发生泄露的线程堆栈，也就是无法定位出哪个类的第几行发生了问题。其实原因也是显而易见的，Heap Dump只是一个瞬态的内存快照，对于持续的一点点的泄露是无能为力的。  
Heap Dump文件不包含内存的分配信息，因此无法查询谁创建了哪个对象这样的信息。  
A heap dump does not contain allocation information so it cannot resolve questions like who had created the objects and where they have been created.  

### 1.3 为什么有时MAT中可以直接看到发生问题的线程堆栈？

凡是都有特例，快速泄露是有线程堆栈的，这种问题定位也很简单。  
从泄露的速度上看，我们可以把泄露分为两类：  

- 缓慢泄露：运行轨迹每次经过问题代码，内存只泄露一点点，随着时间的流逝，最后发生OOM。这种情况是没有线程堆栈的，靠走读相关类的相关属性的代码或使用jmc监视对象的创建来定位问题。  
- 快速泄露：问题代码一次产生大量内存泄露(如问题代码加载整个表的数据，且表中的数量比较大)导致直接OOM。这种情况是有线程堆栈的，直接锁定问题代码。  

### 1.4 Heap Dump中的对象都是不可回收的吗？

不是的，有些对象会在下次GC时被回收掉，因此为了减少干扰，减小Heap Dump文件的大小(文件越小MAT反应更快)，在获取Heap Dump前最好触发一次GC。jmap使用live参数触发一次GC：jmap -dump:live,format=b,file=heap_dump.hprof java_pid  

## 2. MAT页面介绍

### 2.1 标签页介绍

Overview：初始标签页，提供一个概览界面。  
Histogram： 提供每个类的对象统计。这个标签页不常用。  
Dominator Tree：支配树，提供程序中对象的支配关系，支配的概念后面会详谈。这个便签页很常用。  
Top Consumers：按类和包展示最大的对象。这个标签页不常用。  
Duplicate Classes：分析加载的类。这个标签页不常用。  
Leak Suspects：疑似泄露点，提供内存泄露疑点占用内存大小，被谁加载的，以及类型等详细信息。相当于帮助我们自动分析了内存泄露，当然结果不一定100%对。这个便签页很常用。  
Top Components：提供占内存超过%1堆大小的对象信息。这个便签页很常用。  

### 2.2 工具栏介绍

一些工具栏中的工具是与标签栏动态关联的，只有打开特定标签页才会出现，这种工具再讲每个便签页时在介绍。  
Overview：如果关闭了Overview标签页，可以使用此工具重新打开。  
Histogram：打开Histogram标签页。  
Dominator Tree：打开Histogram标签页。  
所有线程：提供瞬态的所有线程信息。  
Heap Dump Overview：查看System Properties等。  

### 2.3 Histogram标签页

Histogram按类展示内存占用情况：  
Class Name：类全名。  
Objects: 对象个数。这个可以确认某各类是否真是单例。  
Shallow size：对象自身占用的内存大小。  
Retained size：对象的Shallow Size + 对象直接引用或者间接引用的对象的Shallow Size。  

关联工具栏：  
Histogram对比：为查找内存泄漏，可以对比两个不同时间的Dump结果。其实这个用处不太，只需要用一个Heap Dump找占用内存最大的对象就可以了。  

### 2.4 Dominator Tree标签页

展示对象的支配关系。  

支配树详细说明可以参考：<http://www.linuxidc.com/Linux/2015-08/122103.htm>  

一些概念：  
支配：在计算机的控制流理论中意思是假如说从起始节点到节点B的所有路径都经过节点A，则节点A支配节点B。在垃圾回收理论中应该是指某个对象在另外一个对象的保留堆中。  
对象引用图：与Java代码一一对应的引用关系图。MAT中无此功能的页面。  
支配树：根据垃圾回收的角度，MAT将复杂的对象引用图转换为简单的支配树。思想上是从复杂的图转换为简单的树，以便弄清对象的支配关系。  
GC根：Garbage Collections Roots (GC roots) are objects that are kept alive by the Virtual Machines itself. These include for example the thread objects of the threads currently running, objects currently on the call stack and classes loaded by the system class loader. 通常GC Roots是一个在current thread(当前线程)的call stack(调用栈)上的对象(例如方法参数和局部变量)，或者是线程自身或者是system class loader(系统类加载器)加载的类以及native code(本地代码)保留的活动对象。  
Unreachable对象：Unreachable指的是可以被垃圾回收器回收的对象，也就是没有GC根的对象，但是由于没有GC发生，所以还没有释放。  
内存泄露：内存泄露是指有个引用指向一个不再被使用的对象，导致该对象不会被垃圾回收器回收。如果这个对象有个引用指向一个包括很多其他对象的集合(指各种容器，list或set或map)，就会导致这些对象都不会被垃圾回收。因此，需要牢记，垃圾回收无法杜绝内存泄露。  
内存泄露主要特征：可达，无用。无用指的是创建了但是不再使用之后没有释放。  

支配树有以下重要属性：  
属于X的子树的对象表示X的保留对象集合。  
如果X是Y的持有者，那么X的持有者也是Y的持有者。  
在支配树中表示持有关系的边并不是和代码中对象之间的关系直接对应，比如代码中X持有Y，Y持有Z，在支配树中，X的子树中会有Z。  
这三个属性对于理解支配树而言非常重要，一个熟练的开发人员可以通过这个工具快速的找出持有对象中哪些是不需要的以及每个对象的保留堆。  

Java的引用规则：从最强到最弱，不同的引用(可到达性)级别反映了对象的生命周期。  
Strong Ref(强引用)：通常我们编写的代码都是Strong Ref，于此对应的是强可达性，只有去掉强可达，对象才被回收。  
Soft Ref(软引用)：对应软可达性，只要有足够的内存，就一直保持对象，直到发现内存吃紧且没有Strong Ref时才回收对象。一般可用来实现缓存，通过java.lang.ref.SoftReference类实现。  
Weak Ref(弱引用)：比Soft Ref更弱，当发现不存在Strong Ref时，立刻回收对象而不必等到内存吃紧的时候。通过java.lang.ref.WeakReference和java.util.WeakHashMap类实现。  
Phantom Ref(虚引用)：根本不会在内存中保持任何对象，你只能使用Phantom Ref本身。一般用于在进入finalize()方法后进行特殊的清理过程，通过 java.lang.ref.PhantomReference实现。  

### 2.5 Leak Suspects

MAT通过参考Histogram、Dominator Tree等数据分析出泄露原因，相当于帮助我们自动分析了内存泄露，Leak Suspects主要是列出怀疑的内存泄露处，结果不一定100%对。  

### 2.6 右键菜单

MAT中的各个视图中，在每一个Item中点击右键会出现很多选项，很多时候我们需要依赖这些选项来进行分析：  
List objects --> with outcoming references：查看被该对象引用的对象(支配树中对象的出节点)。这个常用。  
List objects --> with incoming references：查看引用到该对象的对象(支配树中对象的入节点)。  
Path To GC Roots --> exclude all phantim/weak/soft etc. references：查看这个对象的GC Root(也就是说这个对象不被回收的根因，注意一个对象的GC Root可能不止一个)，不包含虚、弱引用、软引用，剩下的就是强引用。从GC上说，除了强引用外，其他的引用在JVM需要的情况下是都可以被GC掉的，如果一个对象始终无法被GC，就是因为强引用的存在，从而导致在GC的过程中一直得不到回收，因此就内存溢出了。从一个对象到GC Roots的引用链被称为Path to GC Roots，通过分析Path to GC Roots可以找出Java的内存泄露问题，当程序不在访问该对象时仍存在到该对象的引用路径。为GC Root的Item在左下角有个小黄点。  
Merge Shortest Path To GC Roots --> exclude all phantim/weak/soft etc. references：指定对象到GC Roots的最短路径。Java的垃圾回收机制简单来说有点类似树的深度遍历方式，如果一个对象有引用，则GC Root到这个对象之间是有路径可达的。如果GC Root到这个对象之间无任何路径可达，则这个对象是不可触及的，是可以回收的。  
Java Basics --> Thread Details： 查看线程堆栈，注意此功能仅对线程对象可用。  
Calculate Minimum Retained Size(quick approx.)：快速估算Retained Size，结果可能包含大于等于号。  
Calculate Precise Retained Size：准确计算Retained Size，如果Heap Dump较大，比较耗时。  

## 3. 定位内存问题的一般步骤

1. 使用Leak Suspects进行自动化分析  
2. 使用Dominator Tree，查看占用内存前几名的对象，逐一排查是否有问题。以其中一个为例，逐渐展开支配树，直到占用比例有大幅下降的节点，此节点为问题所在，大幅下降的原因是大量小对象存在，虽然每个小对象占比很低，但是巨大的数量导致了其直接支配对象占比较大。  
3. 使用List objects --> with outcoming references和List objects --> with incoming references确认有问题对象及其相应的问题属性。因为Dominator Tree只是对象GC树，无法查看对象间真正的引用关系，List objects可以展示对象间真正的引用关系，与代码对应。  
4. 分析问题代码，查找引用关系等，理清问题属性的对象是在哪创建和销毁，其创建和销毁是否是合理的。  
5. 修改代码。  
6. 测试，并使用可视化的工具查看堆中内存占用的走势，确保不会慢慢持续上升。  

注意1：MAT中的提供的功能都可以随便点点，达到共同定位和相互佐证，加快定位速度。  
注意2：如果问题容易重现，可以使用jmc的飞行记录观察对象的分配时的线程栈(飞行记录--内存--分配--新TLAB中的分配、TLAB外部的分配)，但要注意，只要对象被创建，不管最终是否被回收飞行记录都会记录，所以可能存在一些干扰。  

## 4. 其他功能列表

1. 获得系统属性的方法。  
   工具栏--Heap Dump Overview  

2. 获取全部线程堆栈  
   工具栏--线程堆栈(图标为齿轮)  
