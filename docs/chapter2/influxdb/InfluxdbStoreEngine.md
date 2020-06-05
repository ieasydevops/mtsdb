# Influxdb 存储引擎


## 概览

## 目标

   Influxdb 的存储引擎发展历史很有趣，通过详细了解其发展历程对我们了解时间序列数据存储引擎的设计很有
必要。
   Influxdb 的存储引擎设计原则：

* 数据能安全的写入到磁盘
* 数据查询结果齐全并且正确
* 数据第一，性能第二



## 存储引擎的发展历史

### LevalDB 时代

   数据序列的特性，决定了在选择存储引擎时，主要的考量有三点：
1. 写入吞吐性能高
2. 能做Range查询
3. 稳定，值得依赖，能基于此存储上生产环境

基于这三点，Influxdb 选择了LevalDB. 然而，LevelDB的几个致命的缺点，导致了后来在底层存储引擎上纠结了一年多。主要的问题如下：

1. LevelDB 不支持热点备份。如果备份，需要关掉当前的数据库实例，做完拷贝，在启服务。
2. 对过期数据的删除，会导致大量的IO，这个量级和数据的写入没啥区别。
3. 每个序列映射一个小文件，对历史数据的批量读（比如查询6个月，或一年一系列数据的），会引发灾难性的问题，文件句柄耗尽。

虽然，针对问题1 有LevelDB的变种数据库，如RocksDB 和 HyperLevelDB 能解决，但是，他们解决不了问题3。
针对问题2，Influxdb针对时间序列数据库，也做了按照时间分片，比如过去的数据 按7天生产一个shard, 结合 RocksDB 引入的列族特性，可以解决2的问题，但是还是解决不了问题3.

### BoltDB时代

经过一年多的纠结，Influxdb 终于放弃了 LevelDB. 转而用BoltDB替换了LevelDB。
0.9.0 到 0.9.2 版本是基于BoltDB 的。
BoltDB 是受到LMDB数据库的启发，用纯粹GO语言实现的一个数据库。BoltDB 的优势就是稳定，简单。基于
B+树 和mmap实现，解决了问题3. 但是随着数据文件大小增长到几GB时，会出现IOPS的 爆涨。Influxdb 团队
为了解决这个问题，在BoltDB 之上，增加了 WAL，试图减少随机写的数量，但是这只是延迟了落盘的随机写的时机，并没有根本解决问题。

### TSM 时代
 在Bolt之上构建第一个WAL实现的经验给Influxdb团队信心，来解决数据写的问题。由于WAL性能比较出色，问题在
 索引上，因此他们考虑 创建一个 类似 LSM 树的结构，来提高整体的写入负载。这个东西，就是TSM。



## 存储引擎的实现

### 存储引擎的核心概念

* WAL（Write Ahead Log）
* 缓存
* Time-Structed MergeTree (TSM )
* Time Series Index (TSI)





<!-- 

## 几个问题

### 为什么存储引擎不用B+树？

考虑到给定的序列大部分的工作负载在追加写，用B+树应该能达到一个好的写入性能？ 实质上，
针对特定序列的写入能到达每秒10万+ 的吞吐量，但是真实的情况是，时间序列的并发写入，对应
的是大量的序列，在表现上，写入更像是随机写。


### 大规模的删除过期的数据

时间序列的数据，通常面临大规模的数据删除。常见的场景是，时间序列的数据，对近期的时间精度要求更高，
通常是几天或几个月。更长的数据，通常通过降采样，或者聚合的方式转化为低精度的数据。一方面是为了节省
存储成本，另一方便是为了提高查询响应时间。

最简单的办法，是当每个序列过期的时候，自动删除。但这意味着，系统需要处理删除的数据和写入时一样。
而且，大部分的数据引擎并不支持这种设计。


## LevelDB 和 Log Structured Merge Trees


Influxdb 最初选择LevelDB 作为底层的存储引擎，这个和Prometheus的最初选择一样。主要的考量是：
 
1. LevelDB 基于LSM 实现，而且具有很好的写吞吐性能。 LevelDB 暴露的出API，是对Key做了排序的，这对
时间序列数据是非常友好的，因为可以基于Key做范围的筛选。

2. LevelDB 的最大优势是，高吞吐率的写入和存储压缩。

面临的问题：

 1. LevelDB 不支持热点备份。如果希望备份，你需要将数据关掉，在做一个拷贝。当然有LevelDB 的变种数据
 库，如 RocksDB and HyperLevelDB 能解决这个问题，但是还是会有其它问题。

 2. 自动管理数据保留策略。不幸的是，LSM 结构数据的删除 和数据的写入一样昂贵。
 通常，一个删除的执行过程是：
     写一个删除记录到一个 tombstone.
     之后，将查询的结果集和所有的 tombstone 合并，来获取需要删除的数量
     最后，将运行压缩操作，删除SSTable文件中的逻辑删除记录 和 tombstone中的记录。

为了避免删除，Influxdb 将数据分割到 shard 的各个时间块上。一个shard 通常可以保存一天或七天的数据。每个shard映射到一个底层LevelDB。这意味着我们可以通过关闭数据库并删除底层文件来删除一整天的数据。 -->





## 参考文献

[Cassandra SSTable Storage Format](http://distributeddatastore.blogspot.com/2013/08/cassandra-sstable-storage-format.html)

[InfluxDB storage engine](https://v2.docs.influxdata.com/v2.0/reference/internals/storage-engine/#)

[The InfluxDB Storage Engine and the Time-Structured Merge Tree (TSM)](https://docs.influxdata.com/influxdb/v1.3/concepts/storage_engine/)