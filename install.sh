#!/usr/bin/bash

declare -r install_path="/usr/sbin"
declare -r main_script="script-LUCAS.sh"
declare -r script_src_path="${PWD}/$main_script"

declare -r conf_dir="/etc/backup_script_lucas"
declare -r conf_file_name="backup.conf"
declare -r conf_file_path="$conf_dir/$conf_file_name"

if [[ $(id -u) -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

function echo-err {
    echo "E: $@" >&2
}

function echo-info {
    echo "I: $@" >&2
}

function check-tools {
    which tar >/dev/null || {
        echo-err "tar utility not found."
        return 1
    }

    which sha256sum >/dev/null || {
        echo-err "sha256sum utility not found."        
        return 1
    }

    which bzip2  >/dev/null || {
        echo-err "bzip2 utility not found."
        return 1
    }
}

function setup-config {
    echo-info "Setting up configuration..."

    if [[ ! -e $conf_dir ]]; then
        echo-info "Creating config directory..."

        if ! mkdir -p $conf_dir; then
            echo-err "Aborting...."
            exit 1
        fi

        echo-info "Conf directory created successfully."
    fi  

    if [[ ! -f $conf_file_path ]]; then
        echo-info "Creating configuration file..."

        if ! touch "$conf_file_path"; then
            echo-err "Aborting..."
            exit 1
        fi

        write-conf-content

        echo-info "Config file created successfully."
    fi  
}

function write-conf-content {

    declare -r default_log_dir = "/var/backup_script_lucas/logs"
    declare -r default_log_file = "backup-LUCAS.log"
    declare -r default_targetdirs = "/var"
    declare -r default_backupdir = "/bckp"
         
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

setup-config "$@"
cp -v $script_src_path $install_path
chmod+x "$install_path/$main_script"
echo-info "Install complete."
