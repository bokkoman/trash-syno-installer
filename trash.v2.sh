#!/usr/bin/env bash

### Big thanks to @userdocs for creating the script.
### Idea by @bokkoman.
### https://trash-guides.info

## This script is created for Synology systems that support Docker. Tested on DSM v7.

#check for root access
if [[ "$(id -un)" != 'root' ]]; then
    printf '\n%s\n' "Please run this script with sudo to proceed"
    printf '\n%s\n\n' "sudo ./$(basename -- "$0")"
    exit 1
fi

user="docker"                                                                                # {Update me if needed} User App will run as and the owner of it's binaries
group="users"                                                                                # {Update me if needed} Group App will run as.
password=$(openssl rand -base64 14)                                                          # generate a password
volume="/${volume:-volume1}"                                                                 # use default volume unless one was provided as an env: export volume=volume4
dockerdir="$volume/docker"                                                                   # docker directory
datadir="$volume/data"                                                                       # /data share
ip="$(ip route get 1 | awk '{print $NF;exit}')"                                              # get local ip
gateway="$(ip route | grep "$(ip route get 1 | awk '{print $7}')" | awk 'FNR==2{print $1}')" # get gateway info
TZ="$(realpath --relative-to /usr/share/zoneinfo /etc/localtime)"                            # get timezone

# Set the brace expanded filepaths into arrays so that we can create them easily with mkdir and a quoted expansion

mapfile -t mkdir_appdata < <(printf '%s\n' "$dockerdir"/appdata/{radarr,sonarr,bazarr,plex,pullio})          # mkdir -p "${mkdir_appdata[@]}"
mapfile -t mkdir_media < <(printf '%s\n' "$datadir"/media/{tv,movies,music})                                 # mkdir -p "${mkdir_media[@]}"
mapfile -t mkdir_usenet < <(printf '%s\n' "$datadir"/{usenet/{tv,movies,music},media/{tv,movies,music}})     # mkdir -p "${mkdir_usenet[@]}"
mapfile -t mkdir_torrents < <(printf '%s\n' "$datadir"/{torrents/{tv,movies,music},media/{tv,movies,music}}) # mkdir -p "${mkdir_torrents[@]}"

#Checking if Docker is installed
printf '\n%s\n\n' "Checking if Docker package is installed..."
if ! synopkg is_onoff Docker &> /dev/null; then
    wget -qO "$volume/docker.spk" "https://global.download.synology.com/download/Package/spk/Docker/20.10.3-1239/Docker-x64-20.10.3-1239.spk"
    synopkg install "$volume/docker.spk"
    synopkg start Docker
    # test it
    synopkg is_onoff Docker
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
if [[ -d "$datadir" ]]; then
    ### Take action if $datadir exists ###
    printf '\n%s\n' "$datadir share exist, continuing..."
else
    ###  Control will jump here if $datadir does NOT exists ###
    printf '\n%s\n' "$datadir share does not exist, creating"
    synoshare --add data "Data Directory" "${datadir}" "" "$user" "" 1 0
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

printf '\n%s\n' "Downloading docker compose..."
if wget -qO "$dockerdir/appdata/docker-compose.yml" https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/docker-compose.yml; then
    printf '\n%s\n' "Docker compose downloaded."
else
    printf '\n%s\n' "There was a problem downloading then docker-compose.yml, try again"
    exit 1
fi

printf '\n%s\n' "Downloading docker env..."
if wget -qO "$dockerdir/appdata/.env" https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/.env; then
    printf '\n%s\n' "Docker .env downloaded."
else
    printf '\n%s\n' "There was a problem downloading then .env, try again"
    exit 1
fi

printf '\n%s\n\n' "Setting correct User ID in .env ..."
sed -i "s|PUID=1035|PUID=$(id "$user" -u)|g" "$dockerdir/appdata/.env"
printf '\n%s\n\n' "User ID set.."

printf '\n%s\n\n' "Setting local IP in .env ..."
sed -i "s|192.168.x.x:32400|$ip:32400|g" "$dockerdir/appdata/.env"
printf '\n%s\n\n' "Local IP set."

printf '\n%s\n\n' "Setting local Gateway in .env ..."
sed -i "s|LAN_NETWORK=192.168.x.x/24|LAN_NETWORK=$gateway|g" "$dockerdir/appdata/.env"
printf '\n%s\n\n' "local Gateway set."

