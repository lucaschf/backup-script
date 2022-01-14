#!/usr/bin/bash

declare -r install_path="/usr/sbin"
declare -r main_script="script-LUCAS.sh"

declare -r conf_dir="/etc/backup_script_lucas"
declare -r conf_file_name="backup.conf"
declare -r conf_file_path="$conf_dir/$conf_file_name"

# fails if any pipeline item fails
# fails if a variable is accessed without being set
# fails if any command fails
set -euo pipefail

source $conf_file_path

function echo-err {
    echo "E: $@" >&2
}

function echo-info {
    echo "I: $@" >&2
}

function main {
    if [[ $(id -u) -ne 0 ]]; then
        echo "uninstall: cannot uninstall '$main_script': permission denied. Run as root to proceed"
        exit 1
    fi

    echo-info "removing main script...."
    rm -rf "$install_path/$main_script"

    echo-info "removing backups..."
    rm -rf $backupdir
    echo-info "backups removed"

    echo-info "removing logs..."
    rm -rf "$logdir/$log_file"
    echo-info "logs removed"

    echo-info "removing configuration"
    rm -rf $conf_dir
    echo-info "configuration removed"

    echo-info "Done."
}

main "$@"