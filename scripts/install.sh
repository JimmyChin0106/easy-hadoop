#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/utils.sh"

# Step counter
step=0

# Internet network check
# Define function: Check network connection
function check_network() {
    if ping -c 3 www.baidu.com &> /dev/null; then
        log_info "Internet connection is normal."
    else
        log_error "Internet connection failed, please check your network settings and try again."
        exit 1
    fi
}

# Internal network check
# Define function: Check the format of a single IP address and try to ping it
function check_and_ping_ip() {
    local ip=$1
    local hostname=$2

    # Check IP address format
    if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_warn "Warning: Skipping invalid IP address format '$ip'."
        exit 1
    fi

    # Ping test, -c 3 sends one ICMP request, -w 5 sets timeout to 5 seconds
    if ping -c 3 -w 5 "$ip" &> /dev/null; then
        log_info "Success: IP address '$ip' ($hostname) is reachable."
    else
        log_error "Failure: IP address '$ip' ($hostname) is not reachable."
        exit 2
    fi
}

# Download necessary tools
# Define function: Install epel-release
function install_epel_release() {
    if ! yum list installed | grep 'epel-release' > /dev/null; then
        log_info "Epel-release is not installed, starting installation..."
        yum install -y epel-release
    else
        log_info "Epel-release is already installed."
    fi
}

# Define function: Install base tools
function install_base_tools() {
    declare -a packages=("net-tools" "vim" "sshpass" "nc")
    for package in "${packages[@]}"; do
        if ! yum list installed | grep "$package" > /dev/null; then
            log_info "$package is not installed, starting installation..."
            yum install -y $package
        else
            log_info "$package is already installed."
        fi
    done
}


# Define function to install Java
function install_java() {
    log_info "Checking if running as root user."
    check_root_user

    log_info "Unzipping JDK to directory ${INSTALL_DIR}"
    log_info "Checking if the target compressed file exists."
    local jdk_tar_gz=$(ls ${SOFTWARE_DIR}/jdk*.tar.gz 2>/dev/null)
    check_file "$jdk_tar_gz"
    log_info "Extracting to the specified directory, checking if it has already been extracted."
    local jdk_target_dir="${INSTALL_DIR}/jdk1.8.0_212"
    local java_bin="bin/java"
    extract_and_check "$jdk_tar_gz" "$jdk_target_dir" "$java_bin"

    log_info "Creating JDK symlink."
    create_symlink "$jdk_target_dir" "${INSTALL_DIR}/jdk"

    log_info "Configuring JAVA environment variables."
    ensure_file_exists "${ENV_FILE_PATH}"
    write_line_if_not_exists "${ENV_FILE_PATH}" "export JAVA_HOME=${INSTALL_DIR}/jdk" "JAVA_HOME"
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$JAVA_HOME/bin' 'export PATH=$PATH:$JAVA_HOME/bin'
    source_env_vars "${ENV_FILE_PATH}"

    log_info "Checking if Java installation was successful."
    check_installation_success "Java" "java -version"
    log_info "Java installation path is $JAVA_HOME"
}

# Define function to install Hadoop
function install_hadoop() {
    log_info "Checking if running as root user."
    check_root_user

    log_info "Unzipping Hadoop to directory ${INSTALL_DIR}"
    log_info "Checking if the target compressed file exists."
    local hadoop_tar_gz=$(ls ${SOFTWARE_DIR}/hadoop*.tar.gz | tail -1)
    check_file "$hadoop_tar_gz"
    log_info "Extracting to the specified directory, checking if it has already been extracted."
    local hadoop_target_dir="${INSTALL_DIR}/${HADOOP_VERSION}"
    local hadoop_bin="bin/hadoop"
    extract_and_check "$hadoop_tar_gz" "${hadoop_target_dir}" "$hadoop_bin"

    log_info "Creating Hadoop symlink."
    create_symlink "$hadoop_target_dir" "${INSTALL_DIR}/hadoop"

    log_info "Configuring Hadoop environment variables."
    ensure_file_exists "${ENV_FILE_PATH}"
    write_line_if_not_exists "${ENV_FILE_PATH}" "export HADOOP_HOME=${INSTALL_DIR}/hadoop" "HADOOP_HOME"
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$HADOOP_HOME/bin' 'export PATH=$PATH:$HADOOP_HOME/bin'
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$HADOOP_HOME/sbin' 'export PATH=$PATH:$HADOOP_HOME/sbin'
    source_env_vars "${ENV_FILE_PATH}"

    log_info "Checking if Hadoop installation was successful."
    check_installation_success "Hadoop" "hadoop version"
    log_info "Hadoop installation path is $HADOOP_HOME"

    log_info "Starting to move Hadoop configuration files."
    HADOOP_ETC_PATH="${INSTALL_DIR}/hadoop/etc/hadoop"
    copy_file ${CONFIG_DIR}/hadoop/core-site.xml ${HADOOP_ETC_PATH}/core-site.xml
    copy_file ${CONFIG_DIR}/hadoop/hdfs-site.xml ${HADOOP_ETC_PATH}/hdfs-site.xml
    copy_file ${CONFIG_DIR}/hadoop/mapred-site.xml ${HADOOP_ETC_PATH}/mapred-site.xml
    copy_file ${CONFIG_DIR}/hadoop/yarn-site.xml ${HADOOP_ETC_PATH}/yarn-site.xml
    copy_file ${CONFIG_DIR}/hadoop/workers ${HADOOP_ETC_PATH}/workers
}

