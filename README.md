# CDH6

CDH(Cloudera’s Distribution，including Apache Hadoop)，是 Hadoop 分支中的一种，由 Cloudera 维护，基于稳定版本的 Apache hadoop 构建，并继承了许多补丁，可以直接用于生产环境。

由于整个安装过程涉及了多台服务器，为了更加方便地安装 CDH6，减少出错几率，将安装过程封装成项目驱动的形式。

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

IP            | HostName                                            | OS         | Cores | Memory | Disk | Remark
--------------|-----------------------------------------------------|------------|-------|--------|------|---------------
10.240.114.34 | bjds-kubernetes-node-pre-10-240-114-34-vm.belle.lan | CentOS 7.5 | 8     | 16G    | 250  | Server & Agent
10.240.114.38 | bjds-kubernetes-node-pre-10-240-114-38-vm.belle.lan | CentOS 7.5 | 8     | 16G    | 250  | Agent
10.240.114.65 | bjds-kubernetes-node-pre-10-240-114-65-vm.belle.lan | CentOS 7.5 | 8     | 16G    | 250  | Agent
10.240.114.67 | bjds-kubernetes-node-pre-10-240-114-67-vm.belle.lan | CentOS 7.5 | 8     | 16G    | 250  | Agent
10.240.114.54 | bjds-kubernetes-node-pre-10-240-114-54-vm.belle.lan | CentOS 7.5 | 8     | 16G    | 250  | MySQL 5.7.24
10.240.114.45 | bjds-kubernetes-node-pre-10-240-114-45-vm.belle.lan | CentOS 7.5 | 8     | 16G    | 250  | 下载服务器

#### 准备下载服务器

CDH6 官网自身提供了下载服务器地址：

