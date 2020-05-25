# 概述

- VictoriaMetrics 数据库的历史
- VictoriaMetrics 功能亮点
- VictoriaMetrics 的架构设计
- VictoriaMetrics 模块分析
- VictoriaMetrics 集群模式
- VictoriaMetrics 实践方案
- VictoriaMetrics 源码分析

# 历史




# 架构设计




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