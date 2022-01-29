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
        echo-err "you don't have permission to read from $BACKUP_PATH"
        abort
    fi  

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
    declare -r target_folder="{$1}" 
    declare -r rotation_type="{$2}" # m = montly, h = every 8 hours, d = daily, w = weekly

    check-and-create-folder-as-needed $TEMPORARY_FOLDER
    check-and-create-folder-as-needed $target_folder

    if ! ls "$BACKUP_PATH/*$BACKUP_FILE_EXTENSION" &> /dev/null; then
        abort "No backup to rotate"
    fi

    # remove any temporary saved backup on temporary folder
    rm -r "$TEMPORARY_FOLDER/*"

    # move the rotated backup to temporary folder only if is not montly
    if rotation_type != 'm'; then
        if ! mv "$target_folder/*$BACKUP_FILE_EXTENSION" $TEMPORARY_FOLDER &> /dev/null; then 
            abort "unable to rotate backups. Creating temporary copy failed."
        fi
    fi

    # move the backup to rotation folder
    mv "$BACKUP_PATH/*$BACKUP_FILE_EXTENSION" $target_folder

    # ensure that temporary folder is empty
    rm -r "$TEMPORARY_FOLDER/*"
}

function main {
    # check-backup-directory

    declare OPTIND optkey
    while getopts "hdwm" optkey; do
        case "${optkey}" in
            h)
                check-and-rotate-backups "$BACKUP_PATH/every_eight_hours" 'm' && return 0;
                ;;
            d) 
                check-and-rotate-backups "$BACKUP_PATH/daily" 'd' && return 0;
                ;;
            w)
                check-and-rotate-backups "$BACKUP_PATH/weekly" 'w' && return 0;
                ;;
            m)
                check-and-rotate-backups "$BACKUP_PATH/montly" 'm' && return 0;
                ;;
            *)
                abort "invalid option"
                ;;
        esac
    done
    if [ $OPTIND -eq 1 ]; then
        abort "expected arg not informed" && return 1
    fi
    shift $((OPTIND-1))
}

main "$@"