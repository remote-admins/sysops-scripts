#!/bin/bash
#admins@remote-admins.com

SRC_DIR='{YOUR DIRECTORY WITH FILES FOR BACKUP. USE FULL PATH}'
DST_DIR='{FULL PATH OF YOUR BACKUPS DIRECTORY, where tarballs backups are located}'
SALT='your_super-duper-megahard_encryption-string'

tar=`which tar`
openssl=`which openssl`
pigz=`which pigz`

# Timestamp for unique tarball and encrypted file names
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Create the tarball with pigz compression using 8 parallel processes
TARBALL="$DST_DIR/backup_$TIMESTAMP.tar.gz"
$tar -cf - "$SRC_DIR" | $pigz -p 8 > "$TARBALL"

# Encrypt the tarball using openssl
ENCRYPTED_TARBALL="$DST_DIR/backup_$TIMESTAMP.tar.gz.enc"
$openssl enc -aes-256-cbc -salt -in "$TARBALL" -out "$ENCRYPTED_TARBALL" -k "$SALT"

# Verify if the encryption was successful then remove the tarball
if [ $? -eq 0 ]; then
  rm "$TARBALL"
  echo "Backup and encryption completed successfully."
else
  echo "Error during encryption process."
  exit 1
fi