# Define function to install Hadoop HA(High Availablity)
function install_hadoop_ha() {
    log_info "Checking if running as root user."
    #check_root_user

    log_info "Unzipping Hadoop to directory ${INSTALL_DIR}"
    log_info "Checking if the target compressed file exists."
    local hadoop_tar_gz=$(ls ${SOFTWARE_DIR}/hadoop*.tar.gz | tail -1)
    check_file "$hadoop_tar_gz"
    log_info "Extracting to the specified directory, checking if it has already been extracted."
    local hadoop_target_dir="${INSTALL_DIR}/hadoop-ha/${HADOOP_VERSION}"
    local hadoop_bin="bin/hadoop"
    create_dir_if_not_exists "${hadoop_target_dir}"
    extract_and_check "$hadoop_tar_gz" "${hadoop_target_dir}" "$hadoop_bin"

    log_info "Creating Hadoop symlink."
    create_symlink "$hadoop_target_dir" "${INSTALL_DIR}/hadoop"

    log_info "Configuring Hadoop environment variables."
    ensure_file_exists "${ENV_FILE_PATH}"
    write_line_if_not_exists "${ENV_FILE_PATH}" "export HADOOP_HOME=${INSTALL_DIR}/hadoop" "HADOOP_HOME"
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$HADOOP_HOME/bin' 'export PATH=$PATH:$HADOOP_HOME/bin'
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:$HADOOP_HOME/sbin' 'export PATH=$PATH:$HADOOP_HOME/sbin'
    source_env_vars "${ENV_FILE_PATH}"

    log_info "Checking if Hadoop installation was successful."
    check_installation_success "Hadoop" "hadoop version"
    log_info "Hadoop installation path is $HADOOP_HOME"

    log_info "Starting to move Hadoop configuration files."
    HADOOP_ETC_PATH="${INSTALL_DIR}/hadoop/etc/hadoop"
    copy_file ${CONFIG_DIR}/hadoop-ha/core-site.xml ${HADOOP_ETC_PATH}/core-site.xml
    copy_file ${CONFIG_DIR}/hadoop-ha/hdfs-site.xml ${HADOOP_ETC_PATH}/hdfs-site.xml
    #copy_file ${CONFIG_DIR}/hadoop-ha/mapred-site.xml ${HADOOP_ETC_PATH}/mapred-site.xml
    copy_file ${CONFIG_DIR}/hadoop-ha/yarn-site.xml ${HADOOP_ETC_PATH}/yarn-site.xml
    copy_file ${CONFIG_DIR}/hadoop-ha/workers ${HADOOP_ETC_PATH}/workers
}


