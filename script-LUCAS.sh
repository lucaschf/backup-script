#!/usr/bin/bash

# configuration file path
source /etc/backup-LUCAS/backup.conf

declare -r exe_path="${0}"
declare -r log_path=$logdir/$logfile

# falha caso qualquer item do pipeline falhe
# falha caso uma variável seja acessada sem ser definida
# falha o  todo caso qualque comando falhe
set -euo pipefail

# padrões:
# variável minúscula indica variável local
# variável maiuscula indica vaiável exportada/importada do ambiente

function echo-err {
    echo "ERR: $@" >&2
}

function echo-info {
    echo "INFO: $@" >&2
}

if [[ ! -e $logdir ]]; then
    echo-info "Criando diretório de logs..."

    if ! mkdir -p $logdir; then
        echo-err "Abortando...."
        exit 1
    fi

    echo-info "Diretório de logs criado"
fi

if [[ ! -e $log_path ]]; then
    echo "Criando arquivo de logs..."

    if ! touch "$log_path"; then
        echo-err "Abortando..."
        exit 1
    fi

    echo "Arquivo de logs criado"
fi  S

if [[ ! -e $backupdir ]]; then
    echo-info "Criando diretório de backups..."

    if ! mkdir -p $backupdir; then
        echo-err "Abortando...."
        exit 1
    fi

    echo-info "Diretório de backups criado"

fi

# Verifica se os utilitarios necessarios para a execucao estao instalados
function check-tools {
    which tar >/dev/null || {
        echo-err "utilitário tar não foi encontrado"
        return 1
    }

    which shasum >/dev/null || {
        echo-err "utilitário shasum não foi encontrado"
        return 1
    }
}

function do-verify-backup-integrity {
    declare backup_name="${1}"       
    declare -r stored_hash_info=$(grep "$backup_name:" $log_path)

    if [[ ! $stored_hash_info ]]; then
        echo-err "Registro de backup '$backup_name' não encontrado."
        exit 1
    fi
   
    IFS=": "
    read -ra arr <<< "$stored_hash_info"
    declare stored_hash=${arr[-1]}
    
    backup_name=$(echo $backup_name | xargs)
    declare backup_file="$backupdir/$backup_name"
    
    if [[ ! -f $backup_file ]]; then
        echo-err "Arquivo de backup nao encontrado"
        exit 1
    fi

    declare -r current_hash=$(shasum -a 256 "${backup_file}" | cut -f 1 -d ' ')

    echo-info "Stored hash: $stored_hash"
    echo-info "File calculated hash: $current_hash"

    if [[ $stored_hash == $current_hash ]]; then
        echo-info "Backup íntegro."
    else
        echo-info "Integridade do backup comprometida."
    fi

    return 0
}

function do-show-usage {
    cat >&2 <<EOF
Usage: ${exe_path} <-h|-c <caminho para o arquivo bz2>|-r <diretorios para restaurar>|-b>

    -c <caminho>                   : Verifica o sha256 do arquivo <caminho> comparando-o com o log de execução

    -r <backup_file_path> <dir...> : Restaura o conteúdo dos diretórios <dir> a partir do arquivo de backup <backup_file_path>

    -b                             : Efetua o backup de acordo com o arquivo .conf

    -h                             : Exibe este menu

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

    archive-directiories $backup_path

    backup_end_time=$(date +"%H:%M:%S")
    readonly backup_end_time

    save-log $log_path $backup_path
}

# verifica se os diretorios especificados para backup sao diretorios validos.
function check-targetdirs {
    IFS=','
    read -ra directories <<< "$targetdirs"

    for path in "${directories[@]}"
     do  
        if [[ ! -d $path ]]; then
            echo-err "O caminho '$path' não é válido. Abortando...."
            exit 1
        fi
     done
}

function archive-directiories {
    check-targetdirs
    declare -r backup_file="${1}"

    # considera todos os outros parametros como diretórios a serem salvos.
    shift

    tar -jcf "${backup_file}" $targetdirs # 2> /dev/null
}

function save-log {
    declare -r log_file="${1}"
    declare -r backup_file="${2}"

    declare hash_backup=$(shasum -a 256 "${backup_file}" | cut -f 1 -d ' ');
    readonly hash_backup

    declare backup_content
    backup_content=$(tar -tf "${backup_file}")
    
    readonly backup_content   
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

function do-backup-restore {
    declare -r args=("$@")
    declare -r args_count=${#args[@]}

    if [[ $args_count < 2 ]]; then
        echo-err "Informe o diretorio a ser restaurado"
        exit 1
    fi

    declare -r backup_name=${args[0]}
    declare -r backup_file="$backupdir/$backup_name"
    declare target=""

    if [[ ! -f $backup_file ]]; then
        echo-err "Arquivo de backup nao encontrado."
        exit 1
    fi

    declare backup_content
    backup_content=$(tar -tf "${backup_file}")

    declare arg
    for (( i=1; i<args_count; i++ ));
    do
        arg=${args[$i]}

        if ! tar -tf $backup_file $arg >/dev/null 2>&1; then
            echo-err "O diretório '$arg' não está contido no backup '$backup_name'."
            exit 1    
        fi

        target+=" $arg"
    done

    echo-info "Iniciando restauração..."
    tar -C / -xf $backup_file $target
    echo-info "Restauração realizada com sucesso."
}

function main {
    check-tools
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
        echo-err "No options were passed."
        do-show-usage && return 1
    fi
    shift $((OPTIND-1))
}

# function check-args {

# }

function getopts-extra () {
    declare i=1
    # if the next argument is not an option, then append it to array OPTARG
    while [[ ${OPTIND} -le $# && ${!OPTIND:0:1} != '-' ]]; do
        OPTARG[i]=${!OPTIND}
        let i++ OPTIND++
    done
}

main "$@"
