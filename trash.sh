#!/bin/bash
#check for root access
if [[ "$(id -un)" != 'root' ]]; then
    printf '\n%s\n' "Please run this script with sudo to proceed"
    printf '\n%s\n\n' "sudo ./$(basename -- "$0")"
    exit 1
fi

#Checking if Docker is installed
echo "Checking if Docker package is installed..."
if ! synopkg is_onoff Docker > /dev/null 2>&1; then
    wget -qO /volume1/docker.spk "https://global.download.synology.com/download/Package/spk/Docker/20.10.3-1239/Docker-x64-20.10.3-1239.spk"
    synopkg install /volume1/docker.spk
    synopkg start Docker
    # test it
    synopkg is_onoff Docker
    #delete file
    rm /volume1/docker.spk
fi

user="docker"                                                    # {Update me if needed} User App will run as and the owner of it's binaries
puid="$(id $user -u)"                                            # Grabs puid for user created
group="users"                                                    # {Update me if needed} Group App will run as.
dockerdir="/volume1/docker"                                      # docker directory
datadir="/volume1/data"                                          # /data share
ip="$(ip route get 1 | awk '{print $NF;exit}')"                  # get local ip
TZ="(realpath --relative-to /usr/share/zoneinfo /etc/localtime)" # get timezone

#check for /data share
echo "Checking if /data share excists..."
if [[ -d "$datadir" ]]; then
    ### Take action if $datadir exists ###
    printf '\n%s\n' "/data share exist, continuing..."
else
    ###  Control will jump here if $datadir does NOT exists ###
    printf '\n%s\n' "/data share does not exist, creating"
    synoshare --add data "Data Directory" "$datadir" "$user" "$user" "$user"
fi

#check for $user
echo "Checking if user 'docker' exists..."
if ! synouser --get "$user" &> /dev/null; then
    printf '\n%s\n' "The user 'docker' doesn't exist, creating."
    synouser --add "$user" rekcod "Docker User" 0 "" 0
else
    printf '\n%s\n' "User 'docker' exists. Carry on."
fi

echo "Setting user rights to shares..."
synoshare --setuser data RW + $user,@$group
synoshare --setuser docker RW + $user,@$group
echo "User has rights to share."

echo "Creating appdata directories..."
mkdir -p /volume1/docker/appdata/{radarr,sonarr,bazarr,plex,pullio}
echo "Appdata directories created."

echo "Creating media directories..."
mkdir -p /volume1/data/media/{tv,movies,music}
echo "Media directories created."

echo "Downloading docker compose..."
#wget https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/docker-compose.yml -P "$dockerdir/appdata/"
wget https://raw.githubusercontent.com/bokkoman/trash-syno-installer/main/docker-compose.yml -P "$dockerdir/appdata/"
echo "Docker compose download."

echo "Downloading environment file..."
wget https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/.env -P "$dockerdir/appdata/"
echo ".env file downloaded."

echo "Setting correct User ID in .env ..."
sed -i s/1035/"$puid"/g "$dockerdir/appdata/.env"
echo "User ID set.."

echo "Setting local IP in .env ..."
sed -i s/192.168.x.x/"$ip"/g "$dockerdir/appdata/.env"
echo "Local IP set."

echo "Setting timezone in .env ..."
sed -i s/"Europe/Amsterdam"/"$TZ"/g "$dockerdir/appdata/.env"
echo "Timezone set."

mapfile -t mkdir_usenet < <(printf '%s\n' /volume1/data/{usenet/{tv,movies,music},media/{tv,movies,music}})     # mkdir -p "${mkdir_usenet[@]}"
mapfile -t mkdir_torrents < <(printf '%s\n' /volume1/data/{torrents/{tv,movies,music},media/{tv,movies,music}}) # mkdir -p "${mkdir_torrents[@]}"

PS3=$'\n'"Please select from the options: "
options=("torrents" "usenet" "both" "quit")
printf '\n%s\n' "Select your preferred download method."
select opt in "${options[@]}"; do
    case "$opt" in
        "torrents")
            printf '\n%s\n' "You chose torrents, creating data directories..."
            mkdir -p "${mkdir_torrents[@]}"
            printf '\n%s\n' "Choose your torrent client:"
            options=("qbittorrent" "qbittorrentvpn" "deluge" "delugevpn" "rtorrentvpn" "quit")
            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "qbittorrentvpn")
                        printf '\n%s\n\n' "You picked Qbittorrent with VPN"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "delugevpn")
                        printf '\n%s\n\n' "You picked Deluge with VPN"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "rtorrentvpn")
                        printf '\n%s\n\n' "You picked rTorrent with VPN"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "quit")
                        exit
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
            printf '\n%s\n' "Choose your usenet client:"
            options=("nzbget" "sabnzbd" "quit")
            select opt in "${options[@]}"; do
                case "$opt" in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "quit")
                        exit
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done
            ;;
        "both")
            printf '\n%s\n' "Creating data directories for torrent and usenet."
            mkdir -p "${mkdir_usenet[@]}" "${mkdir_torrents[@]}"

            printf '\n%s\n\n' "Choose your torrent client:"
            options=("qbittorrent" "qbittorrentvpn" "deluge" "delugevpn" "rtorrentvpn" "quit")

            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "qbittorrentvpn")
                        printf '\n%s\n\n' "You picked Qbittorrent with VPN"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "delugevpn")
                        printf '\n%s\n\n' "You picked Deluge with VPN"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "rtorrentvpn")
                        printf '\n%s\n\n' "You picked rTorrent with VPN"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "quit")
                        exit
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done

            printf '\n%s\n' "Choose your usenet client:"
            options=("nzbget" "sabnzbd" "quit")
            select opt in "${options[@]}"; do
                case $opt in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p "/volume1/docker/appdata/$opt"
                        break
                        ;;
                    "quit")
                        exit
                        ;;
                    *)
                        printf '\n%s\n\n' "invalid option $REPLY"
                        ;;
                esac
            done
            break
            ;;
        "quit")
            exit
            ;;
        *)
            printf '\n%s\n\n' "invalid option $REPLY"
            ;;
    esac
    break
done

echo "Doing final permissions stuff..."
chown -R $user:$group $datadir $dockerdir
chmod -R a=,a+rX,u+w,g+w $datadir $dockerdir
echo "Permissions set."

echo "Installing Pullio for auto updates..."
sudo curl -fsSL "https://raw.githubusercontent.com/hotio/pullio/master/pullio.sh" -o /usr/local/bin/pullio
sudo chmod +x /usr/local/bin/pullio
echo "Pullio installed"

echo "Creating task for auto updates..."

echo "Now let's install the containers..."
docker-compose -f "$dockerdir/appdata/docker-compose.yml" up -d
echo "All set, everything should be running. If you have errors, follow the complete guide. And join our discord server."

exit 0
