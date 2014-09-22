#!/bin/bash

# @(#) Nom du script .. : restore.sh
# @(#) Version ........ : 1.00
# @(#) Date ........... : 19/09/2014
#      Auteurs ........ : Hardware

#~
#~ @(#) Description : Script de restauration

# --------------------------------------------------------------------
# Adresse email de reporting
REPORTING_EMAIL=

# Paramètres de connexion au serveur FTP
HOST=''
USER=''
PASSWD=''
PORT=
# --------------------------------------------------------------------

ERROR_FILE=./errors.log
FTP_FILE=./ftp.log
EXIT=0
ARCHIVE=""

# Définition des variables de couleurs
CSI="\033["
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CPURPLE="${CSI}1;35m"
CCYAN="${CSI}0;36m"

##################################################

sendErrorMail() {

SERVER_NAME=`hostname -s`

echo -e "Subject: ${SERVER_NAME^^} - Echec de la restauration
Une erreur est survenue lors de l'execution du script de restauration.
$2

Detail de l'erreur :
----------------------------------------------------------

`cat $1`

----------------------------------------------------------

INFO Serveur :

@IP : `hostname -i`
Hostname : `uname -n`
Kernel : `uname -r`
" > /tmp/reporting.txt

sendmail $REPORTING_EMAIL < /tmp/reporting.txt

}

downloadFromRemoteServer() {

    local archive=$1

    lftp -d -e "get $archive;get $archive.sig;get $archive.pub; bye" -u $USER,$PASSWD -p $PORT $HOST 2> $FTP_FILE > /dev/null

    FILES_TRANSFERRED=$(cat $FTP_FILE | grep -i "226\(-.*\)file successfully transferred" | wc -l)

    # On vérifie que les 3 fichiers ont bien été transférés
    if [[ $FILES_TRANSFERRED -ne 3 ]]; then
        echo -e "\n${CRED}/!\ ERREUR: Echec lors de la récupération de l'archive sur le serveur FTP${CEND}"
        echo ""
        exit 1
    fi

}

verifySignature() {

    local file=$1 out=

    FINGERPRINT=$(gpg --list-keys --fingerprint --with-colons | awk -F: '$1 == "fpr" {print $10;}' | head -n 1)

    # On vérifie l'intégrité du backup avec la clé de signature
    if out=$(gpg --status-fd 1 --verify "$file" 2> /dev/null) &&
    echo "$out" | grep -qs "^\[GNUPG:\] VALIDSIG $FINGERPRINT"; then
        echo "OK"
    fi

}

checkIntegrity() {

    # Importation de la clé publique
    echo ""
    echo -e "${CCYAN}-------------------------- CONFIGURATION DE GPG --------------------------${CEND}"

    gpg --import --batch --no-tty $ARCHIVE.pub

    echo -e "${CCYAN}--------------------------------------------------------------------------${CEND}"
    echo ""

    NB_ATTEMPT=1

    echo "> Vérification de l'intégrité"
    while [[ -z `verifySignature $ARCHIVE.sig` ]]; do
        if [ "$NB_ATTEMPT" -lt 4 ]; then
            echo -e "${CRED}/!\ ERREUR: Echec de la vérification de l'intégrité... Tentative $NB_ATTEMPT${CEND}"
            rm -rf $ARCHIVE $ARCHIVE.sig $ARCHIVE.pub
            downloadFromRemoteServer $ARCHIVE

            if [[ -n `verifySignature $ARCHIVE.sig` ]]; then
                break
            fi

            let "NB_ATTEMPT += 1"
            sleep 10
        else
            echo -e "${CRED}/!\ ERREUR: Echec lors de la vérification de l'intégrité de l'archive, signature incorrecte.${CEND}"
            exit 1
        fi
    done

}

