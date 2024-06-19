#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. "${BASE_DIR}/const.sh"

VERBOSE="false"

# 函数：get_script_dir
#     获取当前脚本所在的目录
# 参数：
#     不需要参数
# 使用示例：
#     get_script_dir
get_script_dir() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$script_dir"
}
# 配置文件路径基于脚本所在目录
_SERVERS_CONFIG_FILE="$(get_script_dir)/../conf/servers.txt"



# 定义日志函数
log() {
    local message="$1"
    local level="$2" # 可以是INFO, ERROR等
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="$timestamp - ${level^^} - $message"

    # 使用tee同时输出到控制台和日志文件
    # 使用-a选项来追加到日志文件而不是覆盖
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null

    # 如果是错误日志，同时输出到stderr
    if [[ "$level" == "ERROR" ]]; then
        echo "$log_entry" >&2
    fi
}

function echo_red() {
  echo -e "\033[1;31m$1\033[0m"
}

function echo_green() {
  echo -e "\033[1;32m$1\033[0m"
}

function echo_yellow() {
  echo -e "\033[1;33m$1\033[0m"
}

function echo_done() {
  sleep 0.5
  echo "$(gettext 'complete')"
}

function echo_check() {
  echo -e "$1 \t [\033[32m √ \033[0m]"
}

function echo_warn() {
  echo -e "[\033[33m WARNING \033[0m] $1"
}

function echo_failed() {
  echo_red "$(gettext 'fail')"
}

function log_success() {
  echo_green "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1"
}

function log_warn() {
  echo_yellow "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1"
}

function log_error() {
  echo_red "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1"
}

function log_info() {
  echo_green "$(date '+%Y-%m-%d %H:%M:%S') [INFO] >>> $1"
}


function get_current_version() {
    echo_green "当前EasyHadoop版本：$PROJECT_VERSION"
    echo_green "    Java：$JAVA_VERSION"
    echo_green "    Hadoop: $HADOOP_VERSION"
}

function echo_logo() {
  cat <<"EOF"
 _______   ________  ________       ___    ___ ___  ___  ________  ________  ________  ________  ________   
|\  ___ \ |\   __  \|\   ____\     |\  \  /  /|\  \|\  \|\   __  \|\   ___ \|\   __  \|\   __  \|\   __  \  
\ \   __/|\ \  \|\  \ \  \___|_    \ \  \/  / | \  \\\  \ \  \|\  \ \  \_|\ \ \  \|\  \ \  \|\  \ \  \|\  \ 
 \ \  \_|/_\ \   __  \ \_____  \    \ \    / / \ \   __  \ \   __  \ \  \ \\ \ \  \\\  \ \  \\\  \ \   ____\
  \ \  \_|\ \ \  \ \  \|____|\  \    \/  /  /   \ \  \ \  \ \  \ \  \ \  \_\\ \ \  \\\  \ \  \\\  \ \  \___|
   \ \_______\ \__\ \__\____\_\  \ __/  / /      \ \__\ \__\ \__\ \__\ \_______\ \_______\ \_______\ \__\   
    \|_______|\|__|\|__|\_________\\___/ /        \|__|\|__|\|__|\|__|\|_______|\|_______|\|_______|\|__|   
                       \|_________\|___|/                                                                 

EOF

  # 假设 EasyHadoop 的版本号存储在 VERSION 变量中
  echo -e "\t\t\t EasyHadoop $PROJECT_VERSION : \033[33m$VERSION\033[0m\n"
}

# 定义函数：提示重启虚拟机
function prompt_reboot() {
    ((step++))
    log_info "步骤 $step: 重启服务器以应用更改..."
    read -p "是否现在重启服务器？(y/n): " answer
    case ${answer:0:1} in
        y|Y )
            log_info "开始重启服务器..."
            reboot
            ;;
        * )
            log_info "服务器重启已取消。"
            ;;
    esac
}

# 函数：execute_function
#     执行传入的函数并传递参数
# 参数：
#     $1 - 函数名
# 使用示例：
#     execution_funtion func_name
function execute_function() {
    local func="$1"; shift # 取出第一个参数作为函数名，然后移动位置参数
    # 将剩余的参数作为函数的参数
    "$func" "$@"
}


