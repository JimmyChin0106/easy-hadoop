#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. "${BASE_DIR}/const.sh"

VERBOSE=false

# Configuration file path is based on the directory where the script is located
_SERVERS_CONFIG_FILE="${PROJECT_DIR}/conf/servers.txt"

# Function: get_script_dir
#     Gets the directory where the current script is located
# Parameters:
#     No parameters needed
# Usage example:
#     get_script_dir
get_script_dir() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$script_dir"
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

# Define a logging function
log() {
    local message="$1"
    local level="$2" # Could be INFO, ERROR, etc.
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="$timestamp - ${level^^} - $message"

    # Use tee to output to both the console and the log file
    # Use the -a option to append to the log file instead of overwriting
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null

    # If it's an error log, also output to stderr
    if [[ "$level" == "ERROR" ]]; then
        echo "$log_entry" >&2
    fi
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
#function log_info() {
#  log $1 "[INFO]"
#}


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

# Define a function to prompt for a reboot of the virtual machine
function prompt_reboot() {
    ((step++))
    log_info "Step $step: Rebooting the server to apply changes..."
    read -p "Do you want to reboot the server now? (y/n): " answer
    case ${answer:0:1} in
        y|Y )
            log_info "Starting to reboot the server..."
            reboot
            ;;
        * )
            log_info "Server reboot has been canceled."
            ;;
    esac
}

# Function: execute_function
#     Execute the passed function with arguments
# Parameters:
#     $1 - Function name
# Usage Example:
#     execute_function func_name "$@"
function execute_function() {
    local func="$1"; shift # The first argument is the function name, then shift the positional parameters
    # Pass the remaining arguments as parameters to the function
    "$func" "$@"
}

# Function: read_config_and_execution_function
#     Read the configuration file and pass the parameters to the function
# Parameters:
#     $1 - Function name
# Usage Example:
#     read_config_and_execution_function func_name
function read_config_and_execution_function() {
    # The first argument is the name of the function to execute
    local FUNC_NAME="$1"
    shift # Remove the first argument, the rest are the paths to the configuration file

    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}"

    if [ ! -f "$CONFIG_FILE" ]; then
        log "Error: Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Assume the configuration file has a format of: ip host_name user password
        IFS=',' read -r ip host_name user password <<< "$line"

        # Execute the passed function and pass the parsed parameters
        execute_function "$FUNC_NAME" "$ip" "$host_name" "$user" "$password"
    done < "$CONFIG_FILE"
}

# Function: generate_hosts_conf_file
#     Read the configuration file and generate a HOSTS file
# Parameters:
#     None
# Usage Example:
#     generate_hosts_conf_file
function generate_hosts_conf_file() {
    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}"   # Configuration file path as an argument
    local hosts_conf_file=$(dirname "$CONFIG_FILE")/hosts.txt

    # Check if the configuration file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi

    # Create or clear the Hosts file
    log_info "Generating Hosts file..."
    > $hosts_conf_file  # Clear the Hosts file

    # Read the configuration file and write to the Hosts file
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ignore empty lines or comment lines
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


# Function: set_hostname
#     Change the server's hostname if it's different and take effect immediately
# Parameters:
#     $1 - The new hostname
# Usage Example:
#     set_hostname "new_hostname_here"
function set_hostname() {
    local new_hostname=$1  # The new hostname as a function argument

    # Check if a new hostname was provided
    if [ -z "$new_hostname" ]; then
        echo "Error: No new hostname provided."
        return 1
    fi

    # Get the current hostname
    local current_hostname=$(hostname)

    # Check if the current hostname is the same as the new one
    if [ "$current_hostname" == "$new_hostname" ]; then
        echo "The current hostname is already '$new_hostname', no change needed."
        return 0
    fi

    # Set the new hostname
    hostnamectl set-hostname "$new_hostname"

    # Take effect immediately
    local updated_hostname=$(hostname)

    # Check if the hostname was successfully changed
    if [ "$updated_hostname" == "$new_hostname" ]; then
        echo "Hostname has been successfully changed to: $new_hostname"
    else
        echo "Error: Failed to change the hostname."
        return 2
    fi
}