printf '\n%s\n\n' "Setting timezone in .env ..."
sed -i "s|Europe/Amsterdam|$TZ|g" "$dockerdir/appdata/.env"
printf '\n%s\n\n' "Timezone set."

printf '\n%s\n\n' "Setting correct /volume in .env ..."
sed -i "s|=/volume1/|=/$volume/|g" "$dockerdir/appdata/.env"
printf '\n%s\n\n' "/volume set."

get_app_compose() {
    if wget -qO "$dockerdir/appdata/$1.yml" "https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/templates/$1.yml"; then
        printf '\n\n' >> "$dockerdir/appdata/docker-compose.yml"
        cat "$dockerdir/appdata/$1.yml" >> "$dockerdir/appdata/docker-compose.yml"
        rm -f "$dockerdir/appdata/$1.yml"
        printf '\n%s\n' "Docker compose for $1 downloaded."
    else
        printf '\n%s\n' "There was a problem downloading the compose for $1, try again"
        exit 1
    fi
}

PS3=$'\n'"Please select from the options: "
options=("torrents" "usenet" "both")
printf '\n%s\n\n' "Select your preferred download method."
select opt in "${options[@]}"; do
    case "$opt" in
        "torrents")
            printf '\n%s\n' "You chose torrents, creating data directories..."
            mkdir -p "${mkdir_torrents[@]}"
            printf '\n%s\n\n' "Choose your torrent client:"
            options=("qbittorrent" "qbittorrentvpn" "deluge" "delugevpn" "rtorrentvpn")
            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "qbittorrentvpn")
                        printf '\n%s\n\n' "You picked Qbittorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "delugevpn")
                        printf '\n%s\n\n' "You picked Deluge with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "rtorrentvpn")
                        printf '\n%s\n\n' "You picked rTorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    *)
                        printf '\n%s\n\n' "invalid option $REPLY"
                        ;;
                esac
            done
            ;;
        "usenet")
            printf '\n%s\n' "You chose usenet, Creating data directories..."
            mkdir -p "${mkdir_usenet[@]}"
            printf '\n%s\n\n' "Choose your usenet client:"
            options=("nzbget" "sabnzbd")
            select opt in "${options[@]}"; do
                case "$opt" in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done
            ;;
        "both")
            printf '\n%s\n' "Creating data directories for torrent and usenet."
            mkdir -p "${mkdir_usenet[@]}" "${mkdir_torrents[@]}"

            printf '\n%s\n\n' "Choose your torrent client:"
            options=("qbittorrent" "qbittorrentvpn" "deluge" "delugevpn" "rtorrentvpn")

            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "qbittorrentvpn")
                        printf '\n%s\n\n' "You picked Qbittorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "delugevpn")
                        printf '\n%s\n\n' "You picked Deluge with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "rtorrentvpn")
                        printf '\n%s\n\n' "You picked rTorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done

            printf '\n%s\n\n' "Choose your usenet client:"
            options=("nzbget" "sabnzbd")
            select opt in "${options[@]}"; do
                case $opt in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        get_app_compose "$opt"
                        mkdir -p "$dockerdir/appdata/$opt"
                        break
                        ;;
                    *)
                        printf '\n%s\n\n' "invalid option $REPLY"
                        ;;
                esac
            done
            break
            ;;
        *)
            printf '\n%s\n\n' "invalid option $REPLY"
            ;;
    esac
    break
done

printf '\n%s\n\n' "Doing final permissions stuff..."
chown -R "$user":"$group" "$datadir" "$dockerdir"
chmod -R a=,a+rX,u+w,g+w "$datadir" "$dockerdir"
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

printf '%s\n' '0    3    *    *    7    root    /usr/local/bin/pullio &>> '"$dockerdir"'/appdata/pullio/pullio.log' >> /etc/crontab
sed 's/    /\t/g' -i /etc/crontab
systemctl -q restart crond
systemctl -q restart synoscheduler
printf '\n%s\n\n' "Task Created"

printf '\n%s\n\n' "Now let's install the containers..."
docker-compose -f "$dockerdir/appdata/docker-compose.yml" up -d
printf '\n%s\n\n' "All set, everything should be running. If you have errors, follow the complete guide. And join our discord server."

exit
