# Influxdb 写入路径

## 写入流程

 API  (/write) -> WAL -> Cache -> TSM -> 压缩，合并为更高层的TSM
 

## 关键点分析

 API Handler 收到 Write 写请求，添加Tracing 记录，
 增加EventRecord记录。
 权限验证
 获取当前的Org
 获取需要写入的Bucket
 判断针对当前ID是否有写入权限,(会关联OrgID，Bucket资源类型，BucketID，写操作)
 判断写入的数据是否过大
 ...

 进入写入的真正入口函数
```
if err := h.PointsWriter.WritePoints(ctx, points); err != nil {
		log.Error("Error writing points", zap.Error(err))
		handleError(err, influxdb.EInternal, "unexpected error writing points to database")
		return
}
```


### Write Ahead Log (WAL)

### Cache

### TSM

### TSI 

数据序列存储索引

