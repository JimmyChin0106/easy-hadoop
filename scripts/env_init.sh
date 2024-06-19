#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/utils.sh"


# 定义函数：关闭防火墙
check_and_disable_firewall() {
    # 检查firewalld服务状态
    if systemctl is-active --quiet firewalld; then
        log_info "防火墙正在运行，正在尝试关闭..."
        systemctl stop firewalld
        systemctl disable firewalld.service
        log_info "防火墙已经关闭。"
    else
        log_info "防火墙已经关闭。"
    fi
}

# 定义函数：创建用户bigdata并配置权限
create_user_bigdata() {
    
    local user="${EASYHADOOP_USER}"
    local passwd="${EASYHADOOP_PASS}"

    if id "${user}" &>/dev/null; then
        log_info "用户${user}已存在。"
    else
        useradd bigdata
        log_info "为用户${user}设置密码..."
        echo "${user}:${passwd}" | chpasswd
        if [ $? -eq 0 ]; then
            log_info "密码设置成功。"
        else
            log_error "密码设置失败，请检查输入的密码格式是否正确。"
        fi
    fi
}

# 定义函数：创建目录并设置权限
create_directories_and_set_permissions() {
    
    local install_dir="${INSTALL_DIR}"
    local software_dir="${INSTALL_DIR}"
    local user="${EASYHADOOP_USER}"

    if [ ! -d "${install_dir}" ]; then
        mkdir -p "${install_dir}"
        log_info "创建了${install_dir}目录。"
    else
        log_info "${install_dir}目录已存在。"
    fi

    if [ ! -d "${software_dir}" ]; then
        mkdir -p "${software_dir}"
        log_info "创建了${software_dir}目录。"
    else
        log_info "${software_dir}目录已存在。"
    fi

    if id "${user}" &>/dev/null; then
        chown -R "${user}:${user}" ${install_dir}
        chown -R "${user}:${user}" ${software_dir}
        log_info "设置了${install_dir}和${software_dir}目录的权限。"
    else
        log_info "用户${user}不存在，无法设置目录权限。"
    fi
}


# 更改主机名的函数
change_hostname() {
    local ip=$1
    local new_hostname=$2

    # 获取本机的所有IP地址
    local machine_ips=$(hostname -I | tr ' ' '\n')

    # 检查提供的IP是否为本机的IP之一
    if echo "$machine_ips" | grep -qw "$ip"; then
        # 获取当前主机名
        current_hostname=$(hostname)

        # 判断是否需要更改主机名
        if [ "$current_hostname" != "$new_hostname" ]; then
            # 更改主机名
            sudo hostnamectl set-hostname "$new_hostname"
            if [ $? -ne 0 ]; then
                log_error "错误: 更改主机名失败，主机名：$new_hostname。"
                return 1
            fi
            log_info "成功: 本地主机名已更改为 $new_hostname。"
        else
            log_info "信息: 本地主机名已经是 $new_hostname，不需要修改。"
        fi
    else
        log_warn "信息: IP 地址 $ip 不是本机的IP地址，不进行更改。"
    fi
}


# 定义主函数
main() {

    log_info "修改服务器Hostname.."
    read_config_and_execution_funtion change_hostname

    log_info "修改域名映射文件.."
    generate_hosts_conf_file
	append_conf_to_hosts

    log_info "关闭并禁用防火墙服务..."
    check_and_disable_firewall

    log_info "创建用户bigdata并设置密码..."
    create_user_bigdata

    log_info "在/opt目录下创建module和software文件夹，并设置权限..."
    create_directories_and_set_permissions

    #remove_installed_java
}
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi