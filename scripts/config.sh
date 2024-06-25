#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/utils.sh"



function generate_hadoop_ha_core_site() {

  export CORE_CONF_fs_defaultFS=hdfs://mycluster
  export CORE_CONF_hadoop_tmp_dir=/opt/module/hadoop-ha/hadoop-3.1.3/data
  export CORE_CONF_ha_zookeeper_quorum=hadoop101:2181,hadoop102:2181,hadoop103:2181

  configure_hadoop_xmls "../conf/hadoop-ha/temp/core-site.xml" core CORE_CONF

}

function generate_hadoop_ha_hdfs_site() {

  export HA_HDFS_CONF_dfs_namenode_name_dir=file://\${hadoop.tmp.dir}/name
  export HA_HDFS_CONF_dfs_datanode_data_dir=file://\${hadoop.tmp.dir}/data
  export HA_HDFS_CONF_dfs_journalnode_edits_dir=\${hadoop.tmp.dir}/jn
  # <!-- 完全分布式集群名称 -->
  export HA_HDFS_CONF_dfs_nameservices=mycluster
  # <!-- 集群中 NameNode 节点都有哪些 -->
  export HA_HDFS_CONF_dfs_ha_namenodes_mycluster=nn1,nn2,nn3
  # <!-- NameNode 的 RPC 通信地址 -->
  export HA_HDFS_CONF_dfs_namenode_rpc__address_mycluster_nn1=hadoop101:8020
  export HA_HDFS_CONF_dfs_namenode_rpc__address_mycluster_nn2=hadoop102:8020
  export HA_HDFS_CONF_dfs_namenode_rpc__address_mycluster_nn3=hadoop103:8020
  # <!-- NameNode 的 http 通信地址 -->
  export HA_HDFS_CONF_dfs_namenode_http__address_mycluster_nn1=hadoop101:9870
  export HA_HDFS_CONF_dfs_namenode_http__address_mycluster_nn2=hadoop102:9870
  export HA_HDFS_CONF_dfs_namenode_http__address_mycluster_nn3=hadoop103:9870
  # <!-- 访问代理类：client 用于确定哪个 NameNode 为 Active -->
  export HA_HDFS_CONF_dfs_client_failover_proxy_provider_mycluster=org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider
  export HA_HDFS_CONF_dfs_ha_fencing_methods=sshfence
  # <!-- 使用隔离机制时需要 ssh 秘钥登录 -->
  export HA_HDFS_CONF_dfs_ha_fencing_ssh_private__key__files=/home/bigdata/.ssh/id_rsa
  #<!-- 启用 nn 故障自动转移 -->
  export HA_HDFS_CONF_dfs_ha_automatic__failover_enabled=true

  configure_hadoop_xmls "../conf/hadoop-ha/temp/hdfs-site.xml" hdfs HA_HDFS_CONF

}

function generate_hadoop_ha_yarn_site() {

  export HA_YARN_CONF_yarn_nodemanager_aux__services=mapreduce_shuffle
  export HA_YARN_CONF_yarn_resourcemanager_ha_enabled=true
  export HA_YARN_CONF_yarn_resourcemanager_cluster__id=cluster-yarn1

  export HA_YARN_CONF_yarn_resourcemanager_ha_rm__ids=rm1,rm2,rm3

  export HA_YARN_CONF_yarn_resourcemanager_hostname_rm1=hadoop101
  export HA_YARN_CONF_yarn_resourcemanager_webapp_address_rm1=hadoop101:8088
  export HA_YARN_CONF_yarn_resourcemanager_address_rm1=hadoop101:8032
  export HA_YARN_CONF_yarn_resourcemanager_scheduler_address_rm1=hadoop101:8030
  export HA_YARN_CONF_yarn_resourcemanager_resource__tracker_address_rm1=hadoop101:8031

  export HA_YARN_CONF_yarn_resourcemanager_hostname_rm2=hadoop102
  export HA_YARN_CONF_yarn_resourcemanager_webapp_address_rm2=hadoop102:8088
  export HA_YARN_CONF_yarn_resourcemanager_address_rm2=hadoop102:8032
  export HA_YARN_CONF_yarn_resourcemanager_scheduler_address_rm2=hadoop102:8030
  export HA_YARN_CONF_yarn_resourcemanager_resource__tracker_address_rm2=hadoop102:8031

  export HA_YARN_CONF_yarn_resourcemanager_hostname_rm3=hadoop103
  export HA_YARN_CONF_yarn_resourcemanager_webapp_address_rm3=hadoop103:8088
  export HA_YARN_CONF_yarn_resourcemanager_address_rm3=hadoop103:8032
  export HA_YARN_CONF_yarn_resourcemanager_scheduler_address_rm3=hadoop103:8030
  export HA_YARN_CONF_yarn_resourcemanager_resource__tracker_address_rm3=hadoop103:8031

  export HA_YARN_CONF_yarn_resourcemanager_zk__address=true
  export HA_YARN_CONF_yarn_resourcemanager_recovery_enabled=true
  export HA_YARN_CONF_yarn_resourcemanager_store_class=org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore

  export HA_YARN_CONF_yarn_nodemanager_env__whitelist=JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME



  configure_hadoop_xmls "../conf/hadoop-ha/temp/yarn-site.xml" yarn HA_YARN_CONF

}



function main() {
    generate_hadoop_ha_core_site
    generate_hadoop_ha_hdfs_site
    generate_hadoop_ha_yarn_site
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    main
fi