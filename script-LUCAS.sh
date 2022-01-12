#!/usr/bin/bash

# configuration file path
declare -r config_file_path=/etc/backup-LUCAS/backup.conf


if [[ ! -f $config_file_path ]]; then
    echo "ERR: Config file not found."
    exit 1
fi   

source $config_file_path

declare -r exe_path="${0}"
declare -r log_path=$logdir/$logfile

# falha caso qualquer item do pipeline falhe
# falha caso uma variável seja acessada sem ser definida
# falha o  todo caso qualque comando falhe
set -euo pipefail


function check-config {
    if [ -z ${logdir+x} ]; then 
        echo-err "The log directory(logdir) has not been set in '$config_file_path'."
        exit 1
    fi

    if [ -z ${logfile+x} ]; then 
        echo-err "The log file(logfile) has not been set in '$config_file_path'."
        exit 1
    fi

    if [ -z ${targetdirs+x} ]; then 
        echo-err "The directories for backup(targetdirs) has not been set in '$config_file_path'."
        exit 1
    fi
    
    if [ -z ${backupdir+x} ]; then 
        echo-err "The backup storage directory(backupdir) has not been set in  '$config_file_path'."
        exit 1
    fi
}

function echo-err {
    echo "ERR: $@" >&2
}

function echo-info {
    echo "INFO: $@" >&2
}

function check-and-create-directories-and-files-as-needed {
    if [[ ! -e $logdir ]]; then
        echo-info "Creating the logs directory..."

        if ! mkdir -p $logdir; then
            echo-err "Aborting...."
            exit 1
        fi

        echo-info "Logs directory created successfully."
    fi

    if [[ ! -e $log_path ]]; then
        echo-info "Creating the logs file..."

        if ! touch "$log_path"; then
            echo-err "Aborting..."
            exit 1
        fi

        echo-info "Logs file created successfully."
    fi  

    if [[ ! -e $backupdir ]]; then
        echo-info "Creating the backup storage directory..."

        if ! mkdir -p $backupdir; then
            echo-err "Aborting..."
            exit 1
        fi

        echo-info "backup storage directory created successfully."
    fi
}

# Verifica se os utilitarios necessarios para a execucao estao instalados
function check-tools {
    which tar >/dev/null || {
        echo-err "tar utility not found."
        echo-err "Aborting..."
        return 1
    }

    which sha256sum >/dev/null || {
        echo-err "sha256sum utility not found."
        echo-err "Aborting..."
        return 1
    }

    which bzip2  >/dev/null || {
        echo-err "bzip2 utility not found."
        echo-err "Aborting..."        
        return 1
    }
}

function do-verify-backup-integrity {
    declare backup_file="${1}"       

    declare -r backup_name="${backup_file##*/}"
    declare -r stored_hash_info=$(grep "$backup_name:" $log_path)

    if [[ ! $stored_hash_info ]]; then
        echo-err "Backup record '$backup_name' not found."
        exit 1
    fi
   
    IFS=": "
    read -ra arr <<< "$stored_hash_info"
    declare stored_hash=${arr[-1]}
    
    # backup_name=$(echo $backup_name | xargs)
    # declare backup_file="$backupdir/$backup_name"
    
    if ! is-backup-file-in-accepted-format $backup_file; then
        echo-err "Invalid backup file."
        exit 1
    fi

    if [[ ! -f $backup_file ]]; then
        echo-err "Backup record '$backup_name' not found."
        exit 1
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
Usage: ${exe_path} <-h|-c <path to the bz2 file>|-r <backup_file_path> [directories to restore...]|-b>

    -c <path>                      : Checks the sha256 of the <path> file by comparing it with the execution log

    -r <backup_file_path> [dir...] : Restores content from the backup file in <backup_file_path>. If the parameter dir is informed, 
                                     only the specified directories are restored, otherwise a full restore will be performed

    -b                             : performs the backup according to the .conf file

    -h                             : display this help menu

EOF
}

function do-create-backup {
    declare backup_date backup_start_time backup_end_time
    backup_date=$(date +"%d/%m/%Y")
    backup_start_time=$(date +"%H:%M:%S")
    readonly backup_date
    readonly backup_start_time

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

# verifica se os diretorios especificados para backup sao diretorios validos.
function check-targetdirs {
    IFS=','
    read -ra directories <<< "$targetdirs"

    for path in "${directories[@]}"
     do  
        if [[ ! -d $path ]]; then
            echo-err "Invalid path'$path'. Aborting...."
            exit 1
        fi
     done
}

function archive-directiories {
    check-targetdirs
    declare -r backup_file="${1}"

    # considera todos os outros parametros como diretórios a serem salvos.
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
    declare -r backup_name=${args[0]}
    declare -r backup_file="$backupdir/$backup_name"
    declare target=""

    if ! is-backup-file-in-accepted-format $backup_file; then
        echo-err "Invalid backup file."
        exit 1
    fi

    if [[ ! -f $backup_file ]]; then
        echo-err "Backup file not found."
        exit 1
    fi

    declare arg
    for (( i=1; i<$args_count; i++ ));
    do
        arg=${args[$i]}

        if ! tar -tf $backup_file $arg >/dev/null 2>&1; then
            echo-err "'$arg' directory not found in backup file '$backup_name'."
            exit 1    
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
    check-and-create-directories-and-files-as-needed
    
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
