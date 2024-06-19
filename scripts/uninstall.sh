#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/utils.sh"
source "${BASE_DIR}/const.sh"

# 步骤编号
step=0


# 检查给定路径的目录是否存在
check_dir_exists() {
  local dir_path="$1"
  if [ ! -d "$dir_path" ]; then
    echo "错误：目录 $dir_path 不存在。"
    exit 1
  fi
}

# 移除指定的目录
remove_dir() {
  local dir_path="$1"
  if [ -d "$dir_path" ]; then
    echo "正在移除 $dir_path ..."
    rm -rf "$dir_path"
    if [ $? -eq 0 ]; then
      echo "$dir_path 已成功移除。"
    else
      echo "错误：移除 $dir_path 失败。"
      exit 1
    fi
  else
    echo "注意：$dir_path 不存在，无需移除。"
  fi
}

# 移除指定的软链接
remove_symlink() {
  local link_path="$1"
  if [ -L "$link_path" ]; then
    log_info "正在移除软链接 $link_path ..."
    rm "$link_path"
    if [ $? -eq 0 ]; then
      log_info "软链接 $link_path 已成功移除。"
    else
      log_error "错误：移除软链接 $link_path 失败。"
      exit 1
    fi
  else
    log_info "注意：软链接 $link_path 不存在，无需移除。"
  fi
}


# 卸载Java的函数
uninstall_java() {
  check_dir_exists "${INSTALL_DIR}"

  # 移除 java 版本目录
  JAVA_VERSION_DIR="${INSTALL_DIR}/${JAVA_VERSION}"
  remove_dir "$JAVA_VERSION_DIR"

  # 移除 java 软链接
  JAVA_SYMLINK="$INSTALL_DIR/jdk"
  remove_symlink "$JAVA_SYMLINK"
}

# 卸载Hadoop的函数
uninstall_hadoop() {
  check_dir_exists "${INSTALL_DIR}"

  # 移除 hadoop-3.1.3 版本目录
  HADOOP_VERSION_DIR="${INSTALL_DIR}/${HADOOP_VERSION}"
  remove_dir "$HADOOP_VERSION_DIR"

  # 移除 hadoop 软链接
  HADOOP_SYMLINK="$INSTALL_DIR/hadoop"
  remove_symlink "$HADOOP_SYMLINK"

}

uninstall_hadoop_remote() {

  # 移除 hadoop版本目录
  HADOOP_VERSION_DIR="${INSTALL_DIR}/${HADOOP_VERSION}"
  log_info "正在移除 $HADOOP_VERSION_DIR ..."
  execute_cluster "rm -rf $HADOOP_VERSION_DIR"

  # 移除 hadoop 软链接
  HADOOP_SYMLINK="$INSTALL_DIR/hadoop"
  log_info "正在移除软链接 $HADOOP_SYMLINK ..."
  execute_cluster "rm -rf $HADOOP_SYMLINK"

}

uninstall_java_remote() {

  # 移除 java 版本目录
  JAVA_VERSION_DIR="${INSTALL_DIR}/${JAVA_VERSION}"
  log_info "正在移除 $JAVA_VERSION_DIR ..."
  execute_cluster "rm -rf $JAVA_VERSION_DIR"

  # 移除 java 软链接
  JAVA_SYMLINK="$INSTALL_DIR/jdk"
  log_info "正在移除软链接 $JAVA_SYMLINK ..."
  execute_cluster "rm -rf $JAVA_SYMLINK"
}

remove_install_dir_remote() {

  # 移除 安装目录
  log_info "正在移除 $INSTALL_DIR ..."
  execute_cluster "rm -rf $INSTALL_DIR"

}

remove_env_file_path_remote() {

  # 移除 安装目录
  log_info "正在移除 $ENV_FILE_PATH ..."
  execute_cluster "rm  $ENV_FILE_PATH"

}


main() {
    log_info "步骤 $step: 开始卸载大数据集群..."
    ((step++))

    ((step++))
    log_info "步骤 $step: 开始卸载Hadoop..."
    uninstall_hadoop_remote

    ((step++))
    log_info "步骤 $step: 开始卸载Java..."
    uninstall_java_remote

    ((step++))
    log_info "步骤 $step: 开始移除安转目录..."
    remove_install_dir_remote

    ((step++))
    log_info "步骤 $step: 开始移除环境变量文件..."
    remove_env_file_path_remote

}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi

