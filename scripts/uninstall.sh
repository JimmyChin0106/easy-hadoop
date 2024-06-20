#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/utils.sh"
source "${BASE_DIR}/const.sh"

# Step counter
step=0

# Check if the given path directory exists
function check_dir_exists() {
  local dir_path="$1"
  if [ ! -d "$dir_path" ]; then
    echo "Error: The directory $dir_path does not exist."
    exit 1
  fi
}

# Remove the specified directory
function remove_dir() {
  local dir_path="$1"
  if [ -d "$dir_path" ]; then
    echo "Removing $dir_path..."
    rm -rf "$dir_path"
    if [ $? -eq 0 ]; then
      echo "$dir_path has been successfully removed."
    else
      echo "Error: Failed to remove $dir_path."
      exit 1
    fi
  else
    echo "Note: $dir_path does not exist, no need to remove."
  fi
}

# Remove the specified symlink
function remove_symlink() {
  local link_path="$1"
  if [ -L "$link_path" ]; then
    log_info "Removing symlink $link_path..."
    rm "$link_path"
    if [ $? -eq 0 ]; then
      log_info "Symlink $link_path has been successfully removed."
    else
      log_error "Error: Failed to remove symlink $link_path."
      exit 1
    fi
  else
    log_info "Note: Symlink $link_path does not exist, no need to remove."
  fi
}

# Function to uninstall Java
function uninstall_java() {
  check_dir_exists "${INSTALL_DIR}"

  # Remove the Java version directory
  JAVA_VERSION_DIR="${INSTALL_DIR}/${JAVA_VERSION}"
  remove_dir "$JAVA_VERSION_DIR"

  # Remove the Java symlink
  JAVA_SYMLINK="$INSTALL_DIR/jdk"
  remove_symlink "$JAVA_SYMLINK"
}

# Function to uninstall Hadoop
function uninstall_hadoop() {
  check_dir_exists "${INSTALL_DIR}"

  # Remove the Hadoop version directory
  HADOOP_VERSION_DIR="${INSTALL_DIR}/${HADOOP_VERSION}"
  remove_dir "$HADOOP_VERSION_DIR"

  # Remove the Hadoop symlink
  HADOOP_SYMLINK="$INSTALL_DIR/hadoop"
  remove_symlink "$HADOOP_SYMLINK"
}

# Function to remotely uninstall Hadoop
uninstall_hadoop_remote() {
  # Remove the Hadoop version directory remotely
  HADOOP_VERSION_DIR="${INSTALL_DIR}/${HADOOP_VERSION}"
  log_info "Removing $HADOOP_VERSION_DIR remotely..."
  execute_cluster "rm -rf $HADOOP_VERSION_DIR"

  # Remove the Hadoop symlink remotely
  HADOOP_SYMLINK="$INSTALL_DIR/hadoop"
  log_info "Removing symlink $HADOOP_SYMLINK remotely..."
  execute_cluster "rm -rf $HADOOP_SYMLINK"
}

# Function to remotely uninstall Java
uninstall_java_remote() {
  # Remove the Java version directory remotely
  JAVA_VERSION_DIR="${INSTALL_DIR}/${JAVA_VERSION}"
  log_info "Removing $JAVA_VERSION_DIR remotely..."
  execute_cluster "rm -rf $JAVA_VERSION_DIR"

  # Remove the Java symlink remotely
  JAVA_SYMLINK="$INSTALL_DIR/jdk"
  log_info "Removing symlink $JAVA_SYMLINK remotely..."
  execute_cluster "rm -rf $JAVA_SYMLINK"
}

# Function to remotely remove the installation directory
remove_install_dir_remote() {
  # Remove the installation directory remotely
  log_info "Removing $INSTALL_DIR remotely..."
  execute_cluster "rm -rf $INSTALL_DIR"
}

# Function to remotely remove the environment file path
remove_env_file_path_remote() {
  # Remove the environment file path remotely
  log_info "Removing $ENV_FILE_PATH remotely..."
  execute_cluster "rm $ENV_FILE_PATH"
}

# Function to remotely remove the SSH key path
remove_ssh_key_path_remote() {
  # Remove the SSH key path remotely
  log_info "Removing $SSH_KEY_PATH remotely..."
  execute_cluster "rm -rf $SSH_KEY_PATH/*"
}

# Main function
main() {
    log_info "Step $step: Starting to uninstall the big data cluster..."
    ((step++))

    ((step++))
    log_info "Step $step: Starting to uninstall Hadoop..."
    uninstall_hadoop_remote

    ((step++))
    log_info "Step $step: Starting to uninstall Java..."
    uninstall_java_remote

    ((step++))
    log_info "Step $step: Starting to remove the installation directory..."
    remove_install_dir_remote

    ((step++))
    log_info "Step $step: Starting to remove the environment file path..."
    remove_env_file_path_remote

    ((step++))
    log_info "Step $step: Starting to remove the SSH key path..."
    remove_ssh_key_path_remote
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi