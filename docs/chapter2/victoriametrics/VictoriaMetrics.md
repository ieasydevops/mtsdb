# 2.2.1 概述

- VictoriaMetrics 数据库的历史
- VictoriaMetrics 功能亮点
- VictoriaMetrics 的架构设计
- VictoriaMetrics 集群模式
- VictoriaMetrics 组件分析
- VictoriaMetrics 性能分析
- VictoriaMetrics 源码分析

# 2.2.2 VictoriaMetrics 数据库的历史


## 使用Prometheus，以及发现的问题

作者 Aliaksandr Valialkin， 之前写过fastHttp,性能比 go的 net/http库提升了不少。
个人git账户：https://github.com/valyala。

作者 16年开始用 prometheus 和grafana 做监控，到18年，监控的序列增长的了30万。
迁移到Promtheus2.2.0的时候发现了几个问题

-  查询超过几天的范围查询，会比较慢。主要的场景是：长期的趋势查询，和 容量规划

-  将数据保留策略从15天升级到一年后，发现吃掉了大量的存储空间

-  不清楚如何防止 当存储挂掉的时候，prometheus 的数据丢失。由于官网推荐的方案是采集两份
   数据做HA，这大大的增加我存储成本。

## 寻求解决方案。


作者开始探索这几个问题的解决方案，文件就聚焦到了 prometheus 的远程长期存储方案上。
上面的


# 2.2.3  VictoriaMetrics 功能亮点

- 快
- 省
- 易于扩展


# 2.2.4 VictoriaMetrics 的架构设计


VM集群三个服务组件构成，写（Insert）,查（Select）,存储（Storage）组成。

* vmstorage - stores the data
* vminsert - proxies the ingested data to vmstorage shards using consistent hashing
* vmselect - performs incoming queries using the data from vmstorage

系统架构如图：

