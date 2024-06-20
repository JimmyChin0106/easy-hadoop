#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/utils.sh"

# 步骤编号
step=0

# 外网网络检查
# 定义函数：检查网络连接
check_network() {
    if ping -c 3 www.baidu.com &> /dev/null; then
        log_info "互联网连接正常。"
    else
        log_info "互联网连接失败，请检查网络设置后重试。"
        exit 1
    fi
}

# 内网网络检查
# 函数：检查单个IP地址的格式并尝试Ping通
check_and_ping_ip() {
    local ip=$1
    local hostname=$2

    # 检查IP地址格式
    if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_warn "警告：跳过无效的IP地址格式 '$ip'。"
        exit 1
    fi

    # Ping测试，-c 1表示发送一个ICMP请求，-w 1设置超时为5秒
    if ping -c 3  -w 5 "$ip" &> /dev/null; then
        log_info "成功：IP地址 '$ip' ($hostname) 能Ping通。"
    else
        log_error "失败：IP地址 '$ip' ($hostname) 不能Ping通。"
    fi
}

# 下载必要的工具
# 定义函数：安装epel-release
install_epel_release() {
    if ! yum list installed | grep 'epel-release' > /dev/null; then
        log_info "epel-release 未安装，开始安装..."
        yum install -y epel-release
    else
        log_info "epel-release 已安装。"
    fi
}

# 定义函数：安装基础工具
install_base_tools() {
    declare -a packages=("net-tools" "vim" "sshpass")
    for package in "${packages[@]}"; do
        if ! yum list installed | grep "$package" > /dev/null; then
            log_info "$package 未安装，开始安装..."
            yum install -y $package
        else
            log_info "$package 已安装。"
        fi
    done
}


# 定义安装Java的函数
install_java_new() {
    log_info "检查是否以root用户执行"
    check_root_user

    log_info "解压JDK到目录${INSTALL_DIR}"
    log_info "检查目标压缩文件是否存在"
    local jdk_tar_gz=$(ls ${SOFTWARE_DIR}/jdk*.tar.gz 2>/dev/null)
    check_file "$jdk_tar_gz"
    log_info "解压到指定目录， 解压前检查是否已经解压"
    local jdk_target_dir="${INSTALL_DIR}/jdk1.8.0_212"
    local java_bin="bin/java"
    extract_and_check "$jdk_tar_gz" "$jdk_target_dir" "$java_bin"

    log_info "创建JDK连接"
    create_symlink "$jdk_target_dir" "${INSTALL_DIR}/jdk"

    log_info "配置JAVA环境变量"
    ensure_file_exists "${ENV_FILE_PATH}"
    write_line_if_not_exists "${ENV_FILE_PATH}" "export JAVA_HOME=${INSTALL_DIR}/jdk" "JAVA_HOME"
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$JAVA_HOME/bin' 'export PATH=$PATH:$JAVA_HOME/bin'
    source_env_vars "${ENV_FILE_PATH}"

    log_info "检查Java是否安装成功"
    check_installation_success "Java" "java -version"
    log_info "Java 安装路径为 $JAVA_HOME"
}

# 定义安装Hadoop的函数
install_hadoop_new() {
    log_info "检查是否以root用户执行"
    check_root_user

    log_info "解压Hadoop到目录${INSTALL_DIR}"
    log_info "检查目标压缩文件是否存在"
    local hadoop_tar_gz=$(ls ${SOFTWARE_DIR}/hadoop*.tar.gz | tail -1)
    check_file "$hadoop_tar_gz"
    log_info "解压到指定目录， 解压前检查是否已经解压"
    local hadoop_target_dir="${INSTALL_DIR}/${HADOOP_VERSION}"
    local hadoop_bin="bin/hadoop"
    extract_and_check "$hadoop_tar_gz" "${hadoop_target_dir}" "$hadoop_bin"

    log_info "创建Hadoop连接"
    create_symlink "$hadoop_target_dir" "${INSTALL_DIR}/hadoop"

    log_info "配置Hadoop环境变量"
    ensure_file_exists "${ENV_FILE_PATH}"
    write_line_if_not_exists "${ENV_FILE_PATH}" "export HADOOP_HOME=${INSTALL_DIR}/hadoop" "HADOOP_HOME"
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$HADOOP_HOME/bin' 'export PATH=$PATH:$HADOOP_HOME/bin'
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$HADOOP_HOME/sbin' 'export PATH=$PATH:$HADOOP_HOME/sbin'
    source_env_vars "${ENV_FILE_PATH}"


    log_info "检查Hadoop是否安装成功"
    check_installation_success "Hadoop" "hadoop version"
    log_info "Hadoop 安装路径为 $HADOOP_HOME"

    log_info "开始移动Hadoop的配置文件"
    HADOOP_ETC_PATH="${INSTALL_DIR}/hadoop/etc/hadoop"
    copy_file ${CONFIG_DIR}/hadoop/core-site.xml ${HADOOP_ETC_PATH}/core-site.xml
    copy_file ${CONFIG_DIR}/hadoop/hdfs-site.xml ${HADOOP_ETC_PATH}/hdfs-site.xml
    copy_file ${CONFIG_DIR}/hadoop/mapred-site.xml ${HADOOP_ETC_PATH}/mapred-site.xml
    copy_file ${CONFIG_DIR}/hadoop/yarn-site.xml ${HADOOP_ETC_PATH}/yarn-site.xml
    copy_file ${CONFIG_DIR}/hadoop/workers ${HADOOP_ETC_PATH}/workers
}

# 确保在调用这些函数之前已经定义了必要的变量，如：
# SOFTWARE_DIR, INSTALL_DIR, ENV_FILE_PATH, HADOOP_VERSION


main() {

    log_info "步骤 $step: 开始安装大数据集群..."
    echo_logo
    ((step++))
    log_info "步骤 $step: 检查互联网连接..."
    check_network

    ((step++))
    log_info "步骤 $step: 检查集群网络连接..."
    read_config_and_execution_funtion check_and_ping_ip

    ((step++))
    log_info "步骤 $step: 安装epel-release以获取更多软件包..."
    install_epel_release

    ((step++))
    log_info "步骤 $step: 安装基础工具..."
    install_base_tools

    ((step++))
    log_info "步骤 $step: 服务器统一设置..."
    sync_files_to_cluster "${PROJECT_DIR}"
    execute_cluster "cd ${PROJECT_DIR}/scripts && sh ./env_init.sh"

    ((step++))
    log_info "步骤 $step: 服务器免密登录设置..."
    setup_ssh_key_for_user "${EASYHADOOP_USER}"
    sync_files_to_cluster "$SSH_KEY_PATH"

    ((step++))
    log_info "步骤 $step: 开始安装Java..."
    install_java_new

    ((step++))
    log_info "步骤 $step: 开始安装Hadoop..."
    install_hadoop_new

    ((step++))
    log_info "步骤 $step: 开始分发Hadoop..."
    sync_files_to_cluster "${INSTALL_DIR}"

    ((step++))
    log_info "步骤 $step: 开始配置环境变量..."
    sync_files_to_cluster "$ENV_FILE_PATH"
    log_info "使环境变量生效..."
    execute_cluster "source $ENV_FILE_PATH"

}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi

