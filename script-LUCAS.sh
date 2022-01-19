#!/usr/bin/bash

# configuration file path
declare -r config_file_path=/etc/backup_script_lucas/backup.conf

source $config_file_path

declare -r exe_path="${0}"
declare -r log_path=$logdir/$logfile

# fails if any pipeline item fails
# fails if a variable is accessed without being set
# fails if any command fails
set -euo pipefail

function check-config {

    if [ ! -r $config_file_path ]; then
        echo-err "you don't have permission to read from $log_path"
        abort
    fi  

    if [ -z ${logdir+x} ]; then 
        echo-err "The log directory(logdir) has not been set in '$config_file_path'."
        abort
    fi

    if [ -z ${logfile+x} ]; then 
        echo-err "The log file(logfile) has not been set in '$config_file_path'."
        abort
    fi

    if [ -z ${targetdirs+x} ]; then 
        echo-err "The directories for backup(targetdirs) has not been set in '$config_file_path'."
        abort
    fi
    
    if [ -z ${backupdir+x} ]; then 
        echo-err "The backup storage directory(backupdir) has not been set in  '$config_file_path'."
        abort
    fi
}

function echo-err {
    echo "E: $@" >&2
}

function echo-info {
    echo "I: $@" >&2
}

function abort {
    echo-err "Aborting..."
    exit 1
}

function check-and-create-directories-and-files-as-needed {
    if [[ ! -e $logdir ]]; then
        echo-info "Creating the logs directory..."

        if ! mkdir -p $logdir 2>>/dev/null; then
            echo-err "unable to create logs folder. Check your permisssion."
            abort
        fi

        echo-info "Logs directory created successfully."
    fi

    if [[ ! -e $log_path ]]; then
        echo-info "Creating the logs file..."

        if ! touch $log_path 2>>/dev/null ; then
            echo-err "unable to create logs file. Check your permisssion."
            abort
        fi

        echo-info "Logs file created successfully."
    fi  

    if [[ ! -e $backupdir ]]; then
        echo-info "Creating the backup storage directory..."

        if ! mkdir -p $backupdir 2>>/dev/null; then
            echo-err "unable to create backups folder. Check your permisssion."
            abort
        fi

        echo-info "backup storage directory created successfully."
    fi
}

function check-write-permission {
    if [ ! -w $log_path ]; then
        echo-err "you don't have permission to write in $log_path"
        abort
    fi

    if [ ! -w $backupdir ]; then
        echo-err "you don't have permission to write in $backupdir"
    fi
}

# Checks if the utilities needed for the execution are installed
function check-tools {
    which tar >/dev/null || {
        echo-err "tar utility not found."
        abort
    }

    which sha256sum >/dev/null || {
        echo-err "sha256sum utility not found."
        abort
    }

    which bzip2  >/dev/null || {
        echo-err "bzip2 utility not found."
        abort
    }
}

function do-verify-backup-integrity {
    declare backup_file="${1}"       
    declare -r backup_name="${backup_file##*/}"

    if [ ! -f $log_path ]; then
        echo-err "Backup log for '$backup_name' not found."
        abort
    fi;

    if [ ! -r $log_path ]; then
        echo-err "you don't have permission to read from $log_path"
        abort
    fi
   
    declare -r stored_hash_info=$(grep "$backup_name:" $log_path)

    if [[ ! $stored_hash_info ]]; then
        echo-err "Backup record '$backup_name' not found."
        abort
    fi
   
    IFS=": "
    read -ra arr <<< "$stored_hash_info"
    declare stored_hash=${arr[-1]}
    
    if ! is-backup-file-in-accepted-format $backup_file; then
        echo-err "Invalid backup file."
        abort
    fi

    if [[ ! -f $backup_file ]]; then
        echo-err "Backup record '$backup_name' not found."
        abort
    fi

    declare -r current_hash=$(calculate-hash $backup_file)

    echo-info "Stored hash: $stored_hash"
    echo-info "File calculated hash: $current_hash"

    if [[ $stored_hash == $current_hash ]]; then
        echo-info "Backup íntegrity is intact."
    else
        echo-info "Backup íntegrity compromised."
    fi

    return 0
}

function do-show-usage {
    cat >&2 <<EOF
Usage: ${exe_path} <-h|-c <path to the bz2 file>|-r <path to the bz2 file> [directories to restore...]|-b>

    -c <path>          : Checks the sha256 of the <path> file by comparing it with the execution log

    -r <path> [dir...] : Restores content from the backup file in <path>. If the parameter dir is informed, 
                         only the specified directories are restored, otherwise a full restore will be performed.
                         WARNING: When using the dir parameter, enter the full path of the file or directory 
                         to restore from the root, without the leading '/'. For example,
                         if you want to restore the directory '/home/user/important' the argument would be: home/user/important

    -b                 : performs the backup according to the .conf file

    -h                 : display this help menu

EOF
}

function do-create-backup {
    declare backup_date backup_start_time backup_end_time
    backup_date=$(date +"%d/%m/%Y")
    backup_start_time=$(date +"%H:%M:%S")
    readonly backup_date
    readonly backup_start_time

    check-and-create-directories-and-files-as-needed
    check-write-permission

    declare backup_name="backup-$(date +"%Y%m%d")-$(date +"%H%M").tar.bz2" 
    declare backup_path="$backupdir/$backup_name"    

    echo-info "Performing backup. Please be patient..."

    archive-directiories $backup_path
    backup_end_time=$(date +"%H:%M:%S")
    
    readonly backup_end_time

    echo-info "Generating logs..."
    save-log $log_path $backup_path
    echo-info "Finished."
}

# checks whether the directories specified for backup are valid ones.
function check-targetdirs {
    IFS=','
    read -ra directories <<< "$targetdirs"

    for path in "${directories[@]}"
     do  
        if [[ ! -d $path ]]; then
            echo-err "Invalid path'$path'."
            abort
        fi

        if [ ! -r $path ]; then
            echo-err "cannot read from '$path'"
            abort
        fi
     done
}

function archive-directiories {
    check-targetdirs
    declare -r backup_file="${1}"

    # considers all other parameters as directories to be saved.
    shift

    tar -jcf "${backup_file}" $targetdirs 2> /dev/null
}

function calculate-hash {
    declare -r file="${1}"

    echo-info "Calculating hash. Please be patient..."
    declare -r hash=$(sha256sum "${backup_file}" | cut -f 1 -d ' ')

    echo "$hash"
}

function save-log {
    declare -r log_file="${1}"
    declare -r backup_file="${2}"

    declare -r hash_backup=$(calculate-hash $backup_file)
    declare -r backup_content=$(tar -tf "${backup_file}") 
    declare -r filename=$(basename $backup_file)

cat <<EOF >> "${log_file}" 
Execução do Backup - ${backup_date}
Horário de início - ${backup_start_time}

Arquivos inseridos no backup:
${backup_content}

Arquivo gerado: ${backup_file}
Hash sha256 do ${filename}: ${hash_backup}

Horário da Finalização do backup – ${backup_end_time}
***************************************************************
EOF
}

function is-backup-file-in-accepted-format {
    declare file="${1}"  

    if [[ $file == *.bz2 ]]; then
        return 0
    fi
    
    return 1
}   

function do-backup-restore {
    declare -r args=("$@")
    declare -r args_count=${#args[@]}
    declare -r backup_file=${args[0]}   
    declare -r backup_name="${backup_file##*/}"
    declare target=""

    do-verify-backup-integrity $backup_file

    if [ ! -r $backup_file ]; then
        echo-err "you don't have permission to read from $backup_file"
        abort
    fi

    declare arg
    for (( i=1; i<$args_count; i++ ));
    do
        arg=${args[$i]}

        if ! tar -tf $backup_file $arg >/dev/null 2>&1; then
            echo-err "'$arg' directory not found in backup file '$backup_name'."
            abort   
        fi

        target+=" $arg"
    done

    echo-info "Performing restoration. Please be patient..."
    tar -C / -xf $backup_file $target
    echo-info "Finished."
}

function main {
    check-tools
    check-config
    
    declare OPTIND optkey
    while getopts "c:bhr:" optkey; do
        case "${optkey}" in
            c)
                do-verify-backup-integrity "${OPTARG}" && return 0
                ;;
            h)
                do-show-usage && return 0
                ;;
            b)
                do-create-backup && return 0
                ;;
            r)
                getopts-extra "$@"
                args=( "${OPTARG[@]}" )
                do-backup-restore "${args[@]}" && return 0;
                ;;
            *)
                do-show-usage && return 1
                ;;
        esac
    done
    if [ $OPTIND -eq 1 ]; then
        do-show-usage && return 1
    fi
    shift $((OPTIND-1))
}

function getopts-extra () {
    declare i=1
    # if the next argument is not an option, then append it to array OPTARG
    while [[ ${OPTIND} -le $# && ${!OPTIND:0:1} != '-' ]]; do
        OPTARG[i]=${!OPTIND}
        let i++ OPTIND++
    done
}

main "$@"