# 函数：read_config_and_execution_funtion
#     读取配置文件并传递参数给函数
# 参数：
#     $1 - 函数名
# 使用示例：
#     read_config_and_execution_funtion func_name
function read_config_and_execution_funtion() {
    # 第一个参数是执行的函数名
    local FUNC_NAME="$1"
    shift # 移除第一个参数，剩下的是配置文件的路径

    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}" 

    if [ ! -f "$CONFIG_FILE" ]; then
        log "错误: 配置文件不存在: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 假设配置文件的每行格式为：ip host_name user password
        IFS=',' read -r ip host_name user password <<< "$line"

        # 执行传入的函数，并传递解析出的参数
        execute_function "$FUNC_NAME" "$ip" "$host_name" "$user" "$password"
    done < "$CONFIG_FILE"
}


# 函数：generate_hosts_conf_file
#     读取配置文件并生成HOSTS文件
# 参数：
#     无参数
# 使用示例：
#     generate_hosts_conf_file
function generate_hosts_conf_file() {
    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}"   # 配置文件路径作为参数
    #local hosts_conf_file="$(get_script_dir)/conf/hosts.txt"
    local hosts_conf_file=$(dirname "$CONFIG_FILE")/hosts.txt

    # 检查配置文件是否存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi

    # 创建或清空 Hosts 文件
    log_info "Generating Hosts file..."
    > $hosts_conf_file  # 清空 Hosts 文件

    #读取配置文件并写入 Hosts 文件
     while IFS= read -r line || [[ -n "$line" ]]; do
        # 忽略空行或注释行
        [[ "$line" =~ ^#.*$ ]] && continue || [[ -z "$line" ]] && continue
        IFS=',' read -r ip host_name user password <<< "$line"
        echo "$ip $host_name" >> $hosts_conf_file
    done < "$CONFIG_FILE"
    
    log_info "Hosts file generated successfully."
}

# Function: append_to_hosts
#    Appends the content of ./conf/hosts.txt to the /etc/hosts file
# Parameters:
#    None
# Usage Example:
#    append_to_hosts
function append_conf_to_hosts() {
    local source_file=$(dirname "$_SERVERS_CONFIG_FILE")/hosts.txt
    local hosts_file="${HOSTS_FILE_PATH}"

    # Check if the source file exists
    if [ ! -f "$source_file" ]; then
        log_error "Error: The file $source_file does not exist."
        return 1
    fi

    # Read the content of the source file
    local hosts_content=$(<"$source_file")

    # Use sed command to delete lines from /etc/hosts that exist in hosts.txt
    for line in $hosts_content; do
        # Extract the IP address from each line
        ip_address=$(echo $line | awk -F, '{print $1}')
        # Delete the line from /etc/hosts that contains the IP address
        sudo sed -i "/^$ip_address/d" "$hosts_file"
    done

    # Append the content to /etc/hosts
    echo "$hosts_content" >> "$hosts_file"
    log_info "Append to hosts completed."
}

# 函数：set_hostname
#     修改服务器hostname（如果不同）并立即生效
# 参数：
#     $1 - 新的hostname
# 使用示例：
#     set_hostname "new_hostname_here"
function set_hostname() {
    local new_hostname=$1  # 新的hostname作为函数参数

    # 检查是否提供了新的hostname
    if [ -z "$new_hostname" ]; then
        echo "错误：未提供新的hostname。"
        return 1
    fi

    # 获取当前的hostname
    local current_hostname=$(hostname)

    # 检查当前hostname是否与新的hostname相同
    if [ "$current_hostname" == "$new_hostname" ]; then
        echo "当前hostname已经是 '$new_hostname'，无需修改。"
        return 0
    fi

    # 设置新的hostname
    hostnamectl set-hostname "$new_hostname"

    # 立即生效
    local updated_hostname=$(hostname)

    # 检查hostname是否成功修改
    if [ "$updated_hostname" == "$new_hostname" ]; then
        echo "Hostname已成功修改为：$new_hostname"
    else
        echo "错误：修改Hostname失败。"
        return 2
    fi
}


# 函数：sync_file_to_remote
#     使用ssh和rsync同步文件到远程机器
# 参数：
#     $1 - 本地文件路径/本地文件夹路径
#     $2 - 远程主机IP地址
#     $3 - 远程用户名
#     $4 - 远程主机的密码
# 使用示例：
#     将文件同步到远程机器相同的路径
#     sync_file_to_remote "/path/to/your/file" "remote_host" "remote_user" "remote_pass"
function sync_file_to_remote() {
    local local_file="$1"   # 本地文件路径
    local remote_host="$2"  # 远程主机IP地址
    local remote_user="$3"  # 远程用户名
    local remote_pass="$4"  # 远程主机的密码
    # 检查文件是否存在
    if [ ! -e "$local_file" ]; then
        log_error "Error: Local file '$local_file' does not exist."
        return 1
    fi

    local pdir=$(dirname "$local_file")  # 获取文件所在目录的绝对路径
    local fname=$(basename "$local_file")  # 获取文件名
    local remote_dir="$pdir"   # 远程目录路径

    # 使用sshpass和ssh在远程主机上创建目录
    sshpass -p "$remote_pass" ssh -o StrictHostKeyChecking=no -n "$remote_user@$remote_host" "mkdir -p '$remote_dir'"

    # 检查目录创建是否成功
    if [ $? -ne 0 ]; then
        log_error "Error: Failed to create remote directory '$remote_dir' on '$remote_host'."
        return 1
    fi

    # # 使用rsync同步文件到远程主机
    # 检查verbose变量是否为true
    if [ "$VERBOSE" = true ]; then
        rsync_verbose="-avz"  # 如果verbose为true，添加-v参数
    else
        rsync_verbose="-az"     # 否则不添加-v参数
    fi
    sshpass -p "$remote_pass" rsync "${rsync_verbose}" -e ssh  "$local_file" "$remote_user@$remote_host:$remote_dir"

    # 检查rsync命令是否成功执行
    if [ $? -eq 0 ]; then
        log_info "File '$local_file' successfully synced to '$remote_user@$remote_host:$remote_dir'."
    else
        log_error "Error: Failed to sync file '$local_file' to '$remote_user@$remote_host:$remote_dir'."
        return 1
    fi
}


# 函数：sync_file_to_cluster
#     将单个文件分发到集群的所有机器
# 参数：
#     $# - 单个文件路径
# 使用示例：
#     将文件同步到远程机器相同的路径
#     sync_file_to_cluster "/path/to/your/file"
#     将文件夹同步到远程机器相同的目录
#     sync_file_to_cluster "/path/to/your/directory"
function sync_file_to_cluster(){
    local local_file="$1"   # 本地文件路径
    
    # local script_dir=$(get_script_dir)
    # local CONFIG_FILE="${script_dir}/config.txt" # 配置文件路径基于脚本所在目录
    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}" 

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "错误: 配置文件不存在: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 假设配置文件的每行格式为：ip host_name user password
        IFS=',' read -r ip host_name user password <<< "$line"

        # 执行传入的函数，并传递解析出的参数
        log_info "分发文件$local_file到$ip($host_name)"
        sync_file_to_remote "$local_file" "$ip" "$user" "$password"

    done < "$CONFIG_FILE"

}


