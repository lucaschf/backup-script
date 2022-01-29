#!/usr/bin/bash

declare -r BACKUP_PATH="$HOME/bckp" 
declare -r TEMPORARY_FOLDER="$BACKUP_PATH/temp"
declare -r BACKUP_FILE_EXTENSION=".tar.bz2"


function echo-err {
    echo "E: $@" >&2
}

function echo-info {
    echo "rotation: $@" >&2
}

function abort {
    echo-info "$@"
    echo-info "Aborting..."
    exit 1
}

function check-backup-directory {
    if [[ ! -e $BACKUP_PATH ]]; then
        abort "Unable to locate the specified backup directory..."
    fi

    if [ ! -r $BACKUP_PATH ]; then
        echo-err "you don't have permission to read from '$BACKUP_PATH'"
        abort
    fi  
}

function check-and-create-folder-as-needed {
    declare -r path="${1}"

    if [[ ! -d $path ]]; then 
        echo-info "Folder $path' not found. Creating..."

        if ! mkdir -p $path  2>>/dev/null; then
            abort "Unable to locate/create folder '$path'. Check your permission." 
        fi

        echo-info "Folder successfully created"
    fi
}

function check-and-rotate-backups {
    declare -r target_folder="${1}" 
    declare -r rotation_type="${2}" # m = montly, h = every 8 hours, d = daily, w = weekly
    declare -r montly_rotation="m"

    check-and-create-folder-as-needed $TEMPORARY_FOLDER
    check-and-create-folder-as-needed $target_folder

    declare -r pattern=$BACKUP_PATH/*$BACKUP_FILE_EXTENSION
    
    if ! ls $pattern &> /dev/null; then
        abort "No backup to rotate"
    fi    

    # remove any temporary saved backup on temporary folder
    rm -r "$TEMPORARY_FOLDER/*" &> /dev/null

    # move the rotated backup to temporary folder only if is not montly
    if [[ $rotation_type != $montly_rotation ]]; then
  
        declare -r check=$target_folder/*$BACKUP_FILE_EXTENSION 

        if ls $check &> /dev/null; then
            if ! mv $check $TEMPORARY_FOLDER &> /dev/null; then 
                abort 'ended with error. Unable to create secure copy'
            fi
        fi
    fi

    # move the backup to rotation folder
    if ! mv $pattern $target_folder &> /dev/null; then     
        if [[ $rotation_type = $montly_rotation ]]; then
            echo "SEM PROBLEMA"
        else
            mv $TEMPORARY_FOLDER/*$BACKUP_FILE_EXTENSION $target_folder &> /dev/null
        fi
        abort "rotation ended with error"
    fi

    # ensure that temporary folder is empty
    rm -rf $TEMPORARY_FOLDER/* &> /dev/null

    echo-info "done"
}

function main {
    # check-backup-directory

    declare OPTIND optkey
    while getopts "hdwm" optkey; do
        case "${optkey}" in
            h)
                check-and-rotate-backups "$BACKUP_PATH/every_eight_hours" "h" && return 0;
                ;;
            d) 
                check-and-rotate-backups "$BACKUP_PATH/daily" "d" && return 0;
                ;;
            w)
                check-and-rotate-backups "$BACKUP_PATH/weekly" "w" && return 0;
                ;;
            m)
                check-and-rotate-backups "$BACKUP_PATH/montly" "m" && return 0;
                ;;
            *)
                return 1
                ;;
        esac
    done
    if [ $OPTIND -eq 1 ]; then
        abort "expected arg not informed"
    fi
    shift $((OPTIND-1))
}

main "$@"