- [cm6](https://archive.cloudera.com/cm6/6.0.1/redhat7/yum/RPMS/x86_64/)
- [cdh6](https://archive.cloudera.com/cdh6/6.0.1/parcels/)

由于国内服务器需要翻墙才能正常下载，且安装包比较大，因此最佳的方式是在内网中搭建一个类似的下载服务器，然后将这些包下载到内网，极大地提升整个安装的效率。

为了简化操作，下载服务器采用 docker 运行。

首先 [安装 docker + docker-compose](https://www.zorin.xin/docker-manual/install/Centos7.html)。

然后在服务器上初始化下载服务器：

```sh
# sfds 意为 static file download service

# 初始化 sfds 配置目录
mkdir -p /data/docker_volumn/sfds

# 初始化数据文件目录
mkdir -p /data/sfds

# 初始化编排文件目录
mkdir -p /data/docker_compose

# 初始化 sfds 配置文件
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

数据库最好选择 MySQL 5.5.45+, 5.6.26+ and 5.7.6+ 版本，本实验环境使用的是 5.7.24 的版本。

```sql
-- 删除数据库(如重新部署时使用)
-- drop database db_cdh6_scm;
-- drop database db_cdh6_amon;
-- drop database db_cdh6_rmon;
-- drop database db_cdh6_hue;
-- drop database db_cdh6_metastore;
-- drop database db_cdh6_sentry;
-- drop database db_cdh6_nav;
-- drop database db_cdh6_navms;
-- drop database db_cdh6_oozie;

-- 创建数据库
create database db_cdh6_scm default character set utf8 default collate utf8_general_ci;
create database db_cdh6_amon default character set utf8 default collate utf8_general_ci;
create database db_cdh6_rmon default character set utf8 default collate utf8_general_ci;
create database db_cdh6_hue default character set utf8 default collate utf8_general_ci;
create database db_cdh6_metastore default character set utf8 default collate utf8_general_ci;
create database db_cdh6_sentry default character set utf8 default collate utf8_general_ci;
create database db_cdh6_nav default character set utf8 default collate utf8_general_ci;
create database db_cdh6_navms default character set utf8 default collate utf8_general_ci;
create database db_cdh6_oozie default character set utf8 default collate utf8_general_ci;

-- 简单练习使用相同的数据库用户，如果用于线上环境最好是分别使用独立的用户。
grant all on db_cdh6_scm.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_amon.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_rmon.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_hue.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_metastore.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_sentry.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_nav.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_navms.* to 'user_cdh6'@'%' identified by '123456';
grant all on db_cdh6_oozie.* to 'user_cdh6'@'%' identified by '123456';

-- 刷新权限
flush privileges;
```

#### ansible 配置

[ansible 安装与配置](https://www.zorin.xin/2018/08/05/ansible-install-and-config/)

本人是使用 mac 安装了 ansible 作为主控。

```sh
# 配置到服务器的信任
ssh-copy-id -p 60777 root@10.240.114.34
ssh-copy-id -p 60777 root@10.240.114.38
ssh-copy-id -p 60777 root@10.240.114.65
ssh-copy-id -p 60777 root@10.240.114.67

# 测试连接
ansible cdh-cluster -i inventory/uat_cdh6.ini -m ping
```

### 部署 CDH 

#### 安装 CM 和 CDH

```sh
cd /Users/yanglei/01_git/github_me/ansible-playbooks-cdh6

# 测试连接
ansible cdh-cluster -i inventory/uat_cdh6.ini -m ping
ansible cdh-cluster -i inventory/uat_cdh6.ini -m command -a "date"

# 安装公共组件
ansible-playbook -t common -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml 01.cdh.yml

# 安装 jdk
ansible-playbook -t jdk -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml 01.cdh.yml

# 设置 server 免密登录 agent
ansible-playbook -t ssh -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml 01.cdh.yml

# 安装 scm
ansible-playbook -t cm -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml 01.cdh.yml

# 放置 cdh 离线安装包
ansible-playbook -t cdh -i inventory/uat_cdh6.ini -e @inventory/uat_cdh6.yml 01.cdh.yml

# 在 cdh-server 节点检查服务状态
# 检查 scm 数据库是否已经自动创建了表结构
# 如果都正常说明 scm 安装完成
systemctl status cloudera-scm-agent.service
systemctl status cloudera-scm-server.service
# 查看日志
tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log
```

#### 集群配置

![cm_install_step_01.png](/images/cm_install_step_01.png)
启动 Web 控制台进行配置，地址如：http://10.240.114.34:7180/cmf/login ，默认用户名密码都是：admin。

![cm_install_step_02.png](/images/cm_install_step_02.png)
点击"继续"。

![cm_install_step_03.png](/images/cm_install_step_03.png)
接受许可。

![cm_install_step_04.png](/images/cm_install_step_04.png)
这里选择免费版，收费版请自行选择。

![cm_install_step_05.png](/images/cm_install_step_05.png)
点击"继续"。

![cm_install_step_06.png](/images/cm_install_step_06.png)
选择"当前管理的主机"。

![cm_install_step_07.png](/images/cm_install_step_07.png)
看到 CDH-6.0.1 版本可选后，点击"继续"。

![cm_install_step_08.png](/images/cm_install_step_08.png)
等待 CDH 包安装完成，点击"继续"。

![cm_install_step_09.png](/images/cm_install_step_09.png)

![cm_install_step_10.png](/images/cm_install_step_10.png)
点击"完成"。

![cm_install_step_11.png](/images/cm_install_step_11.png)
根据自己的需求选取服务。

![cm_install_step_12.png](/images/cm_install_step_12.png)
自定义角色分配。

![cm_install_step_13.png](/images/cm_install_step_13.png)
数据库设置。

![cm_install_step_14.png](/images/cm_install_step_14.png)
审核更改，如果有特定目录的设定或者参数的设定，可以在这里进行更正。

![cm_install_step_15.png](/images/cm_install_step_15.png)
等待首次运行完成。

![cm_install_step_16.png](/images/cm_install_step_16.png)

![cm_install_step_17.png](/images/cm_install_step_17.png)

![cm_install_step_18.png](/images/cm_install_step_18.png)
顺利进入管理控制台，部署基本完成。

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

### 卸载 CDH

```sh
ansible-playbook -i inventory/uat_cdh6.ini 99.clean_all.yml

# 然后删除已创建的数据库
```

### CDH 配置

#### 目录位置

路径                                   | 说明
---------------------------------------|------------------------------
/var/lib/cloudera-scm-server           | 服务端目录
/var/log/cloudera-scm-*                | CM 日志目录
/opt/cloudera/parcels/                 | Hadoop 相关服务安装目录
/opt/cloudera/parcel-repo/             | 下载的服务软件包数据(parcels)
/opt/cloudera/parcel-cache             | 下载的服务软件包缓存数据
/opt/cloudera/parcels/CDH/jars         | CDH 所有 jar 包所在目录
/etc/cloudera-scm-agent/config.ini     | CM Agent 的配置文件
/etc/cloudera-scm-server/              | CM Server 的配置目录
/etc/cloudera-scm-server/db.properties | CM Server 的数据库配置
/etc/hadoop/*                          | hadoop客户端配置目录
/etc/hive/                             | hive 的配置目录
...                                    |

#### 环境变量

CDH 自身有一个环境变量脚本，如下：

```sh
cat /opt/cloudera/parcels/CDH/meta/cdh_env.sh
#!/bin/bash
CDH_DIRNAME=${PARCEL_DIRNAME:-"CDH-6.0.1-1.cdh6.0.1.p0.590678"}
export CDH_HADOOP_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop
export CDH_MR1_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop-0.20-mapreduce
export CDH_HDFS_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop-hdfs
export CDH_HTTPFS_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop-httpfs
export CDH_MR2_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop-mapreduce
export CDH_YARN_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop-yarn
export CDH_HBASE_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hbase
export CDH_ZOOKEEPER_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/zookeeper
export CDH_HIVE_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hive
export CDH_HUE_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hue
export CDH_OOZIE_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/oozie
export CDH_HUE_PLUGINS_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop
export CDH_FLUME_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/flume-ng
export CDH_PIG_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/pig
export CDH_HCAT_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hive-hcatalog
export CDH_SENTRY_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/sentry
export JSVC_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/bigtop-utils
export CDH_HADOOP_BIN=$CDH_HADOOP_HOME/bin/hadoop
export CDH_IMPALA_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/impala
export CDH_SOLR_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/solr
export CDH_HBASE_INDEXER_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hbase-solr
export SEARCH_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/search
export CDH_SPARK_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/spark
export WEBHCAT_DEFAULT_XML=$PARCELS_ROOT/$CDH_DIRNAME/etc/hive-webhcat/conf.dist/webhcat-default.xml
export CDH_KMS_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/hadoop-kms
export CDH_PARQUET_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/parquet
export CDH_AVRO_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/avro
export CDH_KAFKA_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/kafka
export CDH_KUDU_HOME=$PARCELS_ROOT/$CDH_DIRNAME/lib/kudu
```

#### 其他技巧

在Cloudrea Manager页面上，可以向集群中添加/删除主机，添加服务到集群等。

Cloudrea Manager页面开启了google-analytics，因为从国内访问很慢，可以关闭google-analytics

管理 -> 设置 -> 其他 -> 允许使用情况数据收集 不选

### 参考资料

#### 部署相关

[CentOS7 ntp 服务器配置](https://www.cnblogs.com/harrymore/p/9566229.html)

[CentOS7 配置 ntp 时间服务器](https://blog.csdn.net/zzy5066/article/details/79036674)

[CentOS7 中使用NTP进行时间同步](http://www.cnblogs.com/yangxiansen/p/7860008.html)

[Cloudera Manager 和CDH6.0.1安装，卸载，各步骤截图](https://blog.csdn.net/tototuzuoquan/article/details/85111018)

[CentOS7.5,CDH6安装部署](https://blog.csdn.net/TXBSW/article/details/84648269)

[CDH 最新版本 6.0.1 安装详解](https://blog.csdn.net/u010003835/article/details/85007946)

[CentOS 7下Cloudera Manager及CDH 6.0.1安装过程详解](https://www.cnblogs.com/wzlinux/p/10183357.html)

[CDH5.15卸载指南](https://blog.csdn.net/weixin_35852328/article/details/81774627)

#### 配置相关

[CDH5快速入门手册](https://www.jianshu.com/p/72dc1c591647)
