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
    echo "$@" >&2
}

if [[ ! -e $logdir ]]; then
    echo "Criando diretório de logs..."

    if ! mkdir -p $logdir; then
        echo-err "Abortando...."
        exit 1
    fi

    echo "Diretório de logs criado"
fi


if [[ ! -e $log_path ]]; then
    echo "Criando arquivo de logs..."

    if ! touch "$log_path"; then
        echo-err "Abortando..."
        exit 1
    fi

    echo "Arquivos de logs criado"
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

function main {
    check-tools
    declare OPTIND optkey
    while getopts "c:bhr:" optkey; do
        case "${optkey}" in
            c)
                do-check-backup "${OPTARG}" && return 0
                ;;
            h)
                do-show-usage && return 0
                ;;
            b)
                do-executar-backup && return 0
                ;;
            r)
                shift $((OPTIND-2))
                do-restaurar-backup "$@" && return 0;
                ;;
            *)
                do-show-usage && return 1
                ;;
        esac
    done
    shift $((OPTIND-1))
}

function do-check-backup {
    declare backup_name="${1}"       
    declare -r hash_info=$(grep "$backup_name" $log_path)

    if [[ $hash_info ]]; then        
        IFS=": "
        read -ra arr <<< "$hash_info"
        declare stored_hash=${arr[-1]}
        
        backup_name=$(echo $backup_name | xargs)
        declare backup_file="$backupdestination/$backup_name"
        
        if [[ ! -f $backup_file ]]; then
            echo-err "Arquivo de backup nao encontrado"
            exit 1
        fi

        declare -r current_hash=$(shasum -a 256 "${backup_file}" | cut -f 1 -d ' ')

        if [[ $stored_hash == $current_hash ]]; then
            echo "Backup íntegro."
        else
            echo "Integridade do backup comprometida."
        fi

        return 0
    fi

    echo-err "Log de backup nao encontrado"
    
    exit 1
}

function do-show-usage {
    cat >&2 <<EOF
Usage: ${exe_path} <-h|-c <caminho para o arquivo bz2>|-r <diretorios para restaurar>|-b>

    -c <caminho>            : Verifica o sha256 do arquivo <caminho> comparando-o com o log de execução

    -r <dir1> <dir2> <dir3> : Restaura o conteúdo dos diretórios <dir1>, <dir2> e <dir3>

    -b                      : Efetua o backup de acordo com o arquivo .conf

    -h                      : Exibe este menu

EOF
}

function do-executar-backup {
    declare backup_date backup_start_time backup_end_time
    backup_date=$(date +"%d/%m/%Y")
    backup_start_time=$(date +"%H:%M:%S")
    readonly backup_date
    readonly backup_start_time

    declare backup_name="backup-$(date +"%Y%m%d")-$(date +"%H%M").tar.bz2" 
    declare backup_path="$backupdestination/$backup_name" 
    
    check-targetdirs

    arquivar-diretorios $backup_path $targetdirs

    backup_end_time=$(date +"%H:%M:%S")

    readonly backup_end_time

    save-log $log_path $backup_path
}

function check-targetdirs {
    IFS=','
    read -ra directories <<< "$targetdirs"

    for path in "${directories[@]}"
     do  
        if [[ ! -d $path ]]; then
            echo-err "O caminho '$path' não é um diretório válido. Abortando...."
            exit 1
        fi
     done
}

function arquivar-diretorios {
    declare -r backup_file="${1}"

    # considera todos os outros parametros como diretórios
    # a serem salvos
    shift

    tar -jcf "${backup_file}" "$@"
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

function do-restaurar-backup {
    echo-err "Args: ${*}"
    echo-err "Arg count: ${#}"
    echo-err "not implemented [${1} ${2}]"
    return 1;
}

main "${*}"
