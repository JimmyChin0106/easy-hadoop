#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${BASE_DIR}/utils.sh"

# Define function: Check and disable the firewall
function check_and_disable_firewall() {
    # Check the status of the firewalld service
    if systemctl is-active --quiet firewalld; then
        log_info "The firewall is running, attempting to stop..."
        systemctl stop firewalld
        systemctl disable firewalld.service
        log_info "The firewall has been disabled."
    else
        log_info "The firewall is already disabled."
    fi
}

# Define function: Create user 'bigdata' and set permissions
function create_user_bigdata() {

    local user="${EASYHADOOP_USER}"
    local passwd="${EASYHADOOP_PASS}"

    if id "${user}" &>/dev/null; then
        log_info "User '${user}' already exists."
    else
        useradd bigdata
        log_info "Setting password for user '${user}'..."
        echo "${user}:${passwd}" | chpasswd
        if [ $? -eq 0 ]; then
            log_info "Password set successfully."
        else
            log_error "Password setting failed, please check the password format."
        fi
    fi
}

# Define function: Create directories and set permissions
function create_directories_and_set_permissions() {

    local install_dir="${INSTALL_DIR}"
    local software_dir="${SOFTWARE_DIR}"  # Assuming this should be SOFTWARE_DIR instead of INSTALL_DIR again
    local user="${EASYHADOOP_USER}"

    if [ ! -d "${install_dir}" ]; then
        mkdir -p "${install_dir}"
        log_info "Created directory '${install_dir}'."
    else
        log_info "Directory '${install_dir}' already exists."
    fi

    if [ ! -d "${software_dir}" ]; then
        mkdir -p "${software_dir}"
        log_info "Created directory '${software_dir}'."
    else
        log_info "Directory '${software_dir}' already exists."
    fi

    if id "${user}" &>/dev/null; then
        chown -R "${user}:${user}" "${install_dir}"
        chown -R "${user}:${user}" "${software_dir}"
        log_info "Set permissions for directories '${install_dir}' and '${software_dir}'."
    else
        log_info "User '${user}' does not exist, cannot set directory permissions."
    fi
}

# Function to change the hostname
function change_hostname() {
    local ip=$1
    local new_hostname=$2

    # Get all IP addresses of the machine
    local machine_ips=$(hostname -I | tr ' ' '\n')

    # Check if the provided IP is one of the machine's IPs
    if echo "$machine_ips" | grep -qw "$ip"; then
        # Get the current hostname
        current_hostname=$(hostname)

        # Determine if the hostname needs to be changed
        if [ "$current_hostname" != "$new_hostname" ]; then
            # Change the hostname
            sudo hostnamectl set-hostname "$new_hostname"
            if [ $? -ne 0 ]; then
                log_error "Error: Failed to change hostname to $new_hostname."
                return 1
            fi
            log_info "Success: Local hostname has been changed to $new_hostname."
        else
            log_info "Info: Local hostname is already $new_hostname, no change needed."
        fi
    else
        log_warn "Info: IP address $ip is not one of the machine's IP addresses, no change made."
    fi
}

# Define the main function
main() {

    log_info "Modifying server hostname..."
    read_config_and_execution_function change_hostname  # Assuming this is a function that reads a configuration and calls change_hostname

    log_info "Modifying domain mapping file..."
    generate_hosts_conf_file
    append_conf_to_hosts

    log_info "Stopping and disabling the firewall service..."
    check_and_disable_firewall

    log_info "Creating user 'bigdata' and setting password..."
    create_user_bigdata

    log_info "Creating 'module' and 'software' directories under '/opt' and setting permissions..."
    create_directories_and_set_permissions

    # Additional commands like remove_installed_java would go here if they were defined
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    main
fi