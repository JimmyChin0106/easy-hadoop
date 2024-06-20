#!/usr/bin/env bash
#

export PROJECT_VERSION=1.0.0

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

export SCRIPT_DIR="$BASE_DIR"
export PROJECT_DIR=$(dirname "${SCRIPT_DIR}")

export CONFIG_DIR="$PROJECT_DIR/conf"

if [[ ! "$(echo $PATH | grep /usr/local/bin)" ]]; then
  export PATH=/usr/local/bin:$PATH
fi

check_os() {
    if [ -f /etc/centos-release ]; then
        echo "CentOS"
    elif [ -f /etc/debian_version ]; then
        echo "Debian"
    elif [ -f /etc/fedora-release ]; then
        echo "Fedora"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        echo=$NAME
    else
        echo "Unknown"
    fi
}

export OS=$(check_os)

export SOFTWARE_DIR="/opt/software"

export INSTALL_DIR="/opt/module"

export EASYHADOOP_USER="bigdata"

export EASYHADOOP_PASS="bigdata@hadoop123456"

export JAVA_VERSION="jdk1.8.0_212"

export HADOOP_VERSION="hadoop-3.1.3"

export ENV_FILE_PATH="/etc/profile.d/bigdata_env.sh"

export HOSTS_FILE_PATH="/etc/hosts"

export SSH_KEY_PATH="/home/$EASYHADOOP_USER/.ssh"

export LOG_FILE="$PROJECT_DIR/logs/easyhadoop.log"