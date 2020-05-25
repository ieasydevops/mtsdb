# 概述

- VictoriaMetrics 数据库的历史
- VictoriaMetrics 功能亮点
- VictoriaMetrics 的架构设计
- VictoriaMetrics 模块分析
- VictoriaMetrics 集群模式
- VictoriaMetrics 实践方案
- VictoriaMetrics 源码分析

# 数据库的历史



##  功能亮点

- 快
- 省
- 易于扩展


## 集群模式

### 何时采用集群模式

单点模式更容易配置和维护，少于百万数据点/S 的写入量，建议用单点模式。（对应于实践操作，可理解为1万台机器以下的机器的指标
监控，可以采用单点模式。




### 集群模式有那些好处

- 支持单点模式的所有功能
- 性能和容量可以水平扩容
- 支持多租户，（多个名字空间隔离）

### 架构分析

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


# 模块分析



## 源码分析

## 集群写入逻辑

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

[写入逻辑代码](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/cluster/app/vminsert/netstorage/insert_ctx.go#L169)




## 集群查询逻辑

查询的逻辑：

 1. 将输入的查询分解语句分解为针对存储节点的查询任务，并将这些任务推送到所有的存储节点；
 2. 查询节点根据返回的数据做聚合

```

```



## 参考文献

[VM集群架构模式](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/cluster/README.md)