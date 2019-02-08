export BASE_PATH={{ cdh_base_path }}
export HBASE_HOME=$BASE_PATH/hbase
export PATH=$HBASE_HOME/bin:$PATH
export HADOOP_HOME=$BASE_PATH/hadoop
export PATH=$HADOOP_HOME/bin:$PATH
export HIVE_HOME=$BASE_PATH/hive
export PATH=$HIVE_HOME/bin:$PATH
export HCAT_HOME=$BASE_PATH/hive-hcatalog
export PATH=$HCAT_HOME/bin:$PATH
export SQOOP_HOME=$BASE_PATH/sqoop
export PATH=$SQOOP_HOME/bin:$PATH
# export SPARK_HOME=$BASE_PATH/spark
# export PATH=$SPARK_HOME/bin:$PATH
# 用软链接短 HIVE_LIB 路径长度，防止出现“参数列表过长”的问题
# export HIVE_LIB=/hivelib
# export PATH=$HIVE_LIB/bin:$PATH