# Define function to install zookeeper
function install_zookeeper() {
    log_info "Checking if running as root user."
    check_root_user

    log_info "Unzipping Zookeeper to directory ${INSTALL_DIR}"
    log_info "Checking if the target compressed file exists."
    local zk_tar_gz=$(ls ${SOFTWARE_DIR}/apache-zookeeper*.tar.gz 2>/dev/null)
    check_file "$zk_tar_gz"
    log_info "Extracting to the specified directory, checking if it has already been extracted."
    local zk_target_dir="${INSTALL_DIR}/${ZOOKEEPER_VERSION}"
    local zk_bin="bin/zkServer.sh"
    extract_and_check "$zk_tar_gz" "$zk_target_dir" "$zk_bin"

    log_info "Creating Zookeeper symlink."
    create_symlink "$zk_target_dir" "${INSTALL_DIR}/zookeeper"

    log_info "Configuring Zookeeper environment variables."
    ensure_file_exists "${ENV_FILE_PATH}"
    write_line_if_not_exists "${ENV_FILE_PATH}" "export ZOOKEEPER_HOME=${INSTALL_DIR}/zookeeper" "ZOOKEEPER_HOME"
    write_line_if_not_exists "${ENV_FILE_PATH}" 'export PATH=$PATH:ZOOKEEPER_HOME/bin' 'export PATH=$PATH:ZOOKEEPER_HOME/bin'
    source_env_vars "${ENV_FILE_PATH}"

    log_info "Checking if Zookeeper installation was successful."
    log_info "Zookeeper installation path is $ZOOKEEPER_HOME"

    log_info "Starting to move zookeeper configuration files."
    ZOOKEEPER_ETC_PATH="${INSTALL_DIR}/zookeeper/conf"
    copy_file ${CONFIG_DIR}/zookeeper/zoo.cfg ${ZOOKEEPER_ETC_PATH}/zoo.cfg
    write_to_zoo_cfg ${CONFIG_DIR}/zookeeper/zkCluster.txt ${ZOOKEEPER_ETC_PATH}/zoo.cfg
}


# Make sure that the necessary variables are defined before calling these functions, such as:
# SOFTWARE_DIR, INSTALL_DIR, ENV_FILE_PATH, HADOOP_VERSION
main() {

    log_info "Step $step: Starting the installation of the big data cluster..."
    echo_logo
    ((step++))
    log_info "Step $step: Checking internet connection..."
    check_network

    ((step++))
    log_info "Step $step: Checking cluster network connection..."
    read_config_and_execution_function check_and_ping_ip

    ((step++))
    log_info "Step $step: Installing epel-release to get more packages..."
    install_epel_release

    ((step++))
    log_info "Step $step: Installing base tools..."
    install_base_tools

    ((step++))
    log_info "Step $step: Server uniform settings..."
    local source_folder="${PROJECT_DIR}"
    local directory_name=$(basename "${source_folder}")
    local target_directory="${SOFTWARE_DIR}/tmp"
    copy_folder $source_folder $target_directory
    sync_files_to_cluster $target_directory
    execute_cluster "cd ${target_directory}/${directory_name}/scripts && sh ./env_init.sh"
    execute_cluster "rm -rf ${target_directory}"

    ((step++))
    log_info "Step $step: Setting up SSH keyless login for the server..."
    setup_ssh_key_for_user "${EASYHADOOP_USER}"
    sync_files_to_cluster "$SSH_KEY_PATH"

    ((step++))
    log_info "Step $step: Starting to install Java..."
    install_java

    ((step++))
    log_info "Step $step: Starting to install Hadoop..."
    if [ "$HADOOP_HA" = true ]; then
        install_hadoop_ha
    else
        install_hadoop
    fi

    ((step++))
    log_info "Step $step: Starting to install Zookeeper..."
    install_zookeeper

    ((step++))
    log_info "Step $step: Starting to distribute Hadoop..."
    if [ "$HADOOP_HA" = true ]; then
        sync_file_to_cluster "${INSTALL_DIR}" "hadoop-ha/${HADOOP_VERSION}/data,/hadoop-ha/${HADOOP_VERSION}/logs"
    else
        sync_file_to_cluster "${INSTALL_DIR}" "${HADOOP_VERSION}/data,${HADOOP_VERSION}/logs"
    fi


    ((step++))
    log_info "Step $step: Starting to configure environment variables..."
    sync_files_to_cluster "$ENV_FILE_PATH"
    log_info "Activating environment variables..."
    execute_cluster "source $ENV_FILE_PATH"

    execute_cluster "chown -R ${EASYHADOOP_USER}:${EASYHADOOP_USER} ${INSTALL_DIR}"
    read_config_and_write_zookeeper_myid

}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    main
fi