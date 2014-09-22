#!/bin/bash

# @(#) Nom du script .. : backup.sh
# @(#) Version ........ : 1.00
# @(#) Date ........... : 19/09/2014
#      Auteurs ........ : Hardware

ERROR_FILE=./errors.log
FTP_FILE=./ftp.log
EXIT=0

CSI="\033["
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CPURPLE="${CSI}1;35m"
CCYAN="${CSI}1;36m"
CBROWN="${CSI}0;33m"

# ##########################################################################

smallLoader() {
    echo ""
    echo ""
    echo -ne '[ + + +             ] 3s \r'
    sleep 1
    echo -ne '[ + + + + + +       ] 2s \r'
    sleep 1
    echo -ne '[ + + + + + + + + + ] 1s \r'
    sleep 1
    echo -ne '[ + + + + + + + + + ] Appuyez sur [ENTRÉE] pour continuer... \r'
    echo -ne '\n'

    read
}

# ##########################################################################

if [[ $EUID -ne 0 ]]; then
    echo ""
    echo -e "${CRED}/!\ ERREUR: Vous devez être connecté en tant que root pour pouvoir exécuter ce script.${CEND}" 1>&2
    echo ""
    exit 1
fi

clear

echo ""
echo -e "${CCYAN}                          Configuration du script de sauvegarde ${CEND}"
echo ""
echo -e "${CCYAN}
███╗   ███╗ ██████╗ ███╗   ██╗██████╗ ███████╗██████╗ ██╗███████╗   ███████╗██████╗
████╗ ████║██╔═══██╗████╗  ██║██╔══██╗██╔════╝██╔══██╗██║██╔════╝   ██╔════╝██╔══██╗
██╔████╔██║██║   ██║██╔██╗ ██║██║  ██║█████╗  ██║  ██║██║█████╗     █████╗  ██████╔╝
██║╚██╔╝██║██║   ██║██║╚██╗██║██║  ██║██╔══╝  ██║  ██║██║██╔══╝     ██╔══╝  ██╔══██╗
██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██████╔╝███████╗██████╔╝██║███████╗██╗██║     ██║  ██║
╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═════╝ ╚═╝╚══════╝╚═╝╚═╝     ╚═╝  ╚═╝

${CEND}"
echo ""

echo ""
echo -e "${CCYAN}---------------------------------${CEND}"
echo -e "${CCYAN}[  INSTALLATION DES PRÉ-REQUIS  ]${CEND}"
echo -e "${CCYAN}---------------------------------${CEND}"
echo ""

echo -e "${CGREEN}-> Installation de LFTP, GnuPG et rng-tools ${CEND}"
echo ""

apt-get install -y lftp gnupg rng-tools

if [ $? -ne 0 ]; then
    echo ""
    echo -e "\n ${CRED}/!\ FATAL: Une erreur est survenue pendant l'installation des pré-requis.${CEND}" 1>&2
    echo ""
    exit 1
fi

smallLoader
clear

echo -e "${CCYAN}---------------------------------${CEND}"
echo -e "${CCYAN}[  PARAMÈTRES DE CONNEXION FTP  ]${CEND}"
echo -e "${CCYAN}---------------------------------${CEND}"
echo ""

getCredentials() {

    read -p "> Veuillez saisir l'adresse du serveur ftp : " HOST
    read -p "> Veuillez saisir le numéro du port [Par défaut: 21] : " PORT
    read -p "> Veuillez saisir le nom d'utilisateur : " USER
    read -sp "> Veuillez saisir le mot de passe : " PASSWD

    if [ "$PORT" = "" ]; then
        PORT=21
    fi

    echo -e "\n\nParamètres de connexion :"
    echo -e "- Adresse du serveur : ${CPURPLE}$HOST${CEND}"
    echo -e "- Nom d'utilisateur : ${CPURPLE}$USER${CEND}"
    echo -e "- Port : ${CPURPLE}$PORT${CEND}"
}

getCredentials

echo "set ssl:verify-certificate false" >> ~/.lftprc

echo -e ""
echo -n "Test de connexion en cours..."

until lftp -d -e "ls; bye" -u $USER,$PASSWD -p $PORT $HOST 2> $FTP_FILE > /dev/null
do
    cat $FTP_FILE | grep -i "150\(.*\)accepted data connection"

    if [ $? -eq 0 ]; then
        break
    fi

    echo ""
    echo -e "${CRED}/!\ Erreur: Un problème est survenu lors de la connexion au serveur FTP.${CEND}" 1>&2
    echo -e "${CRED}/!\ Erreur: Merci de re-saisir les paramètres de connexion.${CEND}" 1>&2
    echo ""
    getCredentials
    echo ""
done
echo -e " ${CGREEN}Connexion au serveur FTP [OK]${CEND}"

