### 安装 zookeeper

[官方地址](http://zookeeper.apache.org/releases.html)

[安装包官方下载地址](http://mirror.bit.edu.cn/apache/zookeeper/)

[参考项目](https://gitee.com/pippozq/zookeeper-ansible)

[待参考优秀项目](https://github.com/sleighzy/ansible-zookeeper)

操作说明：

1. 在 inventory 中配置hosts
2. 在当前工程目录执行 ansible 脚本，如：

```sh
# 添加认证用户
ssh-copy-id zookeeper@172.20.32.60
ssh-copy-id zookeeper@172.20.32.48
ssh-copy-id zookeeper@172.20.32.59

# 安装zookeeper集群
cd /Users/yanglei/01_git/oschina/ansible/zookeeper
ansible-playbook -i ../inventory/dev_hosts_zookeeper install.yml

# 启动zookeeper集群
ansible zookeeper -i ../inventory/dev_hosts_zookeeper  --become-user=zookeeper -m command -a 'echo $ZK_HOME'
ansible zookeeper -i ../inventory/dev_hosts_zookeeper --become --become-method=su --become-user=zookeeper -m command -a 'sh $ZK_HOME/bin/zkServer.sh start'

# 查看集群状态（一台为leader，两台为follower）
ansible zookeeper -i ../inventory/dev_hosts_zookeeper --become --become-method=su --become-user=zookeeper -m command -a 'sh $ZK_HOME/bin/zkServer.sh status'

#停止zookeeper集群
ansible zookeeper -i ../inventory/dev_hosts_zookeeper --become --become-method=su --become-user=zookeeper -m command -a 'sh $ZK_HOME/bin/zkServer.sh stop'
$ZK_HOME/bin/zkCli.sh -server 172.20.32.59:2181

# 集群验证（在一个节点创建一个目录，其余节点也能查看）
$ZK_HOME/bin/zkCli.sh -server 172.20.32.60:2181
[zk: 172.20.32.60:2181(CONNECTED) 0] create /project zookeeper_project
[zk: 172.20.32.60:2181(CONNECTED) 1] get /project
[zk: 172.20.32.60:2181(CONNECTED) 2] quit
$ZK_HOME/bin/zkCli.sh -server 172.20.32.59:2181
[zk: 172.20.32.60:2181(CONNECTED) 0] get /project
[zk: 172.20.32.60:2181(CONNECTED) 1] quit
```

重装大数据环境，报异常： org.apache.hadoop.hbase.TableExistsException: kylin_metadata_user

需要手工处理zookeeper数据解决：

```sh
$ZK_HOME/bin/zkCli.sh -server 172.20.32.60:2181
[zk: 172.20.32.60:2181(CONNECTED) 0] ls /
[project, zookeeper, hbase, kylin]
[zk: 172.20.32.60:2181(CONNECTED) 2] rmr /kylin
[zk: 172.20.32.60:2181(CONNECTED) 3] ls /      
```