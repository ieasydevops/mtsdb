# Level Compaction

## 简介


## 算法该要描述

- 分层式压缩方式将数据分成条个层，最底层的叫L0，其上分别是L1，L2….，每一层的数据大小是其上的那一层数据最大大小的10倍，其中最底层L0的大小为5M (可以配置)
- 当level层次大于0时，同一层的各个文件之间的Rowkey区间不会重叠。所以在level n与level n+1的数据块进行合并时，可以明确的知道某个key值处在哪个数据块中，可以一个数据块一个数据块的合并，合并后生成新块就丢掉老块。不用一直到所有合并完成后才能删除老的块。
- 整体执行流程是从L0->L1->L2，依次合并的过程，如下图所示。

![LevelMerge](https://upload-images.jianshu.io/upload_images/3262084-d34d4136678913e8.png)

compaction由上图，我们可以得知，越是level较低的块，它的数据就越新，在满足向下归约合并的过程中，就会按照文件的Rowkey的区间，进行合并，去除多余的版本，或者执行相关删除操作。因此，在读请求最极端的情况下，从Level0开始读数据，一直读到最下层Level n。

## 算法优劣势

### 优势

- 大部分的读操作如果有LRU特性，都会落入较低的Level上。因此，数据越”热”，Level就越低。从而有利于未来HFile多种存储介质的定位问题。
- 在合并的过程中，仅需在由上到下的部分文件参与，而不是要对所有文件执行Compaction操作。这样会加快Compaction执行的效率。

### 劣势

- 如果层次太多，在递归合并的过程中，容易造成某个区间的Compaction风暴，影响该区间数据操作的吞吐。



## 参考文献

[Option of Compaction Priority](https://rocksdb.org/blog/2016/01/29/compaction_pri.html)

[RocksDB. Leveled Compaction](https://www.jianshu.com/p/99cc0df8ed21)

[stripe-compaction](http://www.binospace.com/index.php/hbase-new-features-stripe-compaction/)