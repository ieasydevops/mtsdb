# 存储节点中用的几种算法详解

## Jump Consistent Hash (JCH)

## 简介

- jump consistent hash是一种一致性哈希算法, 此算法零内存消耗，均匀分配，快速，并且只有5行代码。

- 此算法适合使用在分shard的分布式存储系统中 。

- 作者是 Google 的 John Lamping 和 Eric Veach，
   
   [原文地址](http://arxiv.org/ftp/arxiv/papers/1406/1406.2294.pdf)

代码：
```
int32_t JumpConsistentHash(uint64_t key, int32_t num_buckets) { 
    int64_t b = -1, j = 0; 
    while (j < num_buckets) { 
        b = j; 
        key = key * 2862933555777941757ULL + 1; 
        j = (b + 1) * (double(1LL << 31) / double((key >> 33) + 1)); 
    } 
    return b;
}
```
输入是一个64位的key，和桶的数量（一般对应服务器的数量），输出是一个桶的编号。



## 原理解释


JCH 的设计目标是

- 平衡性，把对象均匀地分布在所有桶中。
- 调性，当桶的数量变化时，只需要把一些对象从旧桶移动到新桶，不需要做其它移动。

设计思路是：

   **计算当bucket数量变化时，有哪些输出需要变化**



### 相关算法介绍

- 线性同余随机数生成器



## 参考文献
[一致性hash算法：Jump Consistent hash](https://www.jianshu.com/p/2ca8313512aa)
