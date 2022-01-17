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

function echo-err {
    echo "E: $@" >&2
}

function echo-info {
    echo "I: $@" >&2
}

function abort {
    echo-err "Aborting...."
    exit 1
}

function setup-config {
    echo-info "Setting up configuration..."

    if [[ ! -e $conf_dir ]]; then
        echo-info "Creating config directory..."

        if ! mkdir -p $conf_dir; then
           abort
        fi

        echo-info "Conf directory created successfully."
    fi  

    if [[ ! -f $conf_file_path ]]; then
        echo-info "Creating configuration file..."

        if ! touch "$conf_file_path"; then
           abort
        fi

        echo-info "Generating default config..."
        write-conf-content
        chmod +r $conf_file_path
        echo-info "Config file created successfully."
    fi  
}

function write-conf-content {

    declare -r default_log_dir="/var/log"
    declare -r default_log_file="backup-LUCAS.log"
    declare -r default_targetdirs="/usr/src"
    declare -r default_backupdir="/bckp"
         
cat <<EOF >> "${conf_file_path}"
# log file location must NOT end with "/"
logdir=$default_log_dir

# log file name
logfile=$default_log_file 

# target directories for backup. For multiple directories use ',' to separate.
targetdirs=$default_targetdirs

# location to save created backups
backupdir=$default_backupdir 
EOF
}

function main {
    if [[ $(id -u) -ne 0 ]]; then
        echo "install: cannot install '$main_script': permission denied. Run as root to proceed"
        exit 1
    fi
    
    declare -r installed_path="$install_path/$main_script"
    
    if [[ ! -f $script_src_path ]]; then
        echo-err "Unable to locate '$main_script' file."
        abort
    fi

    setup-config
    echo-info "Copying main script..."
    cp $script_src_path $install_path
    chmod +x "$installed_path"
    echo-info "Install complete."
    echo-info "you can execute the script by running the command: "
    echo "   (cd $install_path && ./$main_script <OPTION>)"
}

main "$@"