# 函数：sync_files_to_cluster
#     将多个文件分发到集群的所有机器
# 参数：
#     $# - 多个文件路径
# 使用示例：
#     sync_files_to_cluster "/path/to/your/file1" "/path/to/your/file2"
function sync_files_to_cluster() {
    # 检查至少提供了一个文件作为参数
    if [ $# -lt 1 ]; then
        log_error "Not Enough Arguments!"
        return 1
    fi

    # 遍历所有提供的文件
    for file in $@; do
        # 判断文件是否存在
        if [ -e $file ]; then
            sync_file_to_cluster $file
        else
            log_info "$file does not exist!"
        fi
    done
}


# 函数：remote_execute
# 参数：
#   $1 - 远程主机IP地址
#   $2 - 远程用户名
#   $3 - 密码
#   $4 - 要执行的命令
# 使用示例：
#   remote_execute 'remote_host' 'remote_user' 'remote_pass' 'command'
function execute_remote() {

    local remote_host="$1" # 远程主机IP地址
    local remote_user="$2" # 远程用户名
    local remote_pass="$3" # 密码
    local command="$4" # 要执行的命令

    if [ -z "$password" ]; then
        log_error "Error: No password provided."
        return 1
    fi

    # 使用sshpass执行远程命令
    sshpass -p "$remote_pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -n "${remote_user}@${remote_host}" "${command}"
}


# 函数：execute_cluster
# 参数：
#   $1 - 要执行的命令
# 使用示例：
#   execute_cluster 'command'
function execute_cluster(){
    local command="$1"   # 执行的命令
    
    # local script_dir=$(get_script_dir)
    # local CONFIG_FILE="${script_dir}/config.txt" # 配置文件路径基于脚本所在目录
    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}" 

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "错误: 配置文件不存在: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 假设配置文件的每行格式为：ip host_name user password
        IFS=',' read -r ip host_name user password <<< "$line"
        log_info "==================$user@$ip($host_name)====================="
        # 执行传入的函数，并传递解析出的参数
        execute_remote "$ip" "$user" "$password" "$command"

    done < "$CONFIG_FILE"

}

