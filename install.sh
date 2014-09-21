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

if [[ $EUID -ne 0 ]]; then
   echo -e "${CRED}/!\ ERREUR: Vous devez être connecté en tant que root pour pouvoir exécuter ce script.${CEND}" 1>&2
   echo ""
   exit 1
fi

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

clear

echo ""
echo -e "${CCYAN}    Configuration du script de sauvegarde ${CEND}"
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

echo -e "${CGREEN}-> Installation de LFTP et rng-tools ${CEND}"
echo ""

apt-get install -y lftp rng-tools

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
    read -p "Veuillez saisir l'adresse du serveur ftp : " HOST
    read -p "Veuillez saisir le nom d'utilisateur : " USER
    read -sp "Veuillez saisir le mot de passe" PASSWD
    read -p "Veuillez saisir le numéro du port [Par défaut: 21] : " PORT
}

getCredentials

if [ "$PORT" = "" ]; then
    PORT=21
fi

echo "set ssl:verify-certificate false" >> ~/.lftprc

echo -n "> Test de connexion au serveur FTP..."
until lftp -d -e "ls; bye" -u $USER,$PASSWD -p $PORT $HOST 2> $FTP_FILE
do
    cat $FTP_FILE | grep -i "150\(.*\)accepted data connection"

    if [ $? -eq 0 ]; then
        break
    fi

    echo ""
    echo -e "${CRED}/!\ Erreur: Un problème est survenu lors de la connexion au serveur FTP.${CEND}" 1>&2
    echo -e "${CRED}/!\ Erreur: Merci de re-saisir les paramètres de connexion.${CEND}" 1>&2
    getCredentials
    echo ""
done
echo -e " ${CGREEN}Connexion [OK]${CEND}"

read -p "Veuillez saisir votre adresse email : " EMAIL

# On échappe les caractères spéciaux dans l'URL
HOST_ESCP=$(echo $HOST | sed -e 's/[]\/$*.^|[]/\\&/g')

echo "Ajout des paramètres de connexion au serveur FTP"
sed -i -e "s/\(HOST=\).*/\1'$HOST_ESCP'/" \
       -e "s/\(USER=\).*/\1'$USER'/"      \
       -e "s/\(PASSWD=\).*/\1'$PASSWD'/"  \
       -e "s/\(PORT=\).*/\1'$PORT'/" backup.sh restore.sh

# Ajout de l'adresse email de reporting
sed -i "s/\(REPORTING_EMAIL=\).*/\1$EMAIL/" backup.sh restore.sh

smallLoader
clear

echo -e "${CCYAN}---------------------------------------${CEND}"
echo -e "${CCYAN}[  EXCLUSION DE FICHIERS/RÉPERTOIRES  ]${CEND}"
echo -e "${CCYAN}---------------------------------------${CEND}"
echo ""

read -p "Voulez-vous exclure des répertoires de la sauvegarde ? (o/n) : " EXCLUDE

if [[ "$EXCLUDE" = "o" ]] || [[ "$EXCLUDE" = "O" ]]; then

    echo -e "Entrez ${CPURPLE}STOP${CEND} pour arrêter la saisie."

    while :
    do
        read -p "Veuillez saisir le chemin à exclure : " EXCLUDEPATH

        if [[ "$EXCLUDEPATH" = "STOP" ]]; then
            break
        fi

        echo "$EXCLUDEPATH" >> .excluded-files
    done

    echo "Les répertoires/fichiers suivants ne seront pas inclus dans la sauvegarde :"
    echo -e "${CGREEN}--------------------------------------------------------${CEND}"
    cat .excluded-files
    echo -e "${CGREEN}--------------------------------------------------------${CEND}"
    echo ""

fi

smallLoader
clear

echo -e "${CGREEN}-> Démarrage de RNG-TOOLS.${CEND}"
service rng-tools start

echo -e "${CCYAN}-----------------${CEND}"
echo -e "${CCYAN}[ FIN DU SCRIPT ]${CEND}"
echo -e "${CCYAN}-----------------${CEND}"

exit 0
