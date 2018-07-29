# JVM的性能调优

摘自：探秘Java虚拟机——内存管理与垃圾回收 <http://www.blogjava.net/chhbjh/archive/2012/01/28/368936.html>  

## 系统调优方法：

1. 评估现状  
2. 设定目标  
3. 衡量调优  
4. 尝试调优  
5. 细微调整  

### 设定目标：

1. 降低Full GC的执行频率？  
2. 降低Full GC的消耗时间？  
3. 降低Full GC所造成的应用停顿时间？  
4. 降低Minor GC执行频率？  
5. 降低Minor GC消耗时间？  

例如某系统的GC调优目标：降低Full GC执行频率的同时，尽可能降低minor GC的执行频率、消耗时间以及GC对应用造成的停顿时间。  

### 衡量调优：

1. 衡量工具  

   1. 打印GC日志信息：-XX:+PrintGCDetails –XX:+PrintGCApplicationStoppedTime -Xloggc:<文件路径> -XX:+PrintGCTimeStamps  
   2. jmap：由于每个版本jvm的默认值可能会有改变，建议还是用jmap首先观察下目前每个代的内存大小、GC方式  
   3. 运行状况监测工具：jstat、jvisualvm、sar、gclogviewer  

2. 应收集的信息  

   1. minor gc的执行频率；full gc的执行频率，每次GC耗时多少？  
   2. 高峰期什么状况？  
   3. minor gc回收的效果如何？survivor的消耗状况如何，每次有多少对象会进入老生代？  
   4. full gc回收的效果如何？(简单的memory leak判断方法)  
   5. 系统的load、cpu消耗、qps or tps、响应时间  

QPS每秒查询率：是对一个特定的查询服务器在规定时间内所处理流量多少的衡量标准。在因特网上，作为域名服务器的机器性能经常用每秒查询率来衡量。对应fetches/sec，即每秒的响应请求数，也即是最大吞吐能力。  

TPS(Transaction Per Second)：每秒钟系统能够处理的交易或事务的数量。  

### 尝试调优：

注意Java RMI的定时GC触发机制，可通过：-XX:+DisableExplicitGC来禁止或通过-Dsun.rmi.dgc.server.gcInterval=3600000来控制触发的时间。  

1. 降低Full GC执行频率 – 通常瓶颈  
   老生代本身占用的内存空间就一直偏高，所以只要稍微放点对象到老生代，就full GC了；  
   通常原因：系统缓存的东西太多；  
   例如：使用oracle 10g驱动时preparedstatement cache太大；  
   查找办法：现执行Dump然后再进行MAT分析；  

   1. Minor GC后总是有对象不断的进入老生代，导致老生代不断的满  
      通常原因：Survivor太小了。  
      系统表现：系统响应太慢、请求量太大、每次请求分配的内存太多、分配的对象太大...  
      查找办法：分析两次minor GC之间到底哪些地方分配了内存；  
      利用jstat观察Survivor的消耗状况，-XX:PrintHeapAtGC，输出GC前后的详细信息；  
      对于系统响应慢可以采用系统优化，不是GC优化的内容；  

   2. 老生代的内存占用一直偏高  
      调优方法：  

      1. 扩大老生代的大小(减少新生代的大小或调大heap的 大小)；  
         减少new注意对minor gc的影响并且同时有可能造成full gc还是严重；  
         调大heap注意full gc的时间的延长，cpu够强悍嘛，os是32 bit的吗？  

      2. 程序优化(去掉一些不必要的缓存)  

   3. Minor GC后总是有对象不断的进入老生代  
      前提：这些进入老生代的对象在full GC时大部分都会被回收  
      调优方法：  

      1. 降低Minor GC的执行频率；  
      2. 让对象尽量在Minor GC中就被回收掉：增大Eden区、增大survivor、增大TenuringThreshold；注意这些可能会造成minor gc执行频繁；  
      3. 切换成CMS GC：老生代还没有满就回收掉，从而降低Full GC触发的可能性；  
      4. 程序优化：提升响应速度、降低每次请求分配的内存。  

2. 降低单次Full GC的执行时间  
   通常原因：老生代太大了...  
   调优方法：1)是并行GC吗？2)升级CPU 3)减小Heap或老生代  

3. 降低Minor GC执行频率  
   通常原因：每次请求分配的内存多、请求量大。  
   通常办法：1)扩大heap、扩大新生代、扩大eden。注意点：降低每次请求分配的内存；横向增加机器的数量分担请求的数量。  

4. 降低Minor GC执行时间  
   通常原因：新生代太大了，响应速度太慢了，导致每次Minor GC时存活的对象多。  
   通常办法：1)减小点新生代吧；2)增加CPU的数量、升级CPU的配置；加快系统的响应速度  

### 细微调整：

首先需要了解以下情况：  

1. 当响应速度下降到多少或请求量上涨到多少时，系统会宕掉？  
2. 参数调整后系统多久会执行一次Minor GC，多久会执行一次Full GC，高峰期会如何？  

需要计算的量：  

1. 每次请求平均需要分配多少内存？系统的平均响应时间是多少呢？请求量是多少、多常时间执行一次Minor GC、Full GC？  
2. 现有参数下，应该是多久一次Minor GC、Full GC，对比真实状况，做一定的调整；  

必杀技：提升响应速度、降低每次请求分配的内存？  

## 系统调优举例

现象：  

1. 系统响应速度大概为100ms；  
2. 当系统QPS增长到40时，机器每隔5秒就执行一次minor gc，每隔3分钟就执行一次full gc，并且很快就一直full GC了；  
3. 每次Full gc后旧生代大概会消耗400M，有点多了。  

问题：  
Full GC次数过多的问题  

解决方案：  

1. 降低响应时间或请求次数，这个需要重构，比较麻烦；——这个是终极方法，往往能够顺利的解决问题，因为大部分的问题均是由程序自身造成的。  

2. 减少老生代内存的消耗，比较靠谱；——可以通过分析Dump文件(jmap dump)，并利用MAT查找内存消耗的原因，从而发现程序中造成老生代内存消耗的原因。  

3. 减少每次请求的内存的消耗，貌似比较靠谱；——这个是海市蜃楼，没有太好的办法。  

4. 降低GC造成的应用暂停的时间；——可以采用CMS GS垃圾回收器。参数设置如下：  
   -Xms1536m -Xmx1536m -Xmn700m -XX:SurvivorRatio=7 -XX:+UseConcMarkSweepGC -XX:+UseCMSCompactAtFullCollection  
   -XX:CMSMaxAbortablePrecleanTime=1000 -XX:+CMSClassUnloadingEnabled -XX:+UseCMSInitiatingOccupancyOnly -XX:+DisableExplicitGC  

5. 减少每次minor gc晋升到old的对象。可选方法：1) 调大新生代。2)调大Survivor。3)调大TenuringThreshold。  
   调大Survivor：当前采用PS GC，Survivor space会被动态调整。由于调整幅度很小，导致了经常有对象直接转移到了老生代；于是禁止Survivor区的动态调整了，-XX:-UseAdaptiveSizePolicy，并计算Survivor Space需要的大小，于是继续观察，并做微调。最终将Full GC推迟到2小时1次。  