![VMArchitecture](https://camo.githubusercontent.com/67fb28071f537a8837812e9e8ea9dcf6c649a648/68747470733a2f2f646f63732e676f6f676c652e636f6d2f64726177696e67732f642f652f32504143582d317654766b32726155396b46675a38346f462d4f4b6f6c72477748616550684852735a4563665131495f45433541425f5850577742333932587368785072616d4c4a38453462717074546e466e354c4c2f7075623f773d3131303426683d373436)

其中，写入，查询无状态。可以横行无限扩容。查询组件，支持PromL语法，方便和Grafana集成。

存储组件，采用 [shared nothing architecture](https://en.wikipedia.org/wiki/Shared-nothing_architecture),增加了集群的可用性，简化集群维护 和集群扩容。


### 多租户（Multitenacy）

VM 通过NS，实现多个租户的隔离。每个租户通过，accountID:projectID 唯一标识。

* 每个用户ID 和项目ID，由一个32位的整数标识，如何项目ID缺失，则自动填0.建议和租户相关的其它
	信息，比如 token，租户名称，限制，账户等存储在一个单独的关系型数据库中。这个数据库能方便被一
	个独立的服务管理。VM提供了 vmauth 来做此事。

* 当第一个数据点写入时，租户被自动创建

* VM 当个请求中，不支持跨越租户的查询。

```
     * Each accountID and projectID is identified by an arbitrary 32-bit integer in the range [0 .. 2^32). If projectID is missing, then it is automatically assigned to 0. It is expected that other information about tenants such as auth tokens, tenant names, limits, accounting, etc. is stored in a separate relational database. This database must be managed by a separate service sitting in front of VictoriaMetrics cluster such as vmauth. Contact us if you need help with creating such a service.

    * Tenants are automatically created when the first data point is written into the given tenant.

    * Data for all the tenants is evenly spread among available vmstorage nodes. This guarantees even load among vmstorage nodes when different tenants have different amounts of data and different query load.

    * VictoriaMetrics doesn't support querying multiple tenants in a single request.

```


# 2.2.5 VictoriaMetrics 集群模式

### 何时采用集群模式

单点模式更容易配置和维护，少于百万数据点/S 的写入量，建议用单点模式。（对应于实践操作，可理解为1万台机器以下的机器的指标
监控，可以采用单点模式。




### 集群模式有那些好处

- 支持单点模式的所有功能
- 性能和容量可以水平扩容
- 支持多租户，（多个名字空间隔离）



# 2.2.6 VictoriaMetrics 组件分析


## vmbackup

 vmbackup 从即时快照(instant snapshot)中创建VM数据备份.
 
 VM 会对 -storageDataPath 目录下的所有数据，创建即时快照。
 创建快照的接口

     http://<victoriametrics-addr>:8428/snapshot/create

返回的结果为：

	 {"status":"ok","snapshot":"<snapshot-name>"}

快照保存的路径为：

	<-storageDataPath>/snapshots

快照可被vmbackup 在合适的时间归档到备份存储服务上。




# 2.2.7 VictoriaMetrics 性能分析

## 粗略估算

内存：
   		
		每个时间序列所需的内存少于1KB，因此， 1GB左右的RAM 可以 支持 1M 的 活动时间序列。
		活动时间序列，指的是新写入，或查询到的序列。
		通过 vm_cache_entries{type="storage/hour_metric_ids"} 指标可以获取活动序列的值
		VM 存储了大量的缓存到RAM中，可以通过
		-memory.allowedPercent 心智内存的使用率
           
CPU核:

       单核CPU处理 30万/s 的数据点写入，因此，1M/s的数据点写入，需要至少4 核的CPU。
	   针对高基数的数据 或 标签较多的数据序列数据， 摄入速率更低。
	   

存储空间:

     一个数据点，大概占用不到1个byte。 因此，10万个数据点美秒的数据点，一个月的插入量，需要
	 至少256GB的的存储空间。
	 真实的存储大小严重以来数据的随机性，更高的随机性，意味着更多的存储空间.


网络利用率：

	   出口带宽利用率可以忽略。 入口网络流量，Prometheus remote_API 写入的数据，
	   大约为 ～100 byte/数据点。真实的入口带宽利用率，取决于 摄入指标的标签个数的均值和每个标签
	   Value值 大小的均值。 





## 实际测试结果

  测试所用的机器：

   3.8TB NVMe drive

   [n2.2.xlarge.x86](https://www.packet.com/cloud/servers/n2-xlarge/)

  

  测试的时间序列数据样本：

    temperature{sensor_id="12345"} 76.23 123456789

	此时序数据标示：在时间点123456789时， 传感器 12345 的 温度为 华氏 76.23。

  测试代码：

    https://github.com/VictoriaMetrics/billy/blob/master/main.go
	

   产生温度的脚本：
   
    https://github.com/VictoriaMetrics/billy/blob/master/scripts/write_needle.sh .

   测试查询性能：

    https://github.com/VictoriaMetrics/billy/tree/master/queries

  测试结果分析：

    525.6 亿 条记录，写入单个VM节点，耗时2H12M，平均摄入速度为
	525.6e9/(2*3600+12*60)= 66百万数据点/s;
	每天写入量可达到
	66M*3600*24=5.7兆 /天 
 

  [各个指标详情](https://medium.com/@valyala/billy-how-victoriametrics-deals-with-more-than-500-billion-rows-e82ff8f725da)

	 

# 2.2.8 VictoriaMetrics 源码分析

比较关心的两个问题：

1. VM如何实现集群模式？

## VM如何实现集群模式？

### [集群写入逻辑](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/cluster/app/vminsert/netstorage/insert_ctx.go#L169)

VM 的写入逻辑，根据传入的 时间序列的 标签{（labelName,lableValue）} 集合，
构建序列ID，然后根据存储节点个数做[跳跃一致性Hash](./一致性Hash算法JCH.md)，找到写入的节点。


```
// GetStorageNodeIdx returns storage node index for the given at and labels.
//
// The returned index must be passed to WriteDataPoint.
func (ctx *InsertCtx) GetStorageNodeIdx(at *auth.Token, labels []prompb.Label) int {
	if len(storageNodes) == 1 {
		// Fast path - only a single storage node.
		return 0
	}

	buf := ctx.labelsBuf[:0]
	buf = encoding.MarshalUint32(buf, at.AccountID)
	buf = encoding.MarshalUint32(buf, at.ProjectID)
	for i := range labels {
		label := &labels[i]
		buf = marshalBytesFast(buf, label.Name)
		buf = marshalBytesFast(buf, label.Value)
	}
	h := xxhash.Sum64(buf)
	ctx.labelsBuf = buf
	idx := int(jump.Hash(h, int32(len(storageNodes))))
	return idx
}

```



### 集群查逻辑

 1. 将输入的查询分解语句分解为针对存储节点的查询任务，并将这些任务推送到所有的存储节点；
 2.2. 查询节点根据返回的数据做聚合






## 参考文献

[VM集群架构模式](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/cluster/README.md)