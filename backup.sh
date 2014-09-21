#!/bin/bash

# @(#) Nom du script .. : backup.sh
# @(#) Version ........ : 1.00
# @(#) Date ........... : 19/09/2014
#      Auteurs ........ : Hardware

#~
#~ @(#) Description : Script de sauvegarde d'un système sous linux

# --------------------------------------------------------------------
# Adresse email de reporting
REPORTING_EMAIL=

# Paramètres de connexion au serveur FTP
HOST=''
USER=''
PASSWD=''
PORT=
# --------------------------------------------------------------------

CDAY=$(date +%d%m%Y-%H%M)
NB_MAX_BACKUP=10
BACKUP_PARTITION=/var/backup/local
BACKUP_FOLDER=$BACKUP_PARTITION/backup-$CDAY
ERROR_FILE=$BACKUP_FOLDER/errors.log
FTP_FILE=$BACKUP_FOLDER/ftp.log
ARCHIVE=$BACKUP_FOLDER/backup-$CDAY.tar.gz
LOG_FILE=/var/log/backup.log

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

# Upload de l'archive sur un serveur distant
uploadToRemoteServer() {

# La commande ftp n'est pas compatible avec SSL/TLS donc on utilise lftp à la place
lftp -d -e "lcd $BACKUP_FOLDER;put backup-$CDAY.tar.gz;put backup-$CDAY.tar.gz.sig;put backup-$CDAY.tar.gz.pub; bye" -u $USER,$PASSWD -p $PORT $HOST 2> $FTP_FILE > /dev/null

FILES_TRANSFERRED=$(cat $FTP_FILE | grep -i "226\(-.*\)file successfully transferred" | wc -l)

# On vérifie que les 3 fichiers ont bien été transférés
if [[ $FILES_TRANSFERRED -eq 3 ]]; then
    echo "OK"
fi

}