backupList() {

    local backups=(/var/backup/local/backup-*)
    local i=0
    local n=""

    if [ ! -d /var/backup/local ]; then
        echo -e "\n${CRED}/!\ ERREUR: Aucune sauvegarde locale existante.${CEND}\n" 1>&2
        exit 1
    fi

    echo -e "\n Liste des archives disponibles :"

    for backup in ${backups[*]}; do
        let "i += 1"
        BACKUPPATH[$i]=$(stat -c "%n" $backup)
        echo "   $i. ${BACKUPPATH[$i]##*/}"
    done

    echo ""
    read -p "Saisir le numéro de l’archive à restaurer : " n

    if [[ $n -lt 1 ]] || [[ $n -gt $i ]]; then
        echo -e "\n${CRED}/!\ ERREUR: Numéro d'archive invalide !${CEND}"
        echo ""
        exit 1
    fi

    ARCHIVEPATH=${BACKUPPATH[$n]##*/} # backup-JJMMAAAA-HHMM
    ARCHIVE="$ARCHIVEPATH.tar.gz"
}

remoteRestoration() {

    echo -e "\n${CCYAN}Liste des archives disponibles :${CEND}"
    echo -e "${CCYAN}-----------------------------------------------------------------------------------------${CEND}"
    lftp -d -e "ls *.tar.gz; bye" -u $USER,$PASSWD -p $PORT $HOST 2> $FTP_FILE
    echo -e "${CCYAN}-----------------------------------------------------------------------------------------${CEND}"
    echo ""

    read -p "Veuillez saisir le nom de l'archive à récupérer : " ARCHIVE

    echo ""
    echo -e "${CRED}-------------------------------------------------------${CEND}"
    echo -e "${CRED} /!\ ATTENTION : RESTAURATION DU SERVEUR IMMINENTE /!\ ${CEND}"
    echo -e "${CRED}-------------------------------------------------------${CEND}"

    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour démarrer la restauration ou CTRL+C pour quitter..."
    read

    echo "> Récupération de l'archive depuis le serveur FTP"
    downloadFromRemoteServer $ARCHIVE

    checkIntegrity

}

localRestoration() {

    echo ""
    echo -e "${CRED}-------------------------------------------------------${CEND}"
    echo -e "${CRED} /!\ ATTENTION : RESTAURATION DU SERVEUR IMMINENTE /!\ ${CEND}"
    echo -e "${CRED}-------------------------------------------------------${CEND}"

    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour démarrer la restauration ou CTRL+C pour quitter..."
    read

    echo "> Récupération de l'archive locale"
    cp /var/backup/local/${ARCHIVEPATH}/*.tar.gz* .

    checkIntegrity

}

##################################################

if [[ $EUID -ne 0 ]]; then
    echo ""
    echo -e "${CRED}/!\ ERREUR: Vous devez être connecté en tant que root pour pouvoir exécuter ce script.${CEND}" 1>&2
    echo ""
    exit 1
fi

clear

echo ""
echo -e "${CCYAN}#########################################################${CEND}"
echo ""
echo -e "${CCYAN}          DEMARRAGE DU SCRIPT DE RESTAURATION            ${CEND}"
echo ""
echo -e "${CCYAN}#########################################################${CEND}"
echo ""

echo "Choisir le type de restauration :"
echo "  1. Distante"
echo "  2. Locale"
echo ""

while [[ $EXIT -eq 0 ]]; do

    read -p "Votre choix (1-2) : " RTYPE

    case "$RTYPE" in
    "1")
        echo -e "Type de restauration sélectionnée : ${CGREEN}Distante${CEND}"
        remoteRestoration
        EXIT=1
        ;;
    "2")
        echo -e "Type de restauration sélectionnée : ${CGREEN}Locale${CEND}"
        backupList
        localRestoration
        EXIT=1
        ;;
    *)
        echo -e "${CRED}Action inconnue${CEND}"
        ;;
    esac

done

echo "> Décompression de l'archive à la racine du système"
tar --warning=none -xpPzf $ARCHIVE -C / --numeric-owner 2> $ERROR_FILE

if [ -s $ERROR_FILE ]; then
    echo -e "\n${CRED}/!\ ERREUR: Echec de la décompression de l'archive.${CEND}"
    echo -e ""
    sendErrorMail $ERROR_FILE "Echec de la décompression de l'archive."
    exit 1
fi

# Si il s'agit d'une restauration complète, il faut mettre à jour l'UUID de la partition
# if [[ "$RTYPE" = "1" ]]; then

    # Récupération de l'UUID de la partition /boot
    # UUID=`blkid -s UUID -o value /dev/sda1` # sda1 = /boot

    # Mise à jour de l'UUID de la partition /boot dans le fichier fstab
    # echo -e "> Mise à jour du fichier ${CPURPLE}/etc/fstab${CEND}"
    # sed -i -e "s/\(UUID=\).*/\1$UUID \/boot ext4 defaults 1 2/" /etc/fstab

# fi

echo ""
echo -e "${CGREEN}> Restauration effectuée !${CEND}"

rm -rf $ARCHIVE
rm -rf $ARCHIVE.pub
rm -rf $ARCHIVE.sig
rm -rf $ERROR_FILE
rm -rf $FTP_FILE

echo ""
echo -e "${CYELLOW}-----------------------------------------${CEND}"
echo -e "${CYELLOW} Redémarrage du système dans 10 secondes ${CEND}"
echo -e "${CYELLOW}-----------------------------------------${CEND}"
echo ""
echo -ne '[                  ] 10s \r'
sleep 1
echo -ne '[+                 ] 9s \r'
sleep 1
echo -ne '[+ +               ] 8s \r'
sleep 1
echo -ne '[+ + +             ] 7s \r'
sleep 1
echo -ne '[+ + + +           ] 6s \r'
sleep 1
echo -ne '[+ + + + +         ] 5s \r'
sleep 1
echo -ne '[+ + + + + +       ] 4s \r'
sleep 1
echo -ne '[+ + + + + + +     ] 3s \r'
sleep 1
echo -ne '[+ + + + + + + +   ] 2s \r'
sleep 1
echo -ne '[+ + + + + + + + + ] 1s \r'
sleep 1
echo -ne '[+ + + + + + + + + +] Redémarrage... \r'
echo -ne '\n'

shutdown -r now
