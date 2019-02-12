# CDH6

为了更加方便地安装 CDH6，减少出错几率，将安装过程封装成项目驱动的形式。

**注意：本项目的运行环境基于 CentOS7.5 + CDH6.01 。**

运行此项目，需要了解以下基础知识：

- linux
- ansible
- docker

## 安装

官方安装文档：[Cloudera Enterprise 6.0.x Installation Guide](https://www.cloudera.com/documentation/enterprise/6/6.0/topics/installation.html)

### 准备工作

#### 准备安装 CDH6 的服务器

硬软件需求：[Cloudera Enterprise 6 Requirements and Supported Versions](https://www.cloudera.com/documentation/enterprise/6/release-notes/topics/rg_requirements_supported_versions.html)

本项目实验环境是使用的是 3 台 `c8m16d250G` 的 CentOS 7.5 的机器：

- 各服务器 root 密码设置为一致
- 磁盘最佳分区格式：ext4
- 数据库：MySQL5.7，使用 UTF8 编码
- JAVA：Oracle JDK 1.8u141 

#### 准备下载服务器

CDH6 官网自身提供了下载服务器地址：

- [cm6](https://archive.cloudera.com/cm6/6.0.1/redhat7/yum/RPMS/x86_64/)
- [cdh6](https://archive.cloudera.com/cdh6/6.0.1/parcels/)

由于国内服务器需要翻墙才能正常下载，且安装包比较大，因此最佳的方式是在内网中搭建一个类似的下载服务器，然后将这些包下载到内网，极大地提升整个安装的效率。

为了简化操作，下载服务器采用 docker 运行。

首先 [安装 docker + docker-compose](https://www.zorin.xin/docker-manual/install/Centos7.html)。

然后在服务器上初始化下载服务器：

```sh
# sfds 意为 static file download service

# 初始化 sfds 配置目录
mkdir -p /data/docker_volumn/sfds

# 初始化数据文件目录
mkdir -p /data/sfds

# 初始化编排文件目录
mkdir -p /data/docker_compose

# 初始化 sfds 配置文件
tee /data/docker_volumn/sfds/nginx.conf <<-'EOF'
worker_processes  1;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
	sendfile        on;
    keepalive_timeout  65;
    server 
    {
        listen        9000;             #端口
        server_name  localhost;         #服务名
        root /usr/share/nginx/html;     #显示的根索引目录   
        autoindex on;                   #开启索引功能
        autoindex_exact_size off;       #关闭计算文件确切大小（单位bytes），只显示大概大小（单位kb、mb、gb）
        autoindex_localtime on;         #显示本机时间而非 GMT 时间
    }
}
EOF

# 初始化编排文件
tee /data/docker_compose/docker-compose.yml <<-'EOF'
version: "3"
services:
  # 文件下载服务器
  sfds:
    image: bjddd192/nginx:1.10.1
    container_name: sfds
    restart: always
    ports:
    - "8066:9000"
    environment:
    - TZ=Asia/Shanghai
    volumes:
    - /data/docker_volumn/sfds/nginx.conf:/etc/nginx/nginx.conf
    - /data/sfds:/usr/share/nginx/html
    network_mode: bridge
EOF

# 启动下载服务器
docker-compose -f /data/docker_compose/docker-compose.yml up -d
```

下载服务器启动好以后，访问一下 `http://serverIP:8066`，如果能正常打开页面，说明下载服务器部署成功。

#### 下载安装包

[Cloudera Manager 6 Version and Download Information](https://www.cloudera.com/documentation/enterprise/6/release-notes/topics/rg_cm_6_version_download.html)

根据官网的下载路径，建立本地目录：

```sh
mkdir -p /data/sfds/cdh6/6.0.1/parcels
mkdir -p /data/sfds/cm6/6.0.1/redhat7/yum/RPMS/x86_64
```

然后将官方的包下载到对应的目录，最终目录结构如下：

```cmd
$ tree /data/sfds/cdh6/6.0.1/parcels
/data/sfds/cdh6/6.0.1/parcels
|-- CDH-6.0.1-1.cdh6.0.1.p0.590678-el7.parcel
|-- CDH-6.0.1-1.cdh6.0.1.p0.590678-el7.parcel.sha256
`-- manifest.json

$ tree /data/sfds/cm6/6.0.1/redhat7/yum/RPMS/x86_64
/data/sfds/cm6/6.0.1/redhat7/yum/RPMS/x86_64
|-- cloudera-manager-agent-6.0.1-610811.el7.x86_64.rpm
|-- cloudera-manager-daemons-6.0.1-610811.el7.x86_64.rpm
|-- cloudera-manager-server-6.0.1-610811.el7.x86_64.rpm
|-- cloudera-manager-server-db-2-6.0.1-610811.el7.x86_64.rpm
`-- oracle-j2sdk1.8-1.8.0+update141-1.x86_64.rpm
```

#### 制作本地YUM仓库

```sh
yum -y install createrepo
cd /data/sfds/cm6/6.0.1/redhat7/yum
createrepo .

# 初始化仓库文件
tee /data/sfds/cm6/6.0.1/redhat7/yum/cloudera-manager.repo <<-'EOF'
[cloudera-manager]
name=Cloudera Manager 6.0.1
baseurl=http://10.240.114.45:8066/cm6/6.0.1/redhat7/yum/
gpgcheck=false
enabled=true
EOF
```

验证仓库：

```sh
wget http://10.240.114.45:8066/cm6/6.0.1/redhat7/yum/cloudera-manager.repo -P /etc/yum.repos.d/
rpm --import http://10.240.114.45:8066/cm6/6.0.1/redhat7/yum/RPM-GPG-KEY-cloudera
yum makecache
yum search cloudera
yum search cloudera-manager-daemons cloudera-manager-agent cloudera-manager-server
```

能够正常找到包说明本地YUM仓库制作成功。

#### 数据库准备

```sql
-- drop database db_cdh6_scm;
create database db_cdh6_scm default character set utf8 default collate utf8_general_ci;
grant all on db_cdh6_scm.* to 'user_cdh6'@'%' identified by '123456';
flush privileges;

-- 为hive建库hive
create database db_cdh_hive;

-- 为Activity Monitor建库amon
create database db_cdh_amon;

-- 为Oozie建库oozie
create database db_cdh_oozie;

-- 为Hue建库hue
create database db_cdh_hue;
```

#### ansible 配置

[ansible 安装与配置](https://www.zorin.xin/2018/08/05/ansible-install-and-config/)

本人是使用 mac 安装了 ansible 作为主控。

```sh
# 配置到服务器的信任
ssh-copy-id -p 60777 root@192.168.200.151

# 测试连接
ansible cdh-cluster -i inventory/uat_cdh6.ini -m ping
```

### Cloudera Manager(CDH5)目录位置

```sh
/var/log/cloudera-scm-installer : 安装日志目录。
/var/log/* : 相关日志文件（相关服务的及CM的）。
/usr/share/cmf/ : 程序安装目录。
/usr/lib64/cmf/ : Agent程序代码。
/var/lib/cloudera-scm-server-db/data : 内嵌数据库目录。
/usr/bin/postgres : 内嵌数据库程序。
/etc/cloudera-scm-agent/ : agent的配置目录。
/etc/cloudera-scm-server/ : server的配置目录。
/opt/cloudera/parcels/ : Hadoop相关服务安装目录。
/opt/cloudera/parcel-repo/ : 下载的服务软件包数据，数据格式为parcels。
/opt/cloudera/parcel-cache/ : 下载的服务软件包缓存数据。
/etc/hadoop/* : 客户端配置文件目录。
```

### 服务器 DNS 检测

```
# 检查 DNS 正向解析与反向解析是否正常
yum -y install bind-utils
nslookup bjds-kubernetes-node-pre-10-240-114-34-vm.belle.lan
nslookup bjds-kubernetes-node-pre-10-240-114-38-vm.belle.lan
nslookup bjds-kubernetes-node-pre-10-240-114-65-vm.belle.lan
nslookup -qt 10.240.114.34
nslookup -qt 10.240.114.38
nslookup -qt 10.240.114.65
```

### 部署 CDH

CDH(Cloudera’s Distribution，including Apache Hadoop)，是 Hadoop 分支中的一种，由 Cloudera 维护，基于稳定版本的 Apache hadoop 构建，并继承了许多补丁，可以直接用于生产环境。 

```sh
cd /Users/yanglei/01_git/github_me/ansible-playbooks-cdh6

# 测试连接
ansible cdh-cluster -i inventory/uat_cdh6.ini -m ping
ansible cdh-cluster -i inventory/uat_cdh6.ini -m command -a "date"

# 安装公共组件
ansible-playbook -t common -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml cdh.yml

# 安装 jdk
ansible-playbook -t jdk -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml cdh.yml

# 设置 server 免密登录 agent
ansible-playbook -t ssh -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml cdh.yml

# 安装 scm
ansible-playbook -t cm -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml cdh.yml

# 在 cdh-server 节点检查服务状态
# 检查 scm 数据库是否已经自动创建了表结构
# 如果都正常说明 scm 安装完成
systemctl status cloudera-scm-agent.service
systemctl status cloudera-scm-server.service

# 放置 cdh 离线安装包
ansible-playbook -t cdh -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml cdh.yml
```

然后，启动 Web 控制台进行配置，地址如：http://10.240.114.34:7180 ，默认用户名密码都是：admin。

控制台的配置步骤也有不少，根据参考资料搜集的博客进行配置即可，启动后可能会遇到一些环境的错误问题或者集群优化的提示，不用慌，上网一个个找资料解决。个人经验是先看看服务器的内存是不是够用，内存充足的话集群运行会正常很多，减少不必要的麻烦。

检查各依赖组件是否都已安装完成：

* Hadoop: 2.7+
* Hive: 0.13 - 1.2.1+
* HBase: 1.1+
* Spark (可选) 2.1.1+
* Kafka (可选) 0.10.0+
* JDK: 1.7+
* OS: Linux only, CentOS 6.5+ or Ubuntu 16.0.4+

Web 查看各组件的状态信息：

hdfs_namenode：http://172.20.32.126:50070/
hadoop_yarn_resourcemanager：/http://172.20.32.126:8088/



### 部署 Kylin

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data

ansible kylin -i inventory/uat_cdh6.ini -m ping

# 安装 kylin
ansible-playbook -i inventory/uat_cdh6.ini kylin.yml

# 给 spark 添加 jars 目录的软链接
ansible kylin -i inventory/uat_cdh6.ini -m file -a 'src=/opt/cloudera/parcels/CDH/jars dest=$SPARK_HOME/jars state=link'

# 用软链接短 HIVE_LIB 路径长度，防止 kylin 启动出现“参数列表过长”的问题
ansible kylin -i inventory/uat_cdh6.ini -m file -a 'src=$HIVE_HOME/lib dest=/hivelib state=link'

# 检查环境
su - hdfs
# hdfs dfs -chmod -R 777 /
$KYLIN_HOME/bin/check-env.sh  
$KYLIN_HOME/bin/find-hive-dependency.sh
$KYLIN_HOME/bin/find-hbase-dependency.sh
$KYLIN_HOME/bin/find-spark-dependency.sh

# 启动
$KYLIN_HOME/bin/kylin.sh start

# 停止
$KYLIN_HOME/bin/kylin.sh stop

# web验证
http://172.20.32.131:7070/kylin
# 初始用户名和密码是 ADMIN/KYLIN

# 测试kylin
$KYLIN_HOME/bin/sample.sh
```

### CDH 安装 spark2

CDH-5.15.0 默认支持的还是 spark1.6 版本。这里需要将 spark 升级到spark2.x 版本。

```sh
# 安装 cdh
ansible-playbook -i inventory/uat_cdh6.ini cdh-spark2.yml
```

然后在CM中下载，分配，激活。 
停掉CM和集群，现在将他们停掉。运行命令：

```sh
# 在 master 节点重新启动 cloudera-scm-server
/home/cdh/cm-5.15.0/etc/init.d/cloudera-scm-server restart  

#在每个 worker 节点重新启动 cloudera-scm-agent
/home/cdh/cm-5.15.0/etc/init.d/cloudera-scm-agent restart 
```

### 部署 ETL 工具 sqoop

因 CDH 版本已自带了 sqoop 的安装，故以下可以跳过，仅作为参考。

```sh
cd /Users/yanglei/01_git/oschina/ansible/big_data 

# 安装 sqoop1
ansible-playbook -i inventory/uat_cdh6.ini sqoop1.yml
```

sqoop 常用命令：

```sh
# 查看帮助信息
sqoop help
```

### sqoop 常用操作

**全量导入**

```sh
# 列出 mysql 数据库中的所有数据库
sqoop list-databases \
--connect jdbc:mysql://dev.db.belle.cn:3306 \
--username root --password "blf1#root"

# 列出 mysql 数据库中的表
sqoop list-tables \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password 'blf1#root'

# 全表导入到 hdfs，目录必须不存在
# 导入是一个 mapreduce 的过程
# 表必须有主键
# --warehouse-dir 指定导入的目录
# -m 指定并行度，决定生成多少个文件，默认并行度是 4
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_province \
--warehouse-dir /user/yanglei/sqoop \
-m 1

# 查看导入的数据
hdfs dfs -cat /user/yanglei/sqoop/bas_province/part-m-00000

# 删除已导入的数据
hdfs dfs -rm -R /user/yanglei/sqoop

# 导入数据用 | 分割，默认是 , 号分割
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_province \
--warehouse-dir /user/yanglei/sqoop \
-m 1 \
--fields-terminated-by "|"

# 导入部分数据(使用--where)
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_province \
--where "direct_controlled=1" \
--warehouse-dir /user/yanglei/sqoop \
-m 1

# 导入部分数据(使用--query)
# 注意 --target-dir 与 --warehouse-dir 的区别，--target-dir 不会再使用表名创建目录
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--query "select * from bas_province where direct_controlled=0 and \$CONDITIONS" \
--delete-target-dir \
--target-dir /user/yanglei/sqoop/bas_province \
-m 1

# 指定导入的列(使用--query)
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--query "select province_no,province_name from bas_province where direct_controlled=0 and \$CONDITIONS" \
--delete-target-dir \
--target-dir /user/yanglei/sqoop/bas_province \
-m 1

# 导入部分数据(使用--cloumns)
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_province \
--cloumns province_no,province_name
--where "direct_controlled=1" \
--warehouse-dir /user/yanglei/sqoop \
-m 1
```

**增量导入**

```sh
# 先导入部分数据
# 指定分隔符是为了防止有特殊的数据(比如：在这里就遇到了包含逗号的数据，与默认的重复了，导致后面的数据合并失败)
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_category \
--where "category_id <= 10" \
--fields-terminated-by "\t" \
--warehouse-dir /user/yanglei/sqoop \
-m 1

# 查看导入的数据
hdfs dfs -cat /user/yanglei/sqoop/bas_category/part-m-00000

# 按 id 增量导入
# --check-column 增量检查的列，一般是时间戳字段或者主键，不能是字符类型
# --incremental 指定增量的模式，有 append 和 lastmodified
# 增量导入会在 hdfs 中新生成增量文件，而不是在原文件上追加
# 因此，如果重复执行增量导入，会导致重复导入，造成数据冗余
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_category \
--check-column category_id \
--incremental append \
--last-value 10 \
--fields-terminated-by "\t" \
--warehouse-dir /user/yanglei/sqoop \
-m 1

# 按时间戳增量导入
# merge 后文件数变多了
sqoop import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_category \
--check-column update_time \
--incremental lastmodified \
--last-value "2018-08-22 09:48:20" \
--merge-key category_id \
--fields-terminated-by "\t" \
--warehouse-dir /user/yanglei/sqoop \
-m 1

# 查看导入的数据
hdfs dfs -cat /user/yanglei/sqoop/bas_category/part-r-00000

# 使用 sqoop job
# 注意 -- import，而不是 --import
sqoop job \
--create job-incremental-import-bas_category \
-- import \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_category \
--check-column update_time \
--incremental lastmodified \
--last-value "2018-08-22 09:48:20" \
--merge-key category_id \
--fields-terminated-by "\t" \
--warehouse-dir /user/yanglei/sqoop \
-m 1

# 查看 sqoop job list
sqoop job --list

# 查看指定的 sqoop job，需要输入密码，密码为数据库的密码
sqoop job --show job-incremental-import-bas_category

# 执行指定的 sqoop job
sqoop job --exec job-incremental-import-bas_category

# 删除指定的 sqoop job
sqoop job --delete job-incremental-import-bas_category

# 解决 sqoop 需要输入密码的问题
# 修改配置文件：/opt/cloudera/parcels/CDH-5.15.0-1.cdh5.15.0.p0.21/etc/sqoop/conf.dist/sqoop-site.xml，取消以下代码的注释。
<property>
    <name>sqoop.metastore.client.record.password</name>
    <value>true</value>
    <description>If true, allow saved passwords in the metastore.
    </description>
</property>
```

**全量导出**

```sh
# 创建一个与 bas_category 结构一样且没有数据的空表
# 如果不是空表或者表不存在都会报错
mysql -hdev.db.belle.cn -P3306 -uroot -p'blf1#root' cat_biz_bl -e "CREATE TABLE bas_category2 LIKE bas_category";

# 执行全量导出
# 注意目录要到 bas_category 所处那一层
sqoop export \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_category2 \
--fields-terminated-by "\t" \
--export-dir /user/yanglei/sqoop/bas_category

# 覆盖导出，updateonly 模式仅做更新
sqoop export \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_category2 \
--fields-terminated-by "\t" \
--export-dir /user/yanglei/sqoop/bas_category \
--update-key category_id \
--update-mode updateonly

# 覆盖导入，常用的是 allowinsert 模式，会执行插入和更新，但是表要有主键，防止重复导入
sqoop export \
--connect jdbc:mysql://dev.db.belle.cn:3306/cat_biz_bl \
--username root --password blf1#root \
--table bas_category2 \
--fields-terminated-by "\t" \
--export-dir /user/yanglei/sqoop/bas_category \
--update-key category_id \
--update-mode allowinsert
```

### 卸载 CDH

```sh
# 清除 CDH
# 破坏力很大，摧毁整个 cloudera 的时候使用
systemctl stop cloudera-scm-agent
systemctl stop cloudera-scm-server
ps -ef | grep cloudera | awk '{print $3}' | xargs kill -9
ps -ef | grep cloudera

# 清理安装目录
rm -rf /dfs
rm -rf /yarn
rm -rf /var/lib/cloudera-host-monitor
rm -rf /var/lib/cloudera-service-monitor
rm -rf /var/lib/cloudera-scm*
rm -rf /var/lib/oozie
rm -rf /var/lib/zookeeper
rm -rf /var/lib/flume-ng 
rm -rf /var/lib/hadoop* 
rm -rf /var/lib/hue  
rm -rf /var/lib/navigator  
rm -rf /var/lib/solr 
rm -rf /var/lib/sqoop*
rm -rf /var/lib/hive
rm -rf /var/lib/impala
rm -rf /var/lib/hbase
rm -rf /var/lib/spark
rm -rf /var/lib/sentry
rm -rf /var/lib/llama

# 删除软链接
# 这里删除后重启会无效，可能是由于CDH使用了alternatives造成的
# 下次尝试使用 alternatives --list 命令移除一下软连接看看
# https://www.linuxidc.com/Linux/2016-12/138986.htm
cd /etc/alternatives
ll /etc/alternatives | grep CDH-5.11.2 | awk '{print $9}' | xargs rm -rf
ll /etc/alternatives | grep CDH-5.15.0 | awk '{print $9}' | xargs rm -rf
 
umount /home/cdh/cm-5.15.0/run/cloudera-scm-agent/process
rm -rf /home/cdh/ 

# rm -rf /opt/cloudera
```

### 其他技巧

在Cloudrea Manager页面上，可以向集群中添加/删除主机，添加服务到集群等。

Cloudrea Manager页面开启了google-analytics，因为从国内访问很慢，可以关闭google-analytics

管理 -> 设置 -> 其他 -> 允许使用情况数据收集 不选

### 参考资料

[CentOS7 ntp 服务器配置](https://www.cnblogs.com/harrymore/p/9566229.html)

[CentOS7 配置 ntp 时间服务器](https://blog.csdn.net/zzy5066/article/details/79036674)

[CentOS7 中使用NTP进行时间同步](http://www.cnblogs.com/yangxiansen/p/7860008.html)

### 参考资料

[CDH5和Cloudera Manager5对环境的要求](http://wsppstwo.iteye.com/blog/2342249)

[离线安装Cloudera Manager 5.11.1和CDH5.11.1完全教程](https://blog.csdn.net/u011026329/article/details/79166626)

[cloudera manager5.13.1离线安装记录](https://segmentfault.com/a/1190000012540680)

[CentOS7下安装Cloudera Manager5.14.1](http://cxy7.com/articles/2018/03/23/1521816625594.html)

[DNS正向解析与反向解析](https://www.cnblogs.com/kasumi/p/6117941.html)

[CDH的错误排查](https://blog.csdn.net/zzq900503/article/details/53393721)

[cdh5.14.2中集成安装kylin与使用测试](http://blog.51cto.com/flyfish225/2128254)

[Apache Kylin 单实例部署](https://ijunjie.github.io/post/programming/kylin-setup/)

[CDH5.15搭建](https://blog.csdn.net/qq1226317595/article/details/80857473)

[CDH 5.13安装spark2](https://www.jianshu.com/p/6acd6419f697)

[Sqoop1 详细使用和避坑指南](https://blog.csdn.net/afanyusong/article/details/79065277)