#!/usr/bin/env bash

# shellcheck disable=SC2034  # Unused variables left for readability

####################### DESCRIPTION: #######################
#
# multiselect is a pure bash implementation of a multi
# selection menu.
#
# If "true" is passed as first argument a help (similar to
# the overview in section "USAGE") will be printed before
# showing the options. Any other value will hide it.
#
# The result will be stored as an array in a variable
# that is passed to multiselect as second argument.
#
# The third argument takes an array that contains all
# available options.
#
# The last argument is optional and can be used to
# preselect certain options. If used it must be an array
# that has a value of "true" for every index of the options
# array that should be preselected.
#
########################## USAGE: ##########################
#
#   j or ↓        => down
#   k or ↑        => up
#   ⎵ (Space)     => toggle selection
#   ⏎ (Enter)     => confirm selection
#
######################### EXAMPLE: #########################
#
# source <(curl -sL multiselect.miu.io)
#
# my_options=(   "Option 1"  "Option 2"  "Option 3" )
# preselection=( "true"      "true"      "false"    )
#
# multiselect "true" result my_options preselection
#
# idx=0
# for option in "${my_options[@]}"; do
#     echo -e "$option\t=> ${result[idx]}"
#     ((idx++))
# done
#
############################################################

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Author       - Ideas and original and code by @bokkoman.
# Contributors - Big thanks to @userdocs for helping with the script.
# Testers      - Thanks @Davo1624 for testing.
# Supporters   - @thezak48 for not getting upset we spammed the #general channel
# Credits      - https://trash-guides.info https://github.com/TRaSH-/Guides-Synology-Templates

## This script is created for Synology systems that support Docker. Tested on DSM v7.

# check for root access and exit if the user does not have the required privilages.

