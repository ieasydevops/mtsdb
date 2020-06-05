# 时间序列索引 [Time Series Index (TSI)]

## 目标

* TSI 的背景

* TSI 存储布局

## TSI 的背景

### 时间序列索引解决的问题

为了支持大规模的时间序列 -即单时间序列高基数的数据存储，Influx 增加了时间序列索引。通过TSI的存储引擎，用户能够处理上百万的时间序列。
这项工作代表了自influxdata 于2016年发布时间序列合并树（TSM）存储引擎以来数据库中最重要的技术进步。


### TSI的由来

Influxdb 实际看上去，像两个数据库合并为一,一个时间序列数据存储(TSM)
和一个对指标，标签，和元数据字段(filed)的倒排索引 (TSI ).

#### TSM(Time-Structured Merge Tree)

时间结构聚合树（TSM）引擎于2015年构建，并于2016年继续增强，旨在解决原始时间序列数据获得最大吞吐量、压缩和查询速度的问题。
在TSI之前，反向索引是一种内存中的数据结构，它是在基于TSM中的数据启动数据库时构建的。
这意味着，对于每个measurement、tag key-value pair 和 failed Name，内存中都有一个查找表来将这些元数据位映射到底层时间序列。对于具有大量短暂序列的用户，随着新时间序列的创建，内存利用率不断增加。而且，启动时间增加了，因为所有这些数据都必须在启动时加载到堆内存中。

#### TSI (Time Series Index)

新的时间序列索引（TSI）将 在内存中映射 移动到磁盘文件上，这意味着我们让操作系统处理最近使用最少的（LRU）内存。与原始时间序列数据的TSM引擎非常相似，我们有一个预写日志，其中有一个内存结构，该结构在查询时与内存映射索引合并。后台协程不断运行，将索引压缩成越来越大的文件，以避免在查询时执行过多的索引合并。
在后台，我们使用类似（Robin Hood Hashing ）的技术来进行快速索引查找，使用HyperLogLog++来保存基数的估计。这以技术可以使我们能够向查询语言添加一些内容，比如SHOW CARDINALITY查询。

#### TSI 解决的问题以及遗留的问题

时间序列索引（TSI）解决的主要问题是短暂的时间序列。最常见的情况是，希望通过在标记中放置标识符来跟踪每个进程或每个容器指标。例如，Kubernetes的Heapster项目就是这样做的。对于不再适合写入或查询的序列，它们不会占用内存空间。

Heapster项目和类似的用例没有解决的问题是限制了查询返回的数据的范围。我们将在将来更新查询语言，以便按时间限制这些结果。我们也不能解决让所有这些系列的读写都很热的问题。对于这个问题，扩展集群是解决方案。我们需要在查询语言中添加护栏和限制，并最终将增加，溢出到磁盘的处理逻辑。


## TSI 存储布局设计


### TSI存储结构


TSI (Time Series Index) 也是一个 基于LSM 的数据库，主要包括如下四块：

索引： 包含一个数据分片的索引的数据集

分区： 包含一个数据分片的 数据分区。- Influxdb的数据，首先会从时间范围做Shard，每个
时间范围内的Shard，会在基于SeriesKey做 Shard Partition。

日志文件： 包含 内存索引中最新写入的序列，类似WAL。

索引文件： 有日志文件（WLA）构建而成的包含一个不可变的，内存映射索引的索引，或是有两个
连续的索引文件合并而成的一个大索引文件。

```
Index: Contains the entire index dataset for a single shard.

Partition: Contains a sharded partition of the data for a shard.

LogFile: Contains newly written series as an in-memory index and is persisted as a WAL.

IndexFile: Contains an immutable, memory-mapped index built from a LogFile or merged
 from two contiguous index files.

```

### TSI构建

#### 写入逻辑

以序列写入流程，分析TSI的构建过程。

1. 新的序列写入到达后，先加入序列文件，或者查找该序列是否存在，如果不存在，在生成一个自增的ID。
   这个自增的ID 和 Measurement，Tag Key-Vaule Pair,Filed 是一一映射的

