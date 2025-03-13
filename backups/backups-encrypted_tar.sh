#!/bin/bash
#admins@remote-admins.com

SRC_DIR='{YOUR DIRECTORY WITH FILES FOR BACKUP. USE FULL PATH}'
DST_DIR='{FULL PATH OF YOUR BACKUPS DIRECTORY, where tarballs backups are located}'
SALT='your_super-duper-megahard_encryption-string'
host=$(hostname -s)
today_folder="$(date +%Y.%m.%d)"

tar=`which tar` || { echo "Failed to find tar"; exit 1; }
openssl=`which openssl` || { echo "Failed to find openssl"; exit 1; }
pigz=`which pigz` || { echo "Failed to find pigz"; exit 1; }
mkdir=`which mkdir` || { echo "Failed to find mkdir"; exit 1; }

# Timestamp for unique tarball and encrypted file names
TIMESTAMP=$(date +%Y%m%d%H%M%S)
[ ! -d "$DST_DIR/$today_folder" ] && $mkdir $DST_DIR/$today_folder || { echo "Failed to create directory $today_folder"; exit 1; }
DST_DIR=$DST_DIR/$today_folder

# Create TARBALL
TARBALL="backup_$(basename $SRC_DIR)_$TIMESTAMP.tar.gz"
$tar --use-compress-program="pigz -p 24 -5" -cf $DST_DIR/$TARBALL $SRC_DIR || { echo "Failed to create tarball"; exit 1; }

# Encrypt the tarball using openssl
ENCRYPTED_TARBALL="$DST_DIR/$TARBALL.enc"
$openssl enc -aes-256-cbc -salt -in "$DST_DIR/$TARBALL" -out "$ENCRYPTED_TARBALL" -k "$SALT" -pbkdf2 || { echo "Encryption failed"; exit 1; }

# Verify if the encryption was successful then remove the tarball
if [ $? -eq 0 ]; then
  rm "$DST_DIR/$TARBALL" || { echo "Failed to remove tarball"; exit 1; }
  echo "Backup and encryption completed successfully."
else
  echo "Error during encryption process."
  exit 1
fi