# 函数：execute_script_remote
#    远程执行脚本， 脚本作为参数传入
# 参数：
#   $1 - 远程主机IP地址
#   $2 - 远程用户名
#   $3 - 密码
#   $4 - 要执行的脚本
# 使用示例：
#   remote_execute 'remote_host' 'remote_user' 'remote_pass' 'script_content'
function execute_script_remote() {

    local remote_host="$1" # 远程主机IP地址
    local remote_user="$2" # 远程用户名
    local remote_pass="$3" # 密码
    local script_content="$4" # 要执行的脚本

    if [ -z "$password" ]; then
        echo "Error: No password provided."
        return 1
    fi

    # 使用sshpass执行远程命令
    # 使用 eval 执行 SSH 命令和脚本
    #echo eval $script_content
    MY_FILE_PATH="./test.txt"
    sshpass -p "$remote_pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -n "${remote_user}@${remote_host}" eval "$script_content"

}

# 函数：execute_cluster
# 参数：
#   $1 - 要执行的脚本内容
# 使用示例：
#   execute_script_cluster 'script_content'
function execute_script_cluster(){
    local script_content="$1"   # 执行的命令
    
    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}" 

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "错误: 配置文件不存在: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 假设配置文件的每行格式为：ip host_name user password
        IFS=',' read -r ip host_name user password <<< "$line"
        log_info "==================$user@$ip($host_name)====================="
        # 执行传入的函数，并传递解析出的参数
        execute_remote "$ip" "$user" "$password" "$script_content"

    done < "$CONFIG_FILE"

}

function run_as_easyhadoop_or_root() {
    local command_to_run="$1"

    # 获取当前用户
    current_user=$(whoami)

    # 根据当前用户执行不同的操作
    if [ "$current_user" == "root" ]; then
        # 如果当前用户是root，使用bigdata用户执行命令
        su -s /bin/bash -c "$command_to_run" ${EASYHADOOP_USER}
    elif [ "$current_user" == "${EASYHADOOP_USER}" ]; then
        # 如果当前用户是bigdata，直接执行命令
        eval "$command_to_run"
    else
        # 如果是其他用户，打印错误信息并退出
        echo "Error: You do not have permission to run this command."
        exit 1
    fi
}