# Function: sync_file_to_remote
#     Synchronize a file to a remote machine using ssh and rsync
# Parameters:
#     $1 - Local file path or local folder path
#     $2 - Remote host IP address
#     $3 - Remote username
#     $4 - Remote host password
# Usage Example:
#     Synchronize a file to the same path on a remote machine
#     sync_file_to_remote "/path/to/your/file" "remote_host" "remote_user" "remote_pass"
function sync_file_to_remote() {
    local local_file="$1"   # Local file path
    local remote_host="$2"  # Remote host IP address
    local remote_user="$3"  # Remote username
    local remote_pass="$4"  # Remote host password

    # Check if the file exists
    if [ ! -e "$local_file" ]; then
        log_error "Error: Local file '$local_file' does not exist."
        return 1
    fi

    local pdir=$(dirname "$local_file")  # Get the absolute path of the directory where the file is located
    local fname=$(basename "$local_file")  # Get the filename
    local remote_dir="$pdir"   # Remote directory path

    # Use sshpass and ssh to create a directory on the remote host
    sshpass -p "$remote_pass" ssh -o StrictHostKeyChecking=no -n "$remote_user@$remote_host" "mkdir -p '$remote_dir'"

    # Check if the directory was created successfully
    if [ $? -ne 0 ]; then
        log_error "Error: Failed to create remote directory '$remote_dir' on '$remote_host'."
        return 1
    fi

    # Use rsync to synchronize the file to the remote host
    # Check if the VERBOSE variable is true
    if [ "$VERBOSE" = true ]; then
        rsync_verbose="-avz"  # If VERBOSE is true, add the -v option
    else
        rsync_verbose="-az"     # Otherwise, do not add the -v option
    fi
    sshpass -p "$remote_pass" rsync "${rsync_verbose}" --stats -e ssh "$local_file" "$remote_user@$remote_host:$remote_dir"

    # Check if the rsync command was executed successfully
    if [ $? -eq 0 ]; then
        log_info "File '$local_file' successfully synced to '$remote_user@$remote_host:$remote_dir'."
    else
        log_error "Error: Failed to sync file '$local_file' to '$remote_user@$remote_host:$remote_dir'."
        return 1
    fi
}

# Function: sync_file_to_cluster
#     Distributes a single file to all machines in the cluster
# Parameters:
#     $1 - Path to a single file
# Usage Example:
#     Synchronize a file to the same path on a remote machine
#     sync_file_to_cluster "/path/to/your/file"
#     Synchronize a directory to the same directory on a remote machine
#     sync_file_to_cluster "/path/to/your/directory"
function sync_file_to_cluster(){
    local local_file="$1"   # Local file path
    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Error: Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Assume the configuration file has a format of: ip host_name user password
        IFS=',' read -r ip host_name user password <<< "$line"

        # Execute the passed function and pass the parsed parameters
        log_info "Distributing file $local_file to $ip ($host_name)"
        sync_file_to_remote "$local_file" "$ip" "$user" "$password"

    done < "$CONFIG_FILE"
}

