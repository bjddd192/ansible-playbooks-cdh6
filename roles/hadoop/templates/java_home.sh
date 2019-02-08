jdk_version=$(ls -al /usr/lib/jvm | grep "^d" | grep "java" | awk '{print$NF}')
export JAVA_HOME=/usr/lib/jvm/$jdk_version