2. 新写入的序列被发送给索引。索引维护了一个 由序列ID构成的 有序的 高效压缩位图[RoaringBitmap](https://github.com/RoaringBitmap/RoaringBitmap) , 并会忽略掉已经存在的序列ID。

3. 对序列做Hash，然后发给合适的分区

4. 对应的分区将该序列写入 日志文件

5. 该日志文件，将该序列写入到 磁盘上的WAL，并将其加入到内存索引集合中。

#### 合并逻辑

   一旦 LogFile 超过1M大小，就会产生一个新的日志文件，之前的日志文件开始合并到索引文件中。
第一个索引文件是 Level1 (L1), 而之前的日志文件 可以认为是 Level 0 (L0).
   索引文件也可以有两个小的索引文件合并而成。例如： 两个连续的 L1 级的索引文件 可以合并为一个
L2 级的索引文件。



### TSI 提供的能力

TSI的 是为了解决倒排索引问题，他需要回答的核心问题是：

* 当前有哪些指标（measurement）?

* 有哪些标签？

* 给定的标签有哪些Value值？

* 一个指标包含那些序列ID？ 

* 给定一个标签，或一些标签，甚至一个模糊匹配的标签，能匹配到那些序列？

* 给定一个标签值能匹配到那些序列？

这几个问题，索引通过物种类型的迭代器解决。

```
MeasurementIterator(): Returns a sorted list of measurement names.

TagKeyIterator(): Returns a sorted list of tag keys in a measurement.

TagValueIterator(): Returns a sorted list of tag values for a tag key.

MeasurementSeriesIDIterator(): Returns a sorted list of all series IDs for a measurement.

TagKeySeriesIDIterator(): Returns a sorted list of all series IDs for a tag key.

TagValueSeriesIDIterator(): Returns a sorted list of all series IDs for a tag value.

```
以上的迭代器，是可以相互组合的。而且每种类型(measurement,
tag key, tag value,series id等)的迭代器，实现了交集，并集，差集的能力。


```
Merge: Deduplicates items from two iterators.

Intersect: Returns only items that exist in two iterators.

Difference: Only returns items from first iterator that don’t exist in the second 
iterator.

```



### TSI 的文件结构



#### 概览

首先，提供一张概览视图，全局了解tsi 的文件结构。TSI 主要由四大文件构成：LogFile文件，Index文件，Mainfest文件，FileSet。下图展示了核心两大文件的结构图：

![](./Influxdb-tsi-arch.png)

新增的序列，首先写入 WAL(LogFile)。LogFile 的文件结构很简单，有一个个LogEntry构成。
LogEntry 有一个Flag 标记当前的类型（增加/删除 ）, measurement名称，一系列的 k/v,
以及check sum构成。

随着LogFile文件的不断变大(超过5M的时候),会被Compaction合并,并构建成索引文件 Index File.

Index File 有三中类型的数据块构成。序列块(SeriesBlock)，标签块(Tag Block)，和指标块
(Measurement Block)。

这三个数据块，通过 HashIndex，来关联对应的序列。

#### 各个文件结构详解

 #### LogFile

 LogFile 是由 按序写入磁盘的一系列 LogEntry构成。
 LogFile 大小超过5MB 就会被合并为 Index 文件。
 日志文件的 LogEntry 可能是如下接种类型：
 * 增加的序列
 * 删除的序列
 * 删除的指标（measurement）
 * 删除的标签键（TagKey）
 * 删除的标签值 (TagValue)

日志文件也维护了一个 与现存的序列ID 和 tombstones 相关的 bisets.
在服务启动的时候，可基于这些 bitsets 和 其他的日志文件 ，索引文件重新生成
全量的 index bitsets.


 #### 索引文件

 Index File 有三个主要的类型的块文件构成：
 序列块，一个和多个标签块，一个指标块。每个数据块的末尾，都包含一个 trailer.
 trailer 描述了 这些块的一些元信息，比如偏移量。

 #### Manifest file
 
 索引是有 WAL 和 Index文件 构成的一个有序集合。这些文件 在做合并和重写操作的时，
 需要保持有序。保持有序是为了对 序列，指标，或标签 的标记删除有利。
 
 当该集合的活动文件变动时，mainfest 文就会被重写，从而保持对该集合的追踪。在服务
 启动时，manifest 能指定文件的顺序，并且不在manifest中的文件，会被从索引目录中删除；



 #### 索引文件的合并（compacting index file）

  TSI的合并有两个主要步骤：

首先： 一旦日志文件大小超过阈值，他们就会被合并为一个索引文件。 日志文件的阈值会设置
的相对较小，主要处于如下两个原因的考虑：
  
    TSI 为了避免在内存堆中维护日志文件的索引

    小的日志文件也很容易转化为Index文件。

其次： 一旦一个连续的索引文件集超过了负载因子（通常为10倍），
这些索引文件会被合并为一个大的索引文件，老的索引文件会被丢弃。
由于，所有的块都是有序的，新的索引文件可以流式传输，减小内存使用


 #### FileSet 解决并发问题
 
 索引文件，虽然是不可修改的，但在做合并的时候，我们需要知道那些文件在被使用。
 为了解决这个问题，引入了引用计数。

 一个FileSet 是由一系列有序的索引文件集构成。当文件集被索引获取时，
 计数器增加，当用户使用完 fileSet时，引用计数器减少。计数器不为0的文件
 是不能被删除的。除了引用计数器，索引文件没有其它的锁机制。








## 参考文献

[Time Series Index (TSI) details](https://docs.influxdata.com/influxdb/v1.8/concepts/tsi-details/)

[InfluxDB详解之TSM存储引擎解析](https://yq.aliyun.com/articles/158312?spm=5176.100239.blogrightarea106382.21.PmSguT)

[tsi1 design](https://github.com/influxdata/influxdb/blob/master/tsdb/tsi1/DESIGN.md)

[tsi doc](https://github.com/influxdata/influxdb/blob/master/tsdb/tsi1/doc.go)


[RoaringBitmap](https://github.com/RoaringBitmap/RoaringBitmap)