echo ""
read -p "> Veuillez saisir votre adresse email : " EMAIL
read -p "> Combien d'archives voulez-vous garder au maximum ? [Par défaut: 10] " NBACKUPS

if [ "$NBACKUPS" = "" ]; then
    NBACKUPS=10
fi

# On échappe les caractères spéciaux dans l'URL
HOST_ESCP=$(echo $HOST | sed -e 's/[]\/$*.^|[]/\\&/g')

echo ""
echo -n "Ajout des paramètres de connexion au serveur FTP"
sed -i -e "s/\(HOST=\).*/\1'$HOST_ESCP'/" \
       -e "s/\(USER=\).*/\1'$USER'/"      \
       -e "s/\(PASSWD=\).*/\1'$PASSWD'/"  \
       -e "s/\(PORT=\).*/\1$PORT/"        \
       -e "s/\(NB_MAX_BACKUP=\).*/\1$NBACKUPS/" backup.sh restore.sh

# Ajout de l'adresse email de reporting
sed -i "s/\(REPORTING_EMAIL=\).*/\1$EMAIL/" backup.sh restore.sh
echo -e " ${CGREEN}[OK]${CEND}"

smallLoader
clear

echo -e "${CCYAN}---------------------------------------${CEND}"
echo -e "${CCYAN}[  EXCLUSION DE FICHIERS/RÉPERTOIRES  ]${CEND}"
echo -e "${CCYAN}---------------------------------------${CEND}"
echo ""

read -p "Voulez-vous exclure des répertoires de la sauvegarde ? (o/n) : " EXCLUDE

if [[ "$EXCLUDE" = "o" ]] || [[ "$EXCLUDE" = "O" ]]; then

    # Exclusion des répertoires par défaut
    echo "/var/cache" >> .excluded-paths
    echo "/var/backup" >> .excluded-paths

    echo -e "\nEntrez ${CPURPLE}STOP${CEND} pour arrêter la saisie.\n"

    while :
    do
        read -p "Veuillez saisir le chemin à exclure : " EXCLUDEPATH

        if [[ "$EXCLUDEPATH" = "STOP" ]] || [[ "$EXCLUDEPATH" = "stop" ]]; then
            break
        fi

        if [ "$EXCLUDEPATH" = "" ]; then
            continue
        fi

        echo "$EXCLUDEPATH" >> .excluded-paths
    done

    echo -e "\nLes répertoires/fichiers suivants ne seront pas inclus dans la sauvegarde :\n"
    echo -e "${CGREEN}-----------------EXCLUSION--------------------${CEND}"
    cat .excluded-paths
    echo -e "${CGREEN}----------------------------------------------${CEND}"

fi

smallLoader
clear

echo -e "${CCYAN}---------------${CEND}"
echo -e "${CCYAN}[  RNG TOOLS  ]${CEND}"
echo -e "${CCYAN}---------------${CEND}"
echo ""

echo -e "${CGREEN}-> Configuration de RNG-TOOLS.${CEND}"
echo "Device: /dev/urandom"
cat > /etc/default/rng-tools <<EOF
HRNGDEVICE=/dev/urandom
RNGDOPTIONS="-W 80% -t 20"
EOF

echo ""
echo -e "${CGREEN}-> Démarrage de RNG-TOOLS.${CEND}"
service rng-tools start

echo ""
echo -e "${CCYAN}-------------------------------------${CEND}"
echo -e "${CCYAN}[  CREATION D'UNE PAIRE DE CLE GPG  ]${CEND}"
echo -e "${CCYAN}-------------------------------------${CEND}"
echo ""

read -p "Voulez-vous créer une nouvelle paire de clé GPG ? (o/n) : " CREATEKEY

if [[ "$CREATEKEY" = "o" ]] || [[ "$CREATEKEY" = "O" ]]; then

    echo -e "${CCYAN}--------------------------------------------------------------------------${CEND}"
    gpg --gen-key

    if [ $? -eq 0 ]; then
        echo -e "\n${CGREEN}Vos clés GPG ont été générées avec succès !${CEND}\n"
        gpg --list-keys --with-fingerprint
    else
        echo -e "\n${CRED}/!\ Erreur: Une erreur est survenue pendant la création de vos clés GPG.${CEND}\n" 1>&2
    fi
fi

read -sp "> Veuillez saisir le mot de passe de votre clé privée : " GPGPASSWD

echo -e "\n"
echo -n "Création du fichier .gpg-passwd"
echo "$GPGPASSWD" > .gpg-passwd
chmod 600 .gpg-passwd
echo -e " ${CGREEN}[OK]${CEND}"

echo ""
echo -e "${CCYAN}-----------------${CEND}"
echo -e "${CCYAN}[ FIN DU SCRIPT ]${CEND}"
echo -e "${CCYAN}-----------------${CEND}"

exit 0