## start of multi select
function multiselect {
    if [[ "${1}" = "true" ]]; then
        echo -e "j or ↓\t\t=> down"
        echo -e "k or ↑\t\t=> up"
        echo -e "⎵ (Space)\t=> toggle selection"
        echo -e "⏎ (Enter)\t=> confirm selection"
        echo
    fi

    # little helpers for terminal print control and key input
    cursor_blink_on() { printf "\033[?25h"; }
    cursor_blink_off() { printf "\033[?25l"; }
    cursor_to() { printf '%b' "\033[$1;${2:-1}H"; }
    print_inactive() { printf '%b' "${2}   ${1} "; }
    print_active() { printf '%b' "${2}  \033[7m ${1} \033[27m"; }
    get_cursor_row() {
        IFS=';' read -rsdR -p $'\E[6n' ROW COL
        printf '%b' "${ROW#*[}"
    }

    local -n options="${2}"
    local -n defaults="${3}"

    local selected=()
    for ((i = 0; i < ${#options[@]}; i++)); do
        if [[ "${defaults[i]}" = "true" ]]; then
            selected+=("true")
        else
            selected+=("false")
        fi
        printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow
    lastrow="$(get_cursor_row)"
    local startrow
    startrow="$((lastrow - ${#options[@]}))"

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    key_input() {
        local key
        IFS= read -rsn1 key 2> /dev/null >&2
        case "${key}" in
            '')
                echo enter
                ;;
            $'\x20')
                echo space
                ;;
            'k')
                echo up
                ;;
            'j')
                echo down
                ;;
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A' | 'k')
                        echo up
                        ;;&
                    '[B' | 'j')
                        echo down
                        ;;&
                esac
                ;;
            *) ;;
        esac
    }

    toggle_option() {
        local option=$1
        if [[ ${selected[option]} == true ]]; then
            selected[option]=false
        else
            selected[option]=true
        fi
    }

    print_options() {
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == true ]]; then
                prefix="[\e[38;5;46m✔\e[0m]"
            fi

            cursor_to $((startrow + idx))
            if [[ "${idx}" -eq "${1}" ]]; then
                print_active "${option}" "${prefix}"
            else
                print_inactive "${option}" "${prefix}"
            fi
            ((idx++))
        done
    }

    local active=0
    while true; do
        print_options "${active}"
        # user key control
        case $(key_input) in
            space) toggle_option "${active}" ;;
            enter)
                print_options -1
                break
                ;;
            up)
                ((active--))
                if [[ "${active}" -lt 0 ]]; then active=$((${#options[@]} - 1)); fi
                ;;
            down)
                ((active++))
                if [[ "${active}" -ge ${#options[@]} ]]; then active=0; fi
                ;;
        esac
    done

    # cursor position back to normal
    cursor_to "${lastrow}"
    printf "\n"
    cursor_blink_on

    declare -gA result
    for i in "${!my_options[@]}"; do
        result["${my_options[i]}"]="${selected[i]}"
    done
}
# Start prerequisites
# check for root access and exit if the user does not have the required privilages.
if [[ "$(id -un)" != 'root' ]]; then
    printf '\n%s\n' "Please run this script with sudo to proceed"
    printf '\n%s\n\n' "sudo ./$(basename -- "$0")"
    exit 1
fi

# Some colour output for printf - start color with ${col_red} end it with ${col_end}: printf '\n%b\n' "${col_red}This will be red text${col_end} this will be normal text"
col_red="\e[1;31m"
col_green="\e[1;32m"
col_yellow="\e[1;33m"
# col_blue="\e[1;34m"
# col_magenta="\e[1;35m"
# col_cyan="\e[1;36m"
col_end="\e[0m"

# Create an array of all available volumes on this device
mapfile -t volume_list_array < <(mount -l | grep -E "/volume[0-9]{1,2}\s" | awk '{ print $3 }' | sort -V) # printf '%s\n' "${volume_list_array[@]}"

# if there is only one volume default to that else ask the user where they want to install stuff
if [[ "${#volume_list_array[@]}" -eq '1' ]]; then
    docker_install_volume="${volume_list_array[0]}"
else
    if [[ "$(# if docker is already installed, active or stopped, get the default share path and use that automatically, skipping the docker prompts.
        synopkg status Docker &> /dev/null
        printf '%s' "$?"
    )" -le '1' ]]; then
        # if docker is installed but there is more than one volume get the default path and set to the variable - docker_install_volume
        docker_install_volume="$(sed -rn 's|(.*)path=(/volume(.*))/docker|\2|p' /etc/samba/smb.share.conf)"
        install_docker="no"
    elif [[ "$(# if docker is not installed actiave the docker prompts
        synopkg status Docker &> /dev/null
        printf '%s' "$?"
    )" -gt '1' ]]; then
        # if docker is not installed but there is more than one volume ask the user which volume they want to use for the installation and set this to the variable - docker_install_volume
        PS3=$'\n'"Please select where to install docker from the list of volumes: "
        printf "\n%b\n\n" "${col_green}This is where docker will be installed and the conf dirs stored${col_end}"
        select option in "${volume_list_array[@]}"; do # in "$@" is the default
            if [[ "$REPLY" -gt "${#volume_list_array[@]}" ]]; then
                printf '\n%b\n' "${col_red}This is not a valid volume option, try again.${col_end}"
            else
                docker_install_volume="$(printf '%s' "${option}")"
                printf '%b\n' "${col_yellow}"
                read -erp "You selected ${docker_install_volume} is this correct: " -i "yes" confirm
                printf '%b' "${col_end}"
                [[ "${confirm}" =~ ^[yY](es)?$ ]] && break
            fi
        done
        install_docker="yes"
    fi

    # If there is more than one volume ask the user which volume they want to use for the data directories and set this to the variable - docker_data_volume
    PS3=$'\n'"Please select a data volume from the list of volumes: "
    printf "\n%b\n\n" "${col_green}This volume is where the data files will be stored (movies, shows, etc)${col_end}"
    select option in "${volume_list_array[@]}"; do # in "$@" is the default
        if [[ "$REPLY" -gt "${#volume_list_array[@]}" ]]; then
            printf '\n%b\n' "${col_red}This is not a valid volume option, try again.${col_end}"
        else
            docker_data_volume="$(printf '%s' "${option}")"
            printf '%b\n' "${col_yellow}"
            read -erp "You selected $docker_data_volume is this correct: " -i "yes" confirm
            printf '%b' "${col_end}"
            [[ "${confirm}" =~ ^[yY](es)?$ ]] && break
        fi
    done
fi

user="docker"                                                                                  # {Update me if needed} User App will run as and the owner of it's binaries
group="users"                                                                                  # {Update me if needed} Group App will run as.
password=$(openssl rand -base64 14)                                                            # generate a password
docker_conf_dir="${docker_install_volume}/docker"                                              # docker directory
docker_data_dir="${docker_data_volume:-${docker_install_volume}}/data"                         # /data share
ip="$(ip route get 1 | awk '{print $NF;exit}')"                                                # get local ip
gateway="$(ip route | grep "$(ip route get 1 | awk '{print $7}')" | awk 'FNR==2{print $1}')"   # get gateway ip
TZ="$(realpath --relative-to /usr/share/zoneinfo /etc/localtime)"                              # get timezone
synoinfo_default_path="$(sed -rn 's|(.*)(pkg_def_intall_vol="(.*)")|\2|p' /etc/synoinfo.conf)" # set the default path for app installations.
qsv="/dev/dri/"

# get the lastest docker version by scraping the archive.synology.com page for the package.
docker_version=$(curl -sL "https://archive.synology.com/download/Package/Docker" | sed -rn 's|(.*)href="/download/Package/Docker/(.*)" (.*)|\2|p' | head -n 1) # get the lastest docker version

# Set the brace expanded filepaths into arrays so that we can create them easily with mkdir and a quoted expansion
mapfile -t mkdir_appdata < <(printf '%s\n' "$docker_conf_dir"/appdata/{radarr,sonarr,bazarr,plex,pullio}) # mkdir -p "${mkdir_appdata[@]}"
mapfile -t mkdir_media < <(printf '%s\n' "$docker_data_dir"/media/{tv,movies,music})                      # mkdir -p "${mkdir_media[@]}"
mapfile -t mkdir_usenet < <(printf '%s\n' "$docker_data_dir"/usenet/{tv,movies,music})                    # mkdir -p "${mkdir_usenet[@]}"
mapfile -t mkdir_torrents < <(printf '%s\n' "$docker_data_dir"/torrents/{tv,movies,music})                # mkdir -p "${mkdir_torrents[@]}"

# Install docker if install_docker=yes or skip
if [[ "${install_docker}" == 'yes' ]]; then
    printf '\n%s\n\n' "Installing Docker package..."

    if [[ "${#volume_list_array[@]}" -gt '1' ]]; then
        sed -r 's|pkg_def_intall_vol="(.*)"|pkg_def_intall_vol="'"$docker_install_volume"'"|g' -i.synoinfo.conf.bak-"$(date +%H-%M-%S)" /etc/synoinfo.conf
        synoinfo_modified="true"
    fi

    wget -qO "$docker_install_volume/docker.spk" "https://global.download.synology.com/download/Package/spk/Docker/$docker_version/Docker-x64-$docker_version.spk"
    synopkg install "$docker_install_volume/docker.spk"

    if [[ "${synoinfo_modified}" == 'true' ]]; then
        sed -r 's|pkg_def_intall_vol="(.*)"|pkg_def_intall_vol="'"$synoinfo_default_path"'"|g' -i /etc/synoinfo.conf
    fi
else
    printf '\n%s\n\n' "Docker package is already installed ..."
fi

synopkg start Docker &> /dev/null

if [[ "$(
    synopkg status Docker &> /dev/null
    printf '%s' "$?"
)" -le '0' ]]; then
    [[ -f "$docker_install_volume/docker.spk" ]] && rm -f "$docker_install_volume/docker.spk"
    printf '\n%b\n\n' "${col_red}Docker has been started and is running${col_end}"
else
    printf '\n%b\n\n' "${col_red}Docker installation has not worked, please try again${col_end}"
    exit 1
fi

#check for $user
printf '\n%s\n\n' "Checking if user 'docker' exists..."
if ! synouser --get "$user" &> /dev/null; then
    printf '\n%s\n' "The user 'docker' doesn't exist, creating."
    synouser --add "$user" "$password" "Docker User" 0 "" 0
else
    printf '\n%s\n' "User 'docker' exists. Carry on."
fi

#check for /data share
printf '\n%s\n\n' "Checking if /data share excists..."
if [[ -d "$docker_data_dir" ]]; then
    ### Take action if $docker_data_dir exists ###
    printf '\n%s\n' "$docker_data_dir share exist, continuing..."
else
    ###  Control will jump here if $docker_data_dir does NOT exists ###
    printf '\n%s\n' "$docker_data_dir share does not exist, creating"
    synoshare --add data "Data Directory" "${docker_data_dir}" "" "$user" "" 1 0
fi

printf '\n%s\n\n' "Setting user rights to shares..."
synoshare --setuser data RW + $user,@$group
synoshare --setuser docker RW + $user,@$group
printf '\n%s\n\n' "User has rights to share."

printf '\n%s\n\n' "Creating appdata directories..."
mkdir -p "${mkdir_appdata[@]}"
printf '\n%s\n\n' "Appdata directories created."

printf '\n%s\n\n' "Creating media directories..."
mkdir -p "${mkdir_media[@]}"
printf '\n%s\n\n' "Media directories created."

# Create the necessary file structure for vpn tunnel device
# Thanks @Gabe
if [[ ! -c /dev/net/tun ]]; then
    if [[ ! -d /dev/net ]]; then
        mkdir -m 755 /dev/net
    fi
    mknod /dev/net/tun c 10 200
    chmod 0755 /dev/net/tun
fi

# Load the tun module if not already loaded
if ( ! (lsmod | grep -q "^tun\s")); then
    insmod /lib/modules/tun.ko
fi

# Create docker-compose.yml and download .env

printf '\n%s\n' "Creating docker-compose.yml..."
cat > "$docker_conf_dir/appdata/docker-compose.yml" << EOF
version: "3.2"
services:
EOF

printf '\n%s\n' "Downloading docker env..."
if wget -qO "$docker_conf_dir/appdata/.env" https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/.env; then
    printf '\n%s\n' "Docker .env downloaded."
else
    printf '\n%s\n' "There was a problem downloading then .env, try again"
    exit 1
fi

# Set all .env variables
printf '\n%s\n\n' "Setting correct User ID in .env ..."
sed -i "s|PUID=1035|PUID=$(id "$user" -u)|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "User ID set.."

printf '\n%s\n\n' "Setting local IP in .env ..."
sed -i "s|192.168.x.x:32400|$ip:32400|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "Local IP set."

printf '\n%s\n\n' "Setting local Gateway in .env ..."
sed -i "s|LAN_NETWORK=192.168.x.x/24|LAN_NETWORK=$gateway|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "local Gateway set."

printf '\n%s\n\n' "Setting timezone in .env ..."
sed -i "s|Europe/Amsterdam|$TZ|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "Timezone set."

printf '\n%s\n\n' "Setting correct docker config dir in then .env ..."
sed -i "s|DOCKERCONFDIR=/volume1/docker|DOCKERCONFDIR=$docker_conf_dir|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "/volume set."

printf '\n%s\n\n' "Setting correct docker storage dir in the .env ..."
sed -i "s|DOCKERSTORAGEDIR=/volume1/data|DOCKERSTORAGEDIR=$docker_data_dir|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "/volume set."

# compose template downloader
get_app_compose() {
    if wget -qO "$docker_conf_dir/appdata/$1.yml" "https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/templates/$1.yml"; then
        printf '\n' >> "$docker_conf_dir/appdata/docker-compose.yml"
        sed -n 'p' "$docker_conf_dir/appdata/$1.yml" >> "$docker_conf_dir/appdata/docker-compose.yml"
        rm -f "$docker_conf_dir/appdata/$1.yml"
        printf '\n%s\n' "$1 template added to compose."
    else
        printf '\n%s\n' "There was a problem downloading the template for $1, try again"
        exit 1
    fi
}

# Start menu selection
my_options=("radarr" "sonarr" "bazarr" "prowlarr" "plex" "nzbget" "sabnzbd" "qbittorrent" "notifiarr" "recyclarr" "tautulli" "overseerr")
preselection=("true" "true" "true" "true" "true")

multiselect "true" my_options preselection

for options in "${!result[@]}"; do
    if [[ "${result[$options]}" == true ]]; then
        selected_options+=("${options}")
        get_app_compose "$options"
    elif [[ ! "${result[*]}" =~ 'true' ]]; then
        printf '%s\n' "it's null bruh"
        exit 1
    fi
done

#for app in "${selected_options[@]}"; do
#    get_app_compose "$app"
#done

# You can use thee "${selected_options[@]}" array to install apps as it is just the name of the app.

printf 'You have selected:\n\n'
printf '%s\n' "${selected_options[@]}"
printf '\n'

while true; do
    read -rp "Is this correct selection? " yn
    case $yn in
        [Yy]*)
            printf '\n%s\n\n' "Doing final permissions stuff..."
            chown -R "$user":"$group" "$docker_data_dir" "$docker_conf_dir"
            chmod -R a=,a+rX,u+w,g+w "$docker_data_dir" "$docker_conf_dir"
            printf '\n%s\n\n' "Permissions set."

            printf '\n%s\n' "Installing Pullio for auto updates..."
            if sudo wget -qO /usr/local/bin/pullio "https://raw.githubusercontent.com/hotio/pullio/master/pullio.sh"; then
                sudo chmod +x /usr/local/bin/pullio
                printf '\n%s\n\n' "Pullio installed"
            else
                printf '\n%s\n' "There was a problem downloading then /usr/local/bin/pullio, try again"
                exit 1
            fi

            printf '\n%s\n\n' "Creating task for auto updates..."
            if grep -q '/usr/local/bin/pullio' /etc/crontab; then
                sed -e '/\/usr\/local\/bin\/pullio/d' -e '/^$/d' -i.bak-"$(date +%H-%M-%S)" /etc/crontab
            else
                cp -f /etc/crontab /etc/crontab.bak-"$(date +%H-%M-%S)"
            fi

            printf '%s\n' '0    3    *    *    7    root    /usr/local/bin/pullio &>> '"$docker_conf_dir"'/appdata/pullio/pullio.log' >> /etc/crontab
            sed 's/    /\t/g' -i /etc/crontab
            systemctl -q restart crond
            systemctl -q restart synoscheduler
            printf '\n%s\n\n' "Task Created"

            printf '\n%s\n\n' "Now let's install the containers..."
            cd "$docker_conf_dir/appdata/" || return
            docker-compose up -d
            printf '\n%s\n\n' "All set, everything should be running. If you have errors, follow the complete guide. And join our discord server."
            break
            ;;
        [Nn]*) printf '\n%s\n\n' "Rerun the script." exit ;;
        *) echo "Please answer yes or no." ;;
    esac
done
exit
