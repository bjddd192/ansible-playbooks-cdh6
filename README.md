# 大数据相关任务 ansible 处理

### 安装hadoop

操作说明：

1. 在 inventory 中配置hosts
2. 在当前工程目录执行 ansible 脚本，如：

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data

# 安装 hadoop
ansible-playbook -i ../inventory/dev_hosts_big_data master.yml
ansible-playbook -i ../inventory/dev_hosts_big_data workers.yml

# 格式化 namenode
ansible hadoop-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a '$HADOOP_HOME/bin/hdfs namenode -format'

# 启动 hadoop
ansible hadoop-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a '$HADOOP_HOME/sbin/start-all.sh'

# 启动 history-server
ansible hadoop-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'mapred --daemon start historyserver'

# 验证 hdfs
[hadoop@k8sn60 ~]$ jps
8528 ResourceManager
8259 SecondaryNameNode
8004 NameNode
6095 Jps

[hadoop@k8sn60 dfs]$ hdfs dfs -mkdir /user
[hadoop@k8sn60 dfs]$ hdfs dfs -mkdir /user/yanglei
[hadoop@k8sn60 dfs]$ hdfs dfs -ls /user
Found 1 items
drwxr-xr-x   - hadoop supergroup          0 2018-06-12 13:59 /user/yanglei
[hadoop@k8sn48 dfs]$ hdfs dfs -ls /user
Found 1 items
drwxr-xr-x   - hadoop supergroup          0 2018-06-12 13:59 /user/yanglei
[hadoop@k8sn59 dfs]$ hdfs dfs -ls /user
Found 1 items
drwxr-xr-x   - hadoop supergroup          0 2018-06-12 13:59 /user/yanglei
[hadoop@k8sn60 dfs]$ hdfs dfs -put /etc/crontab /user/yanglei
[hadoop@k8sn60 dfs]$ hdfs dfs -cat /user/yanglei/crontab
[hadoop@k8sn48 dfs]$ hdfs dfs -cat /user/yanglei/crontab
[hadoop@k8sn59 dfs]$ hdfs dfs -cat /user/yanglei/crontab
# 发现各节点都能看到创建的文件夹以及文件，则验证通过