sendErrorMail() {

SERVER_NAME=`hostname -s`

echo -e "Subject: ${SERVER_NAME^^} - Echec de la sauvegarde
Une erreur est survenue lors de l'execution du script de sauvegarde.
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

##################################################

echo "" | tee -a $LOG_FILE
echo -e "${CCYAN}###################################################${CEND}" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo -e "${CCYAN}          DEMARRAGE DU SCRIPT DE BACKUP            ${CEND}" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo -e "${CCYAN}###################################################${CEND}" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [[ $EUID -ne 0 ]]; then
   echo -e "${CRED}/!\ ERREUR: Vous devez être connecté en tant que root pour pouvoir exécuter ce script.${CEND}" 1>&2
   echo ""
   exit 1
fi

if [ ! -d $MONITORING_FOLDER ]; then
    mkdir -p $BACKUP_PARTITION > /dev/null 2>&1
fi

if [ -e $BACKUP_FOLDER ]; then
    rm -rf $BACKUP_FOLDER
fi

mkdir $BACKUP_FOLDER

# On vérifie que le fichier .excluded-files existe bien
if [ ! -f .excluded-files ]; then
    echo -e "\n${CRED}/!\ ERREUR: Le fichier${CEND} ${CPURPLE}.excluded-files${CEND} ${CRED}n'existe pas !${CEND}" | tee -a $LOG_FILE
    echo -e "" | tee -a $LOG_FILE
    exit 1
fi

echo -n "> Compression des fichiers système" | tee -a $LOG_FILE
tar --warning=none -cpPzf $ARCHIVE --one-file-system --exclude-from=.excluded-files / /var /home 2> $ERROR_FILE

# Si une erreur survient lors de la compression
if [ -s $ERROR_FILE ]; then
    echo -e "\n${CRED}/!\ ERREUR: Echec de la compression des fichiers système.${CEND}" | tee -a $LOG_FILE
    echo -e "" | tee -a $LOG_FILE
    sendErrorMail $ERROR_FILE "Echec de la compression des fichiers systeme."
    exit 1
fi

echo -e " ${CGREEN}[OK]${CEND}" | tee -a $LOG_FILE

# On vérifie que le fichier .gpg-passwd existe bien
if [ ! -f .gpg-passwd ]; then
    echo -e "\n${CRED}/!\ ERREUR: Le fichier${CEND} ${CPURPLE}.gpg-passwd${CEND} ${CRED}n'existe pas !${CEND}" | tee -a $LOG_FILE
    echo -e "" | tee -a $LOG_FILE
    exit 1
fi

gpg --export --armor 2>&1 > /dev/null | fgrep -q "WARNING: nothing exported"

# On vérifie que la paire de clé publique / clé privée a bien créée
if [ $? -eq 0 ]; then
    echo -e "\n${CRED}/!\ ERREUR: Aucune clé publique n'a été détectée !${CEND}" | tee -a $LOG_FILE
    echo -e "${CRED}/!\ Exécuter la commande suivante pour en créer une :${CEND}" | tee -a $LOG_FILE
    echo "-> gpg --gen-key" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    exit 1
fi

echo -n "> Création de la signature de l'archive" | tee -a $LOG_FILE
# Exportation de la clé publique
gpg --export --armor > $ARCHIVE.pub
# Création de la signature
gpg --yes --batch --no-tty --passphrase-file=.gpg-passwd --detach-sign $ARCHIVE

echo -e " ${CGREEN}[OK]${CEND}" | tee -a $LOG_FILE

NB_ATTEMPT=1

echo -n "> Transfert de l'archive vers le serveur distant" | tee -a $LOG_FILE
while [[ -z `uploadToRemoteServer` ]]; do
    if [ "$NB_ATTEMPT" -lt 4 ]; then
        echo -e "\n${CRED}/!\ ERREUR: Echec du transfert... Tentative $NB_ATTEMPT${CEND}" | tee -a $LOG_FILE
        let "NB_ATTEMPT += 1"
        sleep 10
    else
        echo -e "\n${CRED}/!\ ERREUR: Echec du transfert de l'archive vers le serveur distant.${CEND}" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        sendErrorMail $FTP_FILE "Echec du transfert de l'archive vers le serveur distant."
        exit 1
    fi
done
echo -e " ${CGREEN}[OK]${CEND}" | tee -a $LOG_FILE

# Retrouve le nombre de sauvegardes effectuées
nbBackup=$(find $BACKUP_PARTITION -type d -name 'backup-*' | wc -l)

if [ $nbBackup -gt $NB_MAX_BACKUP ]; then

    echo -n "> Suppression de l'archive la plus ancienne" | tee -a $LOG_FILE

    # Recherche l'archive la plus ancienne
    oldestBackupPath=$(find $BACKUP_PARTITION -type d -name 'backup-*' -printf '%T+ %p\n' | sort | head -n 1)
    oldestBackupFile=$(find $BACKUP_PARTITION -type d -name 'backup-*' -printf '%T+ %p\n' | sort | head -n 1 | awk '{split($0,a,/\//); print a[4]}')

    # Supprime le répertoire du backup
    rm -rf $oldestBackupPath

    # Supprime l'archiven du fichier de signature et de la clé publique sur le serveur FTP
    lftp -e "rm $oldestBackupFile.tar.gz;bye"     -u $USER,$PASSWD -p $PORT $HOST > /dev/null 2>&1
    lftp -e "rm $oldestBackupFile.tar.gz.sig;bye" -u $USER,$PASSWD -p $PORT $HOST > /dev/null 2>&1
    lftp -e "rm $oldestBackupFile.tar.gz.pub;bye" -u $USER,$PASSWD -p $PORT $HOST > /dev/null 2>&1

    echo -e " ${CGREEN}[OK]${CEND}" | tee -a $LOG_FILE
fi

echo -e "${CGREEN}> Sauvegarde terminée avec succès !${CEND}" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit 0
