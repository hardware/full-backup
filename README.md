Scripts de sauvegarde/restauration
==================================

Pour plus de détail, allez voir ce topic : http://mondedie.fr/viewtopic.php?pid=13088

### Installation

```bash
apt-get update && apt-get dist-upgrade
apt-get install git-core
```

```bash
cd /opt
git clone https://github.com/hardware/full-backup.git
cd full-backup
chmod +x *.sh && ./install.sh
```

### Mise à jour

**ATTENTION** : Pensez à mettre à jour les scripts régulièrement avec la commande suivante (Ne faites pas un simple git pull sinon vous allez devoir refaire l'installation...) :

```bash
cd /opt/full-backup && git stash && git pull && git stash pop
```

### Support

Si vous avez une question, une remarque ou une suggestion, n'hésitez pas à poster un commentaire sur ce topic : http://mondedie.fr/viewtopic.php?pid=13088

### License
MIT. Voir le fichier ``LICENCE`` pour plus de détails
