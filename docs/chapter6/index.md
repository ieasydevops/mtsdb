# 目标

- 了解一般索引的实现原理
- MySQL的索引

# MySQL的索引

## 问题

为什么 MySQL 的 InnoDB 存储引擎会选择 B+ 树作为底层的数据结构，而不选择 B 树或者哈希？

## 原因分析

两个角度

- InnoDB 需要支持的场景和功能需要在特定查询上拥有较强的性能；

- CPU 将磁盘上的数据加载到内存中需要花费大量的时间，这使得 B+ 树成为了非常好的选择；



### 读写性能

- Online Transaction Processing

   传统的关系型数据库，主要用于处理基本的、日常的事务处理

- Online Analytical Processing

  在数据仓库中使用，用于支持一些复杂的分析和决策


### B Tree vs B+ Tree

    The most important difference between B-tree and B+ tree is that B+ tree only has leaf nodes to store data, and other nodes are used for indexing, while B-trees have Data fields for each index node.