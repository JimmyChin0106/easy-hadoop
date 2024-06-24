#!/usr/bin/env bash
#
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

cd "${PROJECT_DIR}" || exit 1

. "${PROJECT_DIR}/scripts/utils.sh"

action=${1-}
args=("${@:2}")


function usage() {
  echo "$(gettext 'EasyHadoop Deployment Management Script')"
  echo
  echo "Usage: "
  echo "  ./ehctl.sh [COMMAND] [ARGS...]"
  echo "  ./ehctl.sh --help"
  echo
  echo "Installation Commands: "
  echo "  install           $(gettext 'Install EasyHadoop')"
  echo
  echo "Uninstall Commands: "
  echo "  uninstall           $(gettext 'Uninstall EasyHadoop')"
  echo
  echo "Management Commands: "
  echo "  format            $(gettext 'Format  EasyHadoop')"
  echo "  config            $(gettext 'Configuration  EasyHadoop')"
  echo "  start             $(gettext 'Start     EasyHadoop')"
  echo "  stop              $(gettext 'Stop      EasyHadoop')"
  echo "  restart           $(gettext 'Restart   EasyHadoop')"
  echo "  status            $(gettext 'Check     EasyHadoop')"
  echo
}


function format(){

  local service=$1

  case "$service" in
    "hadoop")
      format_hadoop
    ;;
    "hadoop-ha")
      format_ha_hadoop_read_config
    ;;
    *)
      log_info "Invalid service type: $service. Use 'hadoop', 'hadoop-ha'."
      return 1
    ;;
  esac
  
}


function start() {
  if [ $# -eq 0 ]; then
    log_info "No service specified. Starting all services by default."
    stop "all"
  fi

  local service=$1

  case "$service" in
    "zookeeper")
      log_info "Starting zookeeper services..."
      start_zookeeper_read_config
      ;;
    "dfs")
      log_info "Starting Hadoop Distributed File System (DFS)..."
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/start-dfs.sh"
      ;;
    "yarn")
      log_info "Starting YARN services..."
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/start-yarn.sh"
      ;;
    "all")
      log_info "Starting all EasyHadoop services..."
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/start-dfs.sh"
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/start-yarn.sh"
      start_zookeeper_read_config
      ;;
    *)
      log_info "Usage: start_hadoop {zookeeper|dfs|yarn|all}"
      return 1
      ;;
  esac
}

function stop() {

  if [ $# -eq 0 ]; then
    log_info "No service specified. Starting all services by default."
    stop "all"
  fi

  local service=$1

  case "$service" in
    "zookeeper")
      log_info "Starting zookeeper services..."
      stop_zookeeper_read_config
      ;;
    "dfs")
      log_info "Stopping Hadoop Distributed File System (DFS)..."
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/stop-dfs.sh"
      ;;
    "yarn")
      log_info "Stopping YARN services..."
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/stop-yarn.sh"
      ;;
    "all")
      log_info "Stopping all EasyHadoop services..."
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/stop-dfs.sh"
      run_as_easyhadoop_or_root "${HADOOP_HOME}/sbin/stop-yarn.sh"
      stop_zookeeper_read_config
      ;;
    *)
      log_info "Usage: stop_hadoop {zookeeper|dfs|yarn|all}"
      return 1
      ;;
  esac
}


function restart() {

  if [ $# -eq 0 ]; then
    log_info "No service specified. ReStarting all services by default."
    stop "all"
    sleep 5
    start "all"
  fi

  local service=$1

  log_info "Restarting Hadoop services for: $service"

  stop "$service"

  sleep 5

  start "$service"
}


function status() {

  if [ $# -eq 0 ]; then
    log_info  "No service specified.Cheking all services by default."
    status "all"
  fi

  check_dfs_status() {
      log_info "Checking HDFS status..."
      run_as_easyhadoop_or_root "${HADOOP_HOME}/bin/hdfs dfsadmin -report | grep 'Live datanodes'"
      run_as_easyhadoop_or_root "${HADOOP_HOME}/bin/hdfs dfsadmin -report | grep '^Name:'"
      execute_cluster "jps | grep -v Jps | grep Node | grep -v NodeManager"
      
  }

  check_yarn_status() {
      log_info "Checking YARN status..."
      execute_cluster "jps | grep -v Jps | grep Manager"
  }

  check_status() {
    log_info "checking  status..."
    execute_cluster "jps | grep -v Jps"
  }

  local service=$1

  case "$service" in
        "zookeeper")
            status_zookeeper_read_config
            ;;
        "dfs")
            check_dfs_status
            ;;
        "yarn")
            check_yarn_status
            ;;
        "all")
            check_status
            ;;
        *)
            echo "Invalid service type: $service_type. Use 'zookeeper', 'dfs', 'yarn', or 'all'."
            return 1
            ;;
    esac
}


function config() {
    log_info "Moving Configuration Files"
    copy_file ${CONFIG_DIR}/hadoop/core-site.xml ${INSTALL_DIR}/hadoop/etc/hadoop/core-site.xml
    copy_file ${CONFIG_DIR}/hadoop/hdfs-site.xml ${INSTALL_DIR}/hadoop/etc/hadoop/hdfs-site.xml
    copy_file ${CONFIG_DIR}/hadoop/mapred-site.xml ${INSTALL_DIR}/hadoop/etc/hadoop/mapred-site.xml
    copy_file ${CONFIG_DIR}/hadoop/yarn-site.xml ${INSTALL_DIR}/hadoop/etc/hadoop/yarn-site.xml
    copy_file ${CONFIG_DIR}/hadoop/workers ${INSTALL_DIR}/hadoop/etc/hadoop/workers

    sync_files_to_cluster_with_sshkey "${INSTALL_DIR}/hadoop/etc/hadoop/" 

}

function main() {

  if [[ "${OS}" != 'CentOS' ]]; then
    log_error "$(gettext 'Unsupported Operating System Error')"
    exit 0
  fi


  case "${action}" in
  install)
    bash "${SCRIPT_DIR}/install.sh"
    ;;
  uninstall)
   bash "${SCRIPT_DIR}/uninstall.sh"
    ;;
  format)
    format "$args"
    ;;
  start)
    start "$args"
    ;;
  restart)
    restart "$args"
    ;;
  stop)
    stop "$args"
    ;;
  status)
    status "$args"
    ;;
  config)
    config
    ;;
  version)
    get_current_version
    ;;
  help)
    usage
    ;;
  --help)
    usage
    ;;
  -h)
    usage
    ;;
  *)
    echo "No such command: ${action}"
    usage
    ;;
  esac
}

main "$@"
