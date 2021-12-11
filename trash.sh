#!/bin/bash
#check for root access
if [[ "$(id -un)" != 'root' ]]; then
    printf '\n%s\n' "Please run this script with sudo to proceed"
    printf '\n%s\n\n' "sudo ./$(basename -- "$0")"
    exit 1
fi

#Checking if Docker is installed
if ! synopkg is_onoff Docker > /dev/null 2>&1; then
    wget -qO /volume1/docker.spk "https://global.download.synology.com/download/Package/spk/Docker/20.10.3-1239/Docker-x64-20.10.3-1239.spk"
    synopkg install /volume1/docker.spk
    synopkg start Docker
    # test it
    synopkg is_onoff Docker
fi

user="docker"               # {Update me if needed} User App will run as and the owner of it's binaries
puid="$(id $user -u)"       # Grabs puid for user created
group="users"               # {Update me if needed} Group App will run as.
dockerdir="/volume1/docker" # docker directory
datadir="/volume1/data"     # /data share

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

echo "Downloading docker compose..."
#wget https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/docker-compose.yml -P "$dockerdir/appdata/"
wget https://raw.githubusercontent.com/bokkoman/trash-syno-installer/main/docker-compose.yml -P "$dockerdir/appdata/"
echo "Docker compose download."

echo "Downloading environment file..."
wget https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/.env -P "$dockerdir/appdata/"
echo ".env file downloaded."

echo "Setting correct User ID in .env ..."
sed -i "s/1035/$puid/g" "$dockerdir/appdata/.env"
echo "User ID set.."

PS3='Please select your method of downloading: '
options=("torrents" "usenet" "both" "quit")
select opt in "${options[@]}"; do
    case $opt in
        "torrents")
            printf '\n%s\n' " You chose torrents"
            printf '\n%s\n\n' " Creating data directories..."
            mkdir -p /volume1/data/{torrents/{tv,movies,music},media/{tv,movies,music}}
            printf '\n%s\n' " Choose your torrent client:"
            options=("qbittorrent" "deluge" "rtorrent" "quit")
            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/qbittorrent
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/deluge
                        ;;
                    "rtorrent")
                        printf '\n%s\n\n' "You picked rTorrent"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/rtorrent
                        ;;
                    "quit")
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done
            ;;
        "usenet")
            printf '\n%s\n' " You chose usenet"
            printf '\n%s\n\n' " Creating data directories..."
            mkdir -p /volume1/data/{usenet/{tv,movies,music},media/{tv,movies,music}}
            printf '\n%s\n' " Choose your usenet client:"
            options=("nzbget" "sabnzbd" "quit")
            select opt in "${options[@]}"; do
                case $opt in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/nzbget
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/sabnzbd
                        ;;
                    "quit")
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done
            ;;
        "both")
            c
            printf '\n%s\n\n' " Creating data directories..."
            mkdir -p /volume1/data/{torrents/{tv,movies,music},media/{tv,movies,music}}
            mkdir -p /volume1/data/{usenet/{tv,movies,music},media/{tv,movies,music}}
            printf '\n%s\n' " Choose your torrent client:"
            options=("qbittorent" "deluge" "rtorrent" "quit")
            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/qbittorrent
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/deluge
                        ;;
                    "rtorrent")
                        printf '\n%s\n\n' "You picked rTorrent"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/rtorrent
                        ;;
                    "quit")
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done
            printf '\n%s\n' " Choose your usenet client:"
            options=("nzbget" "sabnzbd" "quit")
            select opt in "${options[@]}"; do
                case $opt in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/nzbget
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        sed -i "s/#$opt//" "$dockerdir/appdata/docker-compose.yml"
                        mkdir -p /volume1/docker/appdata/sabnzbd
                        ;;
                    "quit")
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done
            break
            ;;
        *) printf '\n%s\n\n' "invalid option $REPLY" ;;
    esac
done

echo "Doing final permissions stuff..."
chown -R $user:$group $datadir $dockerdir
chmod -R a=,a+rX,u+w,g+w $datadir $dockerdir
echo "Permissions set."

echo "Now let's install the containers..."
docker-compose -f "$dockerdir/appdata/docker-compose.yml" up -d
echo "All set, everything should be running. If you have errors, follow the complete guid. And join our discord server."

exit 0