# Function: sync_files_to_cluster
#     Distributes multiple files to all machines in the cluster
# Parameters:
#     $@ - Paths to multiple files
# Usage Example:
#     sync_files_to_cluster "/path/to/your/file1" "/path/to/your/file2"
function sync_files_to_cluster() {
    # Check if at least one file was provided as an argument
    if [ $# -lt 1 ]; then
        log_error "Not Enough Arguments!"
        return 1
    fi

    # Iterate over all provided files
    for file in "$@"; do
        # Check if the file exists
        if [ -e "$file" ]; then
            sync_file_to_cluster "$file"
        else
            log_info "$file does not exist!"
        fi
    done
}

# Function: remote_execute
# Parameters:
#    $1 - Remote host IP address
#    $2 - Remote username
#    $3 - Password
#    $4 - Command to execute
# Usage Example:
#    remote_execute 'remote_host' 'remote_user' 'remote_pass' 'command'
function execute_remote() {
    local remote_host="$1" # Remote host IP address
    local remote_user="$2" # Remote username
    local remote_pass="$3" # Password
    local command="$4" # Command to execute

    if [ -z "$remote_pass" ]; then
        log_error "Error: No password provided."
        return 1
    fi

    # Use sshpass to execute the remote command
    sshpass -p "$remote_pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -n "${remote_user}@${remote_host}" "${command}"
}


# Function: execute_cluster
# Executes a command on a cluster of servers based on include or exclude mode.
# Parameters:
#   $1 - The command to execute
#   $2 - "include" or "exclude" mode
#   $3 - A list of servers, format: ip1,ip2,ip3
function execute_cluster(){
    local command="$1"   # The command to execute
    local servers_mode="$2" # "include" or "exclude" mode
    local servers_list="$3" # Server list, format: ip1,ip2,ip3

    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Error: Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        IFS=',' read -r ip host_name user password <<< "$line"
        local should_execute=1 # Default to execute

        # Decide whether to execute the command based on the mode
        if [ "$servers_mode" == "include" ]; then
            # If it's include mode, execute only if the IP is in the list
            if ! echo "$servers_list" | grep -Eq "(^|,)$ip(,|$)"; then
                should_execute=0
            fi
        elif [ "$servers_mode" == "exclude" ]; then
            # If it's exclude mode, do not execute if the IP is in the list
            if echo "$servers_list" | grep -Eq "(^|,)$ip(,|$)"; then
                should_execute=0
            fi
        fi

        if [ "$should_execute" -eq 1 ]; then
            log_info "Executing command '${command}' on ${user}@${ip} (${host_name})"
            # Execute the passed function with parsed parameters
            execute_remote "$ip" "$user" "$password" "$command"
        fi
    done < "$CONFIG_FILE"
}

# Function: execute_script_remote
#     Remotely execute a script with the script content passed as an argument.
# Parameters:
#   $1 - Remote host IP address
#   $2 - Remote user name
#   $3 - Password
#   $4 - Script content to execute
# Usage Example:
#   execute_script_remote 'remote_host' 'remote_user' 'remote_pass' 'script_content'
function execute_script_remote() {
    local remote_host="$1" # Remote host IP address
    local remote_user="$2" # Remote user name
    local remote_pass="$3" # Password
    local script_content="$4" # Script content to execute

    if [ -z "$remote_pass" ]; then
        echo "Error: No password provided."
        return 1
    fi

    # Use sshpass to execute the remote command
    # Use eval to execute the SSH command and script
    #echo eval $script_content
    local MY_FILE_PATH="./test.txt"
    sshpass -p "$remote_pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -n "${remote_user}@${remote_host}" eval "$script_content"
}

# Function: execute_script_cluster
# Executes a script on all machines in the cluster as per the provided configuration.
# Parameters:
#   $1 - The script content to execute
# Usage Example:
#   execute_script_cluster 'script_content'
function execute_script_cluster(){
    local script_content="$1"   # The script content to execute

    local CONFIG_FILE="${_SERVERS_CONFIG_FILE}"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Error: Configuration file does not exist: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Assume the configuration file has a format of: ip host_name user password
        IFS=',' read -r ip host_name user password <<< "$line"
        log_info "Executing script '${script_content}' on ${user}@${ip} (${host_name})"
        # Execute the passed function with parsed parameters
        execute_remote "$ip" "$user" "$password" "$script_content"

    done < "$CONFIG_FILE"
}

function run_as_easyhadoop_or_root() {
    local command_to_run="$1"

    # Get the current user
    local current_user=$(whoami)

    # Execute different actions based on the current user
    if [ "$current_user" == "root" ]; then
        # If the current user is root, execute the command as the bigdata user
        su -s /bin/bash -c "$command_to_run" "${EASYHADOOP_USER}"
    elif [ "$current_user" == "${EASYHADOOP_USER}" ]; then
        # If the current user is bigdata, execute the command directly
        eval "$command_to_run"
    else
        # If it is another user, print an error message and exit
        echo "Error: You do not have permission to run this command."
        exit 1
    fi
}


# Function: sync_files_to_cluster_with_sshkey
#     Distributes files to specified cluster machines.
# Parameters:
#    $# - Multiple file paths
# Usage Example:
#    sync_files_to_cluster_with_sshkey file1 file2...
function sync_files_to_cluster_with_sshkey() {

    local hosts_conf_file=$(dirname "$BASE_DIR")/conf/hosts.txt
    local files_array=("$@")

    # Check if the configuration file exists
    if [ ! -f "$hosts_conf_file" ]; then
        log_error "Error: Hosts Configuration file '$hosts_conf_file' does not exist."
        return 1
    fi

    # Read the hostnames or IP addresses from the configuration file into an array
    local hosts_array=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Assume the configuration file has a format of: ip host_name user password
        IFS=' ' read -r ip host_name <<< "$line"
        # Add the hostname to the hosts array
        hosts_array+=("$host_name")
    done < "$hosts_conf_file"

    # Check if the files array is not empty
    if [ ${#files_array[@]} -lt 1 ]; then
        log_error "Error: No files or too few arguments provided."
        return 1
    fi

    # Iterate over all hosts
    for host in "${hosts_array[@]}"; do
        log_info "Syncing to host: $host"

        # Iterate over all files
        for file in "${files_array[@]}"; do
            if [ -e "$file" ]; then
                log_info "Syncing file: $file to $host"
                # Use rsync to synchronize the file to the remote host's specified directory
                local pdir=$(dirname "$file")  # Get the absolute path of the directory where the file is located
                local fname=$(basename "$file")  // Get the filename
                local remote_dir="$pdir"   // Remote directory path
                local cmd="ssh -o StrictHostKeyChecking=no -n $host 'mkdir -p $remote_dir' "
                run_as_easyhadoop_or_root "$cmd"
                # Check if the VERBOSE variable is true
                if [ "$VERBOSE" = true ]; then
                    cmd="rsync -avz -e ssh $file $host:$remote_dir" # If VERBOSE is true, add the -v option
                else
                    cmd="rsync -az -e ssh $file $host:$remote_dir"   # Otherwise, do not add the -v option
                fi
                run_as_easyhadoop_or_root "$cmd"
            else
                log_error "Error: File $file does not exist!"
                return 1
            fi
        done
    done
}

# Function: setup_ssh_key_for_user
#    Sets up SSH key-based authentication for a specified user.
# Parameters:
#    $1 - The user to set up the SSH key for.
# Usage Example:
#    Call the function to set up SSH key-based authentication for the 'bigdata' user.
#    setup_ssh_key_for_user "bigdata"
function setup_ssh_key_for_user() {
    local username="$1"

    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Error: This function must be run with root privileges."
        return 1
    fi

    # Check if the user exists
    if ! id "$username" &>/dev/null; then
        log_error "Error: User '$username' does not exist."
        return 1
    fi

    # User's home directory
    local homedir=$(getent passwd "$username" | cut -d: -f6)

    # Switch to the target user and generate the SSH key pair
    su -s /bin/bash -c " \
        # Check if the .ssh directory exists, create if it doesn't
        if [ ! -d ~/.ssh ]; then
            mkdir ~/.ssh && chmod 700 ~/.ssh
        fi

        # Generate the SSH key pair
        if [ ! -f ~/.ssh/id_rsa ]; then
            ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
        fi

        # Ensure the authorized_keys file exists
        if [ ! -f ~/.ssh/authorized_keys ]; then
            touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
        fi

        # Check if the public key is already in the authorized_keys file
        if ! grep -qF \"\$(cat ~/.ssh/id_rsa.pub)\" ~/.ssh/authorized_keys; then
            # If the public key does not exist, append it to the authorized_keys file
            cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
            echo 'The public key has been added to the authorized_keys file.'
        else
            echo 'The public key already exists and will not be added again.'
        fi
    " "$username"

    # Set the correct context for SELinux (if using SELinux)
    if [ -e /usr/sbin/restorecon ]; then
        restorecon -R -v "$homedir/.ssh"
    fi

    log_info "SSH key-based authentication has been set up for user '$username'."
}

# Function: copy_ssh_key_to_remote_with_password
#    Copies the local user's SSH public key to a remote machine using a password for key-based authentication.
# Parameters:
#    $1 - Local user
#    $2 - Remote server IP address
#    $3 - Remote server user
#    $4 - Remote server password
# Usage Example:
#    Replace the following parameters with the actual username, remote host, remote username, and remote password.
#    copy_ssh_key_to_remote_with_password "local_user" "remote_host" "remote_user" "remote_password"
function copy_ssh_key_to_remote_with_password() {
    local local_user="$1"
    local remote_host="$2"
    local remote_user="$3"
    local remote_pass="$4"

    # Check if all parameters are provided
    if [ -z "$local_user" ] || [ -z "$remote_host" ] || [ -z "$remote_user" ] || [ -z "$remote_pass" ]; then
        log_error "Error: Missing required parameters."
        return 1
    fi

    # Check if the local user exists
    if ! id "$local_user" &>/dev/null; then
        log_error "Error: Local user '$local_user' does not exist."
        return 1
    fi

    # Get the path to the local user's public key
    local local_public_key="/home/$local_user/.ssh/id_rsa.pub"

    # Check if the public key file exists
    if [ ! -f "$local_public_key" ]; then
        log_error "Error: The public key file for local user '$local_user' does not exist."
        return 1
    fi

    # Use sshpass and ssh-copy-id to copy the public key to the remote machine
    sshpass -p "$remote_pass" ssh-copy-id -i "$local_public_key" "$remote_user@$remote_host"

    # Check if the ssh-copy-id command was executed successfully
    if [ $? -eq 0 ]; then
        log_info "The public key has been successfully copied to the remote host '$remote_host' for user '$remote_user'."
    else
        log_error "Failed to copy the public key to the remote host."
        return 1
    fi
}

# Function: copy_file
# Copies a file from the source to the target location.
# Parameters:
#   $1 - The path to the source file.
#   $2 - The path to the target file where the source will be copied.
# Usage Example:
#    copy_file "/path/to/source_file" "/path/to/target_file"
function copy_file() {
    local source_file=$1
    local target_file=$2

    # Check if the source file exists
    if [ ! -f "$source_file" ]; then
        log_error "Error: Source file does not exist - $source_file"
        return 1
    fi

    # Check if the target file exists
    if [ -f "$target_file" ]; then
        # If the target file exists, use diff to check if the files are identical
        if diff -q "$source_file" "$target_file" > /dev/null; then
            log_info "The files are identical, no copy needed."
            return 0
        fi
    fi

    # Perform the copy operation
    cp "$source_file" "$target_file"
    if [ $? -eq 0 ]; then
        log_info "File copied successfully."
    else
        log_error "Error: Failed to copy the file."
        return 1
    fi
}


# Define a function with parameters for the source folder path and the target directory path
# Usage Example:
# copy_folder "/path/to/source_folder" "/path/to/target_dir"
copy_folder() {
    local source_folder=$1
    local target_dir=$2

    # Check if the source folder exists
    if [ ! -d "$source_folder" ]; then
        log_error "Error: The source folder does not exist."
        return 1
    fi

    # Check if the target directory exists, create it if it does not
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi

    # Copy the folder to the target directory
    cp -a "$source_folder" "$target_dir"

    if [ $? -eq 0 ]; then
        log_info "Folder copied successfully."
    else
        log_info "Failed to copy the folder."
        return 1
    fi
}


#############################################################################################################################
#
# Tool function used for installing Hadoop and Java
#
#############################################################################################################################

# Define a function to check if the script is run as the root user
check_root_user() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run with root privileges, please use the sudo command to execute."
        exit 1
    fi
}

# Define a function to check if a file exists
check_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        log_error "File does not exist: $file"
        exit 1
    fi
}

# Define a function to extract .tar.gz files
extract_software() {
    local tar_gz_file=$1
    local target_dir=$2
    if ! tar -xzvf "$tar_gz_file" -C "$target_dir"; then
        log_error "Failed to extract: $tar_gz_file"
        exit 1
    fi
}

# Function to create a directory if it does not exist, skip if it already exists
create_dir_if_not_exists() {
    local dir_path="$1"  # The directory path passed as an argument

    # Check if the directory does not exist
    if [ ! -d "$dir_path" ]; then
        # The directory does not exist, so create it
        mkdir -p "$dir_path"
        if [ $? -eq 0 ]; then
            log_info "Directory created: $dir_path"
        else
            log_error "Error: Failed to create directory $dir_path"
            return 1
        fi
    else
        # The directory already exists, so skip the creation
        log_info "Directory already exists: $dir_path"
    fi
}

# Define a function to extract and verify the software
extract_and_check() {
    local tar_gz_file=$1
    local target_dir=$2
    local bin_file=$3  # The file used to check if the extraction is complete, e.g., bin/java

    if [ -d "$target_dir" ]; then
        if [ -f "$target_dir/$bin_file" ]; then
            log_info "Already exists, skipping extraction step."
        else
            log_warn "The directory exists but seems incomplete, need to re-extract."
            rm -rf "$target_dir"
        fi
    fi

    # Check if the verbose variable is true
    if [ "$verbose" = true ]; then
        extract_verbose="-xzvf"  # If verbose is true, add the -v option
    else
        extract_verbose="-xzf"     # Otherwise, do not add the -v option
    fi
    if [ ! -d "$target_dir" ]; then
        log_info "Extracting to directory $target_dir"
        if ! tar ${extract_verbose} "$tar_gz_file" -C "$(dirname "$target_dir")"; then
            log_error "Extraction failed"
            exit 1
        fi
    fi
}

# Define a function to create a symbolic link
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

# Ensure the file exists
ensure_file_exists() {
    local file_path="$1"  # Path of the environment variable file

    # Check if the file exists
    if [ ! -f "$file_path" ]; then
        # If the file does not exist, try to create the file
        if ! touch "$file_path"; then
            log_error "Failed to create file: $file_path"
            return 1
        fi
        log_info "File created: $file_path"
    else
        log_info "File already exists: $file_path"
    fi
}

# Define a function to write a line to a file if it does not exist
write_line_if_not_exists() {
    local file="$1"    # File path
    local line="$2"    # Line to be written
    local pattern="$3"  # Pattern used for searching, usually part of the line to avoid full match issues

    # Check if the specified pattern exists in the file
    if ! grep -q "$pattern" "$file"; then
        # If the pattern does not exist, write the specified line
        echo "$line" >> "$file"
        log_info "New line written to file: $line"
    else
        log_info "The line $line already exists in the file, skipping write."
    fi
}

# Source environment variables
source_env_vars() {
    local file="$1"  # Path of the environment variable file

    # Try to activate the environment variable file
    if ! source "$file"; then
        log_error "Failed to source environment variables: $file"
        exit 1
    fi
    log_info "Environment variables are now sourced."
}

# Define a function to check if software installation was successful
check_installation_success() {
    local software_name=$1
    local check_command=$2  # Command used to check if the installation was successful, e.g., "java -version" or "hadoop version"

    if ! $check_command >/dev/null 2>&1; then
        log_error "Installation of $software_name failed, please check the installation process."
        exit 1
    else
        log_info "Installation of $software_name was successful."
    fi
}

function format_hadoop(){

   # 检查参数个数
   if [ "$#" -ne 1 ]; then
      echo "Usage: $0 namenode"
      exit 1
   fi
   namenode=$1
   log_info "Formatting NameNode on $namenode"
   cmd="ssh -o StrictHostKeyChecking=no -n $namenode '${HADOOP_HOME}/bin/hdfs namenode -format'"
   run_as_easyhadoop_or_root "$cmd"
}

#  format_ha_hadoop "node1,node2,node3" "node1" "node2,node3"
function format_hadoop_ha() {
    # 检查参数个数
    if [ "$#" -ne 3 ]; then
      echo "Usage: $0 journalnodes_namespace namenode standbynodes_namespace"
      exit 1
    fi

    # 读取参数
    journalnodes=$1
    namenode=$2
    standbynodes=$3

    # 启动JournalNodes
    IFS=',' read -r -a journalnodes_array <<< "$journalnodes"
    for node in "${journalnodes_array[@]}"
    do
        log_info "Starting JournalNode on $node"
        cmd="ssh -o StrictHostKeyChecking=no -n $node 'hdfs --daemon start journalnode'"
        run_as_easyhadoop_or_root "$cmd"
    done

    # 格式化NameNode
    log_info "Formatting and starting NameNode on $namenode"
    cmd="ssh -o StrictHostKeyChecking=no -n $namenode 'yes Y | hdfs zkfc -formatZK'"
    run_as_easyhadoop_or_root "$cmd"
    cmd="ssh -o StrictHostKeyChecking=no -n $namenode 'yes Y | hdfs namenode -format'"
    run_as_easyhadoop_or_root "$cmd"
    cmd="ssh -o StrictHostKeyChecking=no -n $namenode 'hdfs --daemon start namenode'"
    run_as_easyhadoop_or_root "$cmd"

    # 同步Standby NameNodes
    IFS=',' read -r -a standbynodes_array <<< "$standbynodes"
    for node in "${standbynodes_array[@]}"
    do
        log_info "Bootstrapping Standby NameNode on $node"
        cmd="ssh -o StrictHostKeyChecking=no -n $node 'hdfs namenode -bootstrapStandby'"
        run_as_easyhadoop_or_root "$cmd"
    done

}

#############################################################################################################################
#
# Tool fucntion used for zookeeper
#
#############################################################################################################################


# Function: Write the 'myid' to the remote server's zkdata directory via SSH
function write_zookeeper_myid() {
  local server_id=$1
  local server_host=$2
  local zkdata_dir="${ZOOKEEPER_DATA_DIR}" # Assuming the ZOOKEEPER_DATA_DIR environment variable is already set

  # Construct SSH command to create zkdata directory (if it does not exist)
  create_dir_cmd="ssh -o StrictHostKeyChecking=no -n $server_host 'mkdir -p ${zkdata_dir}'"

  # Construct SSH command to write the 'myid'
  write_file_cmd="ssh -o StrictHostKeyChecking=no -n $server_host 'echo $server_id > ${zkdata_dir}/myid'"

  # Execute SSH command to create directory
  run_as_easyhadoop_or_root "$create_dir_cmd"

  # Check if the previous command was successful
  if [ $? -ne 0 ]; then
    echo "Failed to create directory $zkdata_dir on $server_host"
    return 1
  fi

  # Execute SSH command to write the 'myid'
  run_as_easyhadoop_or_root "$write_file_cmd"

  # Check if the write command was successful
  if [ $? -eq 0 ]; then
    log_info "Wrote $server_id to $server_host:$zkdata_dir/myid"
  else
    log_info "Failed to write myid to $server_host"
    return 2
  fi
}

# Function: Read the configuration file and call the write_myid function
function read_config_and_write_zookeeper_myid() {

  local config_file="${PROJECT_DIR}/conf/zookeeper/zkCluster.txt"

  while IFS='=' read -r key value; do
    if [[ -z "$key" || $key == \#* ]]; then
      continue
    fi
    server_id=$(echo "$key" | sed 's/server.\([0-9]*\)/\1/')
    server_host=$(echo "$value" | awk -F ':' '{print $1}')

    write_zookeeper_myid "$server_id" "$server_host"
  done < "$config_file"
}

# Function: Write the content of the zkCluster file to zoo.cfg, skip if the content already exists
# Usage example:
# Replace the function parameters with the actual file paths
# write_to_zoo_cfg "path_to_zkCluster.txt" "path_to_zoo.cfg"
function write_to_zoo_cfg() {
  local zk_cluster_file="$1"
  local zoo_cfg_file="$2"

  # Check if the zkCluster file exists
  if [[ ! -f "$zk_cluster_file" ]]; then
    log_error "Error: zkCluster file does not exist: $zk_cluster_file"
    return 1
  fi

  # Check if the zoo.cfg file exists
  if [[ ! -f "$zoo_cfg_file" ]]; then
    log_error "Error: zoo.cfg file does not exist: $zoo_cfg_file"
    return 1
  fi

  # Read each line of the zkCluster file
  while IFS= read -r line; do
    # Skip empty lines and comment lines
    if [[ -z "$line" || $line == \#* ]]; then
      continue
    fi

    # Check if the line already exists in the zoo.cfg file
    if ! grep -qF -- "$line" "$zoo_cfg_file"; then
      # If not, append to the zoo.cfg file
      echo "$line" >> "$zoo_cfg_file"
      log_info "Added to $zoo_cfg_file: $line"
    else
      # If it exists, skip
      log_info "Skipped (already exists in $zoo_cfg_file): $line"
    fi
  done < "$zk_cluster_file"
}



# Function to start Zookeeper on multiple specified hosts
# Example usage:
# start_zookeeper hadoop102 hadoop103 hadoop104
function start_zookeeper() {
  # 使用"$@"来接收所有传入的参数
  for hostname in "$@"; do
    log_info "Starting Zookeeper on $hostname "
    cmd="ssh -o StrictHostKeyChecking=no -n $hostname '${INSTALL_DIR}/zookeeper/bin/zkServer.sh start'"
    run_as_easyhadoop_or_root "$cmd"
  done
}

# Function to stop Zookeeper on multiple specified hosts
# Example usage:
# stop_zookeeper hadoop102 hadoop103 hadoop104
function stop_zookeeper() {
  for hostname in "$@"; do
    log_info "Stopping Zookeeper on $hostname"
    cmd="ssh -o StrictHostKeyChecking=no -n $hostname '${INSTALL_DIR}/zookeeper/bin/zkServer.sh stop'"
    run_as_easyhadoop_or_root "$cmd"
  done
}

# Function to check the status of Zookeeper on multiple specified hosts
# Example usage:
# status_zookeeper hadoop102 hadoop103 hadoop104
function status_zookeeper() {
  for hostname in "$@"; do
    log_info " Checking Zookeeper status on $hostname "
    cmd="ssh -o StrictHostKeyChecking=no -n $hostname '${INSTALL_DIR}/zookeeper/bin/zkServer.sh status'"
    run_as_easyhadoop_or_root "$cmd"
  done
}


# Define a function to read hostnames from a Zookeeper cluster configuration file
function read_hosts_from_zk_cluster_file() {
  local file_path="${PROJECT_DIR}/conf/zookeeper/zkCluster.txt"  # Path to the Zookeeper cluster configuration file
  local hosts_map # Associative array to store the mapping of server_id to hostname

  # Check if the file exists
  if [[ ! -f "$file_path" ]]; then
    log_error "Error: File does not exist - $file_path"  # Log an error message if the file is not found
    return 1
  fi

  # Read the file and populate the associative array
  while IFS='=' read -r key value; do
    if [[ ! -z "$key" && ! $key == \#* ]]; then
      # Extract the hostname
      local server_id=$(echo "$key" | sed 's/server.\([0-9]*\)/\1/')  # Extract the numeric part after 'server.'
      local hostname=$(echo "$value" | awk -F ':' '{print $1}')  # Extract the hostname part before ':'
      hosts_map["$server_id"]="$hostname"  # Populate the associative array with server_id as key and hostname as value
    fi
  done < "$file_path"

  # Convert the values of the associative array to a regular array
  local hosts_array=()
  for server_id in "${!hosts_map[@]}"; do
    hosts_array+=( "${hosts_map[$server_id]}" )  # Add the hostname to the regular array
  done

  # Return the array to the caller
  echo "${hosts_array[@]}"  # Output the hostnames as a list
}

function start_zookeeper_read_config() {
  hosts=( $(read_hosts_from_zk_cluster_file ) )
  start_zookeeper "${hosts[@]}"
}

function stop_zookeeper_read_config() {
  hosts=( $(read_hosts_from_zk_cluster_file ) )
  stop_zookeeper "${hosts[@]}"
}

function status_zookeeper_read_config() {
  hosts=( $(read_hosts_from_zk_cluster_file ) )
  status_zookeeper "${hosts[@]}"
}


#############################################################################################################################
#
# Tool fucntion used for config hadoop
#
#############################################################################################################################

function create_xml_file_with_header() {
  local path=$1  # 文件路径作为参数

  # 检查文件是否存在
  if [[ ! -f "$path" ]]; then
    # 文件不存在，创建文件并填入XML头和配置结构
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$path"
    echo "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>" >> "$path"
    echo "" >> "$path"  # 添加一个空行
    echo "<configuration>" >> "$path"
    echo "</configuration>" >> "$path"
    log_info "File created and initialized with XML header at: $path"
  else
    # 文件已存在
    log_warn "File already exists at: $path"
  fi
}

#add_property_to_hadoop_xml ../conf/yarn-site.xml dfs.namenode.rpc-bind-host 0.0.0.0
function add_property_to_hadoop_xml() {
  local path=$1
  local name=$2
  local value=$3

  local entry="<property><name>$name</name><value>${value}</value></property>"
  local escapedEntry=$(echo $entry | sed 's/\//\\\//g')
  sed -i "/<\/configuration>/ s/.*/${escapedEntry}\n&/" $path
}

function remove_property_from_hadoop_xml() {
  local path=$1  # XML配置文件的路径
  local name=$2  # 要删除的属性的名称

  # 使用sed命令删除包含<name>标签的行，其中属性名称匹配指定的$name
  sed -i "/<name>$name<\/name>/d" $path
}

#configure_hadoop_xmls /etc/hadoop/core-site.xml core CORE_CONF
function configure_hadoop_xmls() {
    local path=$1
    local module=$2
    local envPrefix=$3

    local var
    local value

    log_info "Configuring $module"
    create_xml_file_with_header $path
    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/@/g; s/_/./g; s/@/_/g;'`
        var="${envPrefix}_${c}"
        value=${!var}
        log_info " - Setting $name=$value"
        remove_property_from_hadoop_xml $path $name
        add_property_to_hadoop_xml $path $name "$value"
    done
}