# 函数：sync_files_to_cluster_with_sshkey
#    将文件分发到指定的集群机器
# 参数：
#    $# - 多个文件路径
# 使用示例：
#    sync_files_to_cluster_with_sshkey file1 file2...
function sync_files_to_cluster_with_sshkey() {

    local hosts_conf_file=$(dirname "$BASE_DIR")/conf/hosts.txt
    local files_array=("$@") 
    echo ${files_array[@]}

    # 检查配置文件是否存在
    if [ ! -f "$hosts_conf_file" ]; then
        log_error "Error: Hosts Configuration file '$hosts_conf_file' does not exist."
        return 1
    fi

    # 读取配置文件中的主机名或IP地址到数组
    local hosts_array=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 假设配置文件的每行格式为：ip host_name user password
        IFS=' ' read -r ip host_name <<< "$line"
        # 执行传入的函数，并传递解析出的参数
        hosts_array+=("$host_name")
    done < "$hosts_conf_file"

    echo "${hosts_array[@]}"

    # 检查files数组是否为空
    if [ ${#files_array[@]} -lt 1 ]; then
        log_error "Error: No files or too few arguments provided."
        return 1
    fi


    # 遍历所有的主机
    for host in "${hosts_array[@]}"; do
        log_info "Syncing to host: $host"
        
        # 遍历所有的文件
        for file in "${files_array[@]}"; do
            if [ -e "$file" ]; then
                log_info "Syncing file: $file to $host"
                # 使用 rsync 同步文件到远程主机的指定目录
                local pdir=$(dirname "$file")  # 获取文件所在目录的绝对路径
                local fname=$(basename "$file")  # 获取文件名
                local remote_dir="$pdir"   # 远程目录路径
                cmd="ssh -o StrictHostKeyChecking=no -n $host 'mkdir -p $remote_dir' "
                run_as_easyhadoop_or_root "$cmd"
                # 检查verbose变量是否为true
                if [ "$VERBOSE" = true ]; then
                    cmd="rsync -avz -e ssh $file $host:$remote_dir" # 如果verbose为true，添加-v参数
                else
                    cmd="rsync -az -e ssh $file $host:$remote_dir"   # 否则不添加-v参数
                fi
                run_as_easyhadoop_or_root "$cmd"
            else
                log_error "Error: File $file does not exist!"
                return 1
            fi
        done
    done
}


# 函数：setup_ssh_key_for_user
#    为指定用户设置SSH免密登录
# 参数：
#    $1 - 要设置用户
# 使用示例：
#    调用函数为bigdata用户设置SSH免密登录
#    setup_ssh_key_for_user "bigdata"
function setup_ssh_key_for_user() {
    local username="$1"
    
    # 检查是否以root用户运行
    if [ "$(id -u)" -ne 0 ]; then
        log_error "错误：该函数必须以root用户权限运行。"
        return 1
    fi

    # 检查用户是否存在
    if ! id "$username" &>/dev/null; then
        log_error "错误：用户 $username 不存在。"
        return 1
    fi

    # 用户的家目录
    local homedir=$(getent passwd "$username" | cut -d: -f6)

    # 切换到目标用户并生成SSH密钥对
    su -s /bin/bash -c " \
        # 检查.ssh目录是否存在，不存在则创建
        if [ ! -d ~/.ssh ]; then
            mkdir ~/.ssh && chmod 700 ~/.ssh
        fi

        # 生成SSH密钥对
        if [ ! -f ~/.ssh/id_rsa ]; then
            ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
        fi

        # 确保authorized_keys文件存在
        touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

        # 将公钥追加到authorized_keys文件
        cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys" "$username"

    # 为SELinux设置正确的上下文（如果使用SELinux）
    if [ -e /usr/sbin/restorecon ]; then
        restorecon -R -v "$homedir/.ssh"
    fi

    log_info "为用户 $username 设置SSH免密登录完成。"
}


# 函数：copy_ssh_key_to_remote_with_password
#    使用密码将本地用户的SSH公钥复制到远程机器上，实现免密登录
# 参数：
#    $1 - 本地用户
#    $2 - 远程服务器IP地址
#    $3 - 远程服务器用户
#    $4 - 远程服务器密码
# 使用示例：
#     请替换以下参数为实际的用户名、远程主机、远程用户名和远程密码
#     copy_ssh_key_to_remote_with_password "local_user" "remote_host" "remote_user" "remote_password"
function copy_ssh_key_to_remote_with_password() {
    local local_user="$1"
    local remote_host="$2"
    local remote_user="$3"
    local remote_pass="$4"

    # 检查参数是否齐全
    if [ -z "$local_user" ] || [ -z "$remote_host" ] || [ -z "$remote_user" ] || [ -z "$remote_pass" ]; then
        log_error "错误：缺少必要的参数。"
        return 1
    fi

    # 检查本地用户是否存在
    if ! id "$local_user" &>/dev/null; then
        log_error "错误：本地用户 $local_user 不存在。"
        return 1
    fi

    # 获取本地用户的公钥路径
    local local_public_key="/home/$local_user/.ssh/id_rsa.pub"

    # 检查公钥文件是否存在
    if [ ! -f "$local_public_key" ]; then
        log_error "错误：本地用户 $local_user 的公钥文件不存在。"
        return 1
    fi

    # 使用sshpass和ssh-copy-id复制公钥到远程机器
    sshpass -p "$remote_pass" ssh-copy-id -i "$local_public_key" "$remote_user@$remote_host"

    # 检查ssh-copy-id命令是否成功执行
    if [ $? -eq 0 ]; then
        log_info "公钥已成功复制到远程主机 $remote_host 上的用户 $remote_user。"
    else
        log_erorr "复制公钥到远程主机失败。"
        return 1
    fi
}

function copy_file() {
    local source_file=$1
    local target_file=$2

    # 检查源文件是否存在
    if [ ! -f "$source_file" ]; then
        log_error "Error: Source file does not exist - $source_file"
        return 1
    fi

    # 检查目标文件是否存在
    if [ -f "$target_file" ]; then
        # 如果目标文件存在，使用diff检查文件是否相同
        if diff -q "$source_file" "$target_file" > /dev/null; then
            log_info "The files are identical, no copy needed."
            return 0
        fi
    fi

    # 执行复制操作
    cp "$source_file" "$target_file"
    if [ $? -eq 0 ]; then
        log_info "File moved successfully."
    else
        log_error "Error: Failed to move file."
        return 1
    fi
}

#############################################################################################################################
#
#  安装Hadoop和Java用到的工具类
#  
#
#
#
#############################################################################################################################

# 定义检查是否以root用户执行的函数
check_root_user() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "该脚本必须以root用户权限运行，请使用sudo命令执行。"
        exit 1
    fi
}

# 定义检查文件是否存在的函数
check_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        log_error "文件不存在：$file"
        exit 1
    fi
}

