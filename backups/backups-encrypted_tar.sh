#!/bin/bash
#admins@remote-admins.com

SRC_DIR='{YOUR DIRECTORY WITH FILES FOR BACKUP. USE FULL PATH}'
DST_DIR='{FULL PATH OF YOUR BACKUPS DIRECTORY, where tarballs backups are located}'
SALT='your_super-duper-megahard_encryption-string'
host=$(hostname -s)
today_folder="$(date +%Y.%m.%d)"

tar=`which tar`
openssl=`which openssl`
pigz=`which pigz`
mkdir=`which mkdir`

# Timestamp for unique tarball and encrypted file names
TIMESTAMP=$(date +%Y%m%d%H%M%S)
[ ! -d "$DST_DIR/$today_folder" ] && $mkdir $DST_DIR/$today_folder
DST_DIR=$DST_DIR/$today_folder

#Create TARBALL
TARBALL="$DST_DIR/backup_$(basename $SRC_DIR)_$TIMESTAMP.tar.gz"
$tar --use-compress-program="pigz -p 24 -6" -cf $TARBALL $SRC_DIR

# Encrypt the tarball using openssl
ENCRYPTED_TARBALL="$DST_DIR/$TARBALL.tar.gz.enc"
$openssl enc -aes-256-cbc -salt -in "$TARBALL" -out "$ENCRYPTED_TARBALL" -k "$SALT" -pbkdf2

# Verify if the encryption was successful then remove the tarball
if [ $? -eq 0 ]; then
  rm "$TARBALL"
  echo "Backup and encryption completed successfully."
else
  echo "Error during encryption process."
  exit 1
fi
