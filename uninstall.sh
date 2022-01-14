#!/usr/bin/bash

declare -r install_path="/usr/sbin"
declare -r main_script="script-LUCAS.sh"
declare -r script_src_path="${PWD}/$main_script"

declare -r conf_dir="/etc/backup_script_lucas"
declare -r conf_file_name="backup.conf"
declare -r conf_file_path="$conf_dir/$conf_file_name"

# fails if any pipeline item fails
# fails if a variable is accessed without being set
# fails if any command fails
set -euo pipefail

source $config_file_path

function echo-err {
    echo "E: $@" >&2
}

function echo-info {
    echo "I: $@" >&2
}

function main {
    f [[ $(id -u) -ne 0 ]]; then
        echo "uninstall: cannot uninstall '$main_script': permission denied. Run as root to proceed"
        exit 1
    fi

    echo-info "removing main script...."
    rm -r $script_src_path $install_path

    echo-info "removing backups..."
    rm -r $backupdir
    echo-info "backups removed"

    echo-info "removing logs..."
    rm -r $logdir
    echo-info "logs removed"

    echo-info "removing configuration"
    rm -r $conf_dir
    echo-info "configuration removed"
}