# 定义解压tar.gz文件的函数
extract_software() {
    local tar_gz_file=$1
    local target_dir=$2
    if ! tar -xzvf "$tar_gz_file" -C "$target_dir"; then
        log_error "解压失败：$tar_gz_file"
        exit 1
    fi
}

# 定义解压并检查的函数
extract_and_check() {
    local tar_gz_file=$1
    local target_dir=$2
    local bin_file=$3  # 用于检查解压是否完整的文件，例如 bin/java

    if [ -d "$target_dir" ]; then
        if [ -f "$target_dir/$bin_file" ]; then
            log_info "已存在，跳过解压步骤。"
        else
            log_warn "目录存在但看起来不完整，需要重新解压。"
            rm -rf "$target_dir"
        fi
    fi

    # 检查verbose变量是否为true
    if [ "$verbose" = true ]; then
        extract_verbose="-xzvf"  # 如果verbose为true，添加-v参数
    else
        extract_verbose="-xzf"     # 否则不添加-v参数
    fi
    if [ ! -d "$target_dir" ]; then
        log_info "解压到目录$target_dir"
        if ! tar ${extract_verbose} "$tar_gz_file" -C "$(dirname "$target_dir")"; then
            log_error "解压失败"
            exit 1
        fi
    fi
}

# 定义创建软链接的函数
create_symlink() {
    local target=$1
    local link_name=$2
    if [ -L "$link_name" ]; then
        if [ "$(readlink -f "$link_name")" != "$target" ]; then
            rm "$link_name"
            ln -s "$target" "$link_name"
        fi
    else
        ln -s "$target" "$link_name"
    fi
}


ensure_file_exists() {
    local file_path="$1"  # 环境变量文件的路径

    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        # 如果文件不存在，尝试创建文件
        if ! touch "$file_path"; then
            log_error "创建文件 $file_path 失败"
            return 1
        fi
        log_info "文件已创建：$file_path"
    else
        log_info "文件已存在：$file_path"
    fi
}

# 定义写入行到文件的函数
write_line_if_not_exists() {
    local file="$1"    # 文件路径
    local line="$2"    # 要写入的行
    local pattern="$3"  # 用于搜索的模式，通常是行的一部分，以避免完全匹配的问题

    # 检查指定的模式是否存在于文件中
    if ! grep -q "$pattern" "$file"; then
        # 如果模式不存在，写入指定的行
        echo "$line" >> "$file"
        log_info "已写入新行到文件：$line"
    else
        log_info "文件中已存在该行$line，跳过写入。"
    fi
}

source_env_vars() {
    local file="$1"  # 环境变量文件的路径

    # 尝试激活环境变量文件
    if ! source "$file"; then
        log_error "环境变量生效失败: $file"
        exit 1
    fi
    log_info "环境变量已生效。"
}

# 定义检查软件安装是否成功的函数
check_installation_success() {
    local software_name=$1
    local check_command=$2  # 用于检查安装是否成功的命令，例如 "java -version" 或 "hadoop version"

    if ! $check_command >/dev/null 2>&1; then
        log_error "$software_name 安装失败，请检查安装过程。"
        exit 1
    else
        log_info "$software_name 安装成功。"
    fi
}