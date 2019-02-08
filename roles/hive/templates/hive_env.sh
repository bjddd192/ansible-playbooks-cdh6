export HIVE_HOME={{ hive_path }}
export PATH=$HIVE_HOME/bin:$PATH
export CLASSPATH=$CLASSPATH.:$HIVE_HOME/lib
export HIVE_CONF_DIR={{ hive_config_path }}