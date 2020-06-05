# 内存索引和TSM 数据结构合并树

## InfluxDB 存储引擎

### 存储引擎概览


1. 批量时序数据shard路由：InfluxDB首先会将这些数据根据shard的不同分成不同的分组，每个分组的时序数据会发送到对应的shard。

2. 倒排索引引擎构建倒排索引：InfluxDB中shard由两个LSM引擎构成 – 倒排索引引擎和TSM引擎。时序数据首先会经过倒排索引引擎构建倒排索引，倒排索引用来实现InfluxDB的多维查询。

3. TSM引擎持久化时序数据:倒排索引构建成功之后时序数据会进入TSM Engine处理。TMS Engine处理流程和通用LSM Engine基本一样，先将写入请求追加写入WAL日志，再写入cache，一旦满足特定条件会将cache中的时序数据执行flush操作落盘形成TSM File。



### 数据shard策略

为了解决水平扩展，及快速查询的需求，需要多时序数据做shard。经过shard 的
数据，在写入和读取上都能获得水平扩展带来性能上的提升。
Influxdb 的Shard 策略有两种，
首先，针对时间做 Range shard，做时间分片。比如，默认情况下，influxdb 会按将7天的粒度，对数据
分片。

其次，针对单序列的高基问题，可以针对 SeriesKey 做 Hash 来划分 Shard。





## 为什么？

### 为什么InfluxDB倒排索引需要构建成LSM引擎？

LSM引擎天生对写友好，写多读少的系统第一选择就是LSM引擎，所以大数据时代的各种数据存储系统就是LSM引擎的天下，HBase、Kudu、Druid、TiKV这些系统无一不是这样。InfluxDB作为一个时序数据库更是写多读少的典型，无论倒排索引引擎还是时序数据处理引擎选用LSM引擎更是无可厚非
LSM引擎，工作机制必然是这样的：首先将数据追加写入WAL再写入Cache就可以返回给用户写入成功，WAL可以保证即使发生异常宕机也可以恢复出来Cache中丢失的数据。一旦满足特定条件系统会将Cache中的时序数据执行flush操作落盘形成文件。文件数量超过一定阈值系统会将这些文件合并形成一个大文件.



## 参考文献


[In-memory indexing and the Time-Structured Merge Tree (TSM)](https://docs.influxdata.com/influxdb/v1.8/concepts/storage_engine/)

[InfluxDB TSM存储引擎之数据写入](http://hbasefly.com/2018/03/27/timeseries-database-6/)

