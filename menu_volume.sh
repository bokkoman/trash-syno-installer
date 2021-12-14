#!/usr/bin/bash

mapfile -t volume_list_array < <(mount -l | grep -E "/volume[0-9]{1,2}\s" | awk '{ print $3 }' | sort -V) # printf '%s\n' "${volume_list_array[@]}"

if [[ "${#volume_list_array[@]}" -eq '1' ]]; then
    volume="${volume_list_array[0]}"
else
    createmenu() {
        REPLY=""
        volume=""
        PS3=$'\n'"Please select a volume to use from the options: "
        printf '\n'
        select option; do # in "$@" is the default
            if [[ "$REPLY" -gt "$#" ]]; then
                printf '\n%s\n' "This is not a valid volume option, try again."
            else
                volume="$(printf '%s' "${option}")"
                printf '\n'
                read -erp "You selected $volume is this correct: " -i "yes" confirm
                [[ "${confirm}" =~ ^[yY](es)?$ ]] && break
            fi
        done
    }
    createmenu "${volume_list_array[@]}"
fi
exit