# 验证 mapreduce
[hadoop@k8sn60 dfs]$ hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.1.0.jar grep /user/yanglei output 'dfs[a-z.]+'
[hadoop@k8sn60 dfs]$ hdfs dfs -ls .
[hadoop@k8sn48 dfs]$ hdfs dfs -ls .
[hadoop@k8sn59 dfs]$ hdfs dfs -ls .
[hadoop@k8sn60 dfs]$ hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.1.0.jar wordcount /user/yanglei/crontab output2
[hadoop@k8sn60 dfs]$ hdfs dfs -ls output2
[hadoop@k8sn60 dfs]$ hdfs dfs -cat output2/*

# web验证
http://172.20.32.131:50070/
http://172.20.32.131:50090/
http://172.20.32.131:8088/

# 停止 hadoop
ansible hadoop-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a '$HADOOP_HOME/sbin/stop-all.sh'

# 停止 history-server
ansible hadoop-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'mapred --daemon stop historyserver'

# 调整配置文件
# ansible hadoop-cluster -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m template -a 'src=./roles/hadoop/templates/mapred-site.xml dest=/home/hadoop/hadoop-3.1.0/etc/hadoop owner=hadoop group=hadoop mode=644'
```

### 安装 Hive

[官方下载地址](http://mirrors.hust.edu.cn/apache/hive/)

提前准备一个mysql库，例如：

```sql
create database db_metastore;
grant all on db_metastore.* to hive@'%'  identified by 'hive';
flush privileges;
```

[下载 jdbc connector](https://dev.mysql.com/downloads/connector/j/)

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data

# 安装 hive
ansible-playbook -i ../inventory/dev_hosts_big_data hive.yml
```

在安装的服务器上启动hive

```sql

su - hadoop
cd $HIVE_HOME
sh $HIVE_HOME/bin/hive

# 验证 hive
hive> show functions;
hive> desc function sum;
hive> create database db_hive_edu;
hive> use db_hive_edu;
hive> create table student(id int,name string) row format delimited fields terminated by '\t';
hive> insert into student (id,name) values(1,'yanglei');
hive> select * from student;

# 另外开一个连接建立一个数据文件(复制后手工处理下tab键)
tee /tmp/students.txt <<-'EOF'
001	zhangsan
002	lisi
003	wangwu
004	zhaoliu
005	chenqi
EOF

# 导入数据
hive> load data local inpath '/tmp/students.txt' into table student;
hive> select * from student;

# 退出 hive
hive> exit;
```

### 安装 HBase

[官方下载地址](http://mirrors.hust.edu.cn/apache/hbase)

[官方文档](https://hbase.apache.org/book.html#basic.prerequisites)

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data

# 安装 hbase
ansible-playbook -i ../inventory/dev_hosts_big_data hbase.yml

# 启动 hbase
ansible hbase-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $HBASE_HOME/bin/start-hbase.sh'

# 验证 hbase
jps
hdfs dfs -ls /hbase
$HBASE_HOME/bin/hbase shell
hbase(main):003:0> help
hbase(main):004:0> status
hbase(main):016:0> create 'table1','col1','col2'
hbase(main):017:0> list 'table1'
hbase(main):018:0> describe 'table1'
hbase(main):023:0> put 'table1','yanglei','col2:','35'
hbase(main):024:0> put 'table1','haily','col2:','34'
hbase(main):025:0> scan 'table1'
hbase(main):026:0> get 'table1','yanglei'
hbase(main):028:0> truncate 'table1'
hbase(main):027:0> disable 'table1'
hbase(main):029:0> drop 'table1'
hbase(main):030:0> quit

#web验证
http://172.20.32.131:60010/
http://172.20.32.131:60030/
http://172.20.32.48:60030/
http://172.20.32.59:60030/

# 停止hbase
ansible hbase-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $HBASE_HOME/bin/stop-hbase.sh'

# 调整配置文件
# ansible hbase -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m template -a 'src=./roles/hbase/templates/hbase-site.xml dest=/home/hadoop/hbase-1.2.6.1/conf owner=hadoop group=hadoop mode=644'
# ansible hbase -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m template -a 'src=./roles/hbase/templates/hbase-env.sh dest=/home/hadoop/hbase-1.2.6.1/conf owner=hadoop group=hadoop mode=644'
```

### 安装 scala

[官网下载地址](https://www.scala-lang.org/download/)

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data

# 安装 scala
ansible-playbook -i ../inventory/dev_hosts_big_data scala.yml

# 验证
scala -version
scala
scala> 9*9
scala> :help
scala> :quit
```

#### 参考资料

[为什么Spark要用Scala实现](https://www.zhihu.com/question/27441350)

### 安装 spark

[官方文档](http://spark.apache.org/docs/latest/)

[官方下载](http://spark.apache.org/downloads.html)

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data

# 安装 spark
ansible-playbook -i ../inventory/dev_hosts_big_data spark.yml

# 启动 spark
ansible spark-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $SPARK_HOME/sbin/start-all.sh'

# 验证
spark-shell
scala> :quit 

# web验证
http://172.20.32.131:18080/

# 停止 spark
ansible spark-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $SPARK_HOME/sbin/stop-all.sh'
```

#### 参考资料

[Spark配置参数](http://blog.javachen.com/2015/06/07/spark-configuration.html)

#### Kylin 与 Spark SQL的差异性

Kylin在目前成为大数据平台的神兽，其主要的逻辑的是针对大量的数据进行预处理，将预处理的结果保存在hbase里面，后续的查询针对hbase，于是提高了速度，这样的解决方案也有他的弊端：

1.如果预处理的结果并没有完成，那么查询依旧是全量数据处理，速度不高。
2.如果数据要求实时，此方案做不到。

当然在大数据领域，使用spark sql 作为处理方案的也是大有人在，那么这两类数据处理的方案有何差异性，在此简单的描述下：

SparkSQL本质上是基于DAG模型的MPP。而Kylin核心是Cube(多维立方体)。

关于MPP和Cube预处理的差异，重复如下：

MPP 的基本思路是增加机器来并行计算，从而提高查询速度。比如扫描8亿记录一台机器要处理1小时，但如果用100台机器来并行处理，就只要一分钟不到。再配合列式存储和一些索引，查询可以更快返回。要注意这里在线运算量并没有减小，8亿条记录还是要扫描一次，只是参与的机器多了，所以快了。

MOLAP Cube 是一种预计算技术，基本思路是预先对数据作多维索引，查询时只扫描索引而不访问原始数据从而提速。8亿记录的一个3维索引可能只有几万条记录，规模大大缩小，所以在线计算量大大减小，查询可以很快。索引表也可以采用列存储，并行扫描等MPP常用的技术。但多维索引要对多维度的各种组合作预计算，离线建索引需要较大计算量和时间，最终索引也会占用较多磁盘空间。

除了有无预处理的差异外，SparkSQL与Kylin对数据集大小的偏好也不一样。

如果数据可以基本放入内存，Spark的内存缓存会让SparkSQL有好的表现。

但对于超大规模的数据集，Spark也不能避免频繁的磁盘读写，性能会大幅下降。反过来Kylin的Cube预处理会大幅减小在线数据规模，对于超大规模数据更有优势。

### 安装 kylin

[官方下载](http://kylin.apache.org/cn/download/)

[官方文档](http://kylin.apache.org/cn/docs23/install/index.html)

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data

# 安装 kylin
ansible-playbook -i ../inventory/dev_hosts_big_data kylin.yml

# 启动 kylin
# ansible kylin -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $KYLIN_HOME/bin/kylin.sh start'

# 检查环境
$KYLIN_HOME/bin/check-env.sh  
$KYLIN_HOME/bin/find-hive-dependency.sh
$KYLIN_HOME/bin/find-hbase-dependency.sh
hadoop checknative -a 

# 启动
$KYLIN_HOME/bin/kylin.sh start

# 停止
$KYLIN_HOME/bin/kylin.sh stop

# web验证
http://172.20.32.131:7070/kylin
# 初始用户名和密码是 ADMIN/KYLIN

# 测试kylin
$KYLIN_HOME/bin/sample.sh

# 停止kylin
ansible kylin -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $KYLIN_HOME/bin/kylin.sh stop'
```

kylin 测试语句：

```sql
-- 简单的 count，可以看到耗时 4.12s，再次执行基本在 0.5s 级，基本是毫秒级别就可以查询出来，这是因为 kylin 支持缓存的功能。
select count(*) from kylin_sales;

-- 复杂查询
select sum(KYLIN_SALES.PRICE) 
as price_sum,KYLIN_CATEGORY_GROUPINGS.META_CATEG_NAME,KYLIN_CATEGORY_GROUPINGS.CATEG_LVL2_NAME 
from KYLIN_SALES inner join KYLIN_CATEGORY_GROUPINGS
on KYLIN_SALES.LEAF_CATEG_ID = KYLIN_CATEGORY_GROUPINGS.LEAF_CATEG_ID and 
KYLIN_SALES.LSTG_SITE_ID = KYLIN_CATEGORY_GROUPINGS.SITE_ID
group by KYLIN_CATEGORY_GROUPINGS.META_CATEG_NAME,KYLIN_CATEGORY_GROUPINGS.CATEG_LVL2_NAME
order by KYLIN_CATEGORY_GROUPINGS.META_CATEG_NAME asc,KYLIN_CATEGORY_GROUPINGS.CATEG_LVL2_NAME desc
```

#### 参考资料

[kylin2.1.0+cdh5.10.1+安装部署+官方测试例子详细教程](https://blog.csdn.net/a920259310/article/details/77771917)

[Apache Kylin安装部署](https://segmentfault.com/a/1190000011506398)

[Apache Kylin权威指南](http://book.51cto.com/art/201704/537819.htm)

[Apche Kylin启动报错：UnknownHostException: node1:2181: invalid IPv6 address](https://blog.csdn.net/chengyuqiang/article/details/80490510)

[使用kylin踩过的坑](https://my.oschina.net/aibati2008/blog/745389)

[hive运行报错running beyond virtual memory错误原因及解决办法](https://my.oschina.net/aibati2008/blog/839233)

[YARN的内存和CPU配置](http://blog.javachen.com/2015/06/05/yarn-memory-and-cpu-configuration.html)

### 停用所有大数据组件

```sh
# 停止kylin
ansible kylin -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $KYLIN_HOME/bin/kylin.sh stop'
# 停止spark
ansible spark-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $SPARK_HOME/sbin/stop-all.sh'
# 停止hbase
ansible hbase-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'sh $HBASE_HOME/bin/stop-hbase.sh'
# 停止 history-server
ansible hadoop-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a 'mapred --daemon stop historyserver'
# 停止hadoop
ansible hadoop-master -i ../inventory/dev_hosts_big_data --become --become-method=su --become-user=hadoop -m command -a '$HADOOP_HOME/sbin/stop-all.sh'
```
