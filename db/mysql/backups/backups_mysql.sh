#!/bin/bash
# MYSQL BACKUP SCRIPT with enough free space check
#sto@remote-admins.com
#admins@remote-admins.com

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <database_name>"
    exit 1
fi

db_name=$1

db_host="localhost"
db_user="$DB_USER"
db_pass="$DB_PASS"
dump_enc_pass="$ENCRYPTION_PASS"
openssl_opts="-AES-256-CBC -pbkdf2 -salt"
backup_dir="$BACKUP_DIRECTORY_FULL_PATH"  #/data/backups/$(date +"%Y.%m.%d")"
current_time=$(date +"%Y.%m.%d.%H.%M")
backup_file="${backup_dir}/${db_name}-${current_time}.sql.gz.enc"
log_file="${backup_dir}/${db_name}-${current_time}-backup.log"
required_space_percentage=5    # check for free space: $actual_db_size + required_space_percentage < $free_disk_space = True; then execute backups; else exit

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" | tee -a "$log_file"
}

if [ -f "$log_file" ]; then
  touch "$log_file"
fi
# Check if database name is provided
if [ -z "$db_name" ]; then
  log "Error: No database name provided."
  exit 1
fi
# Check and create if backup directory not exists
if [ ! -d "$backup_dir" ]; then
  mkdir -p "$backup_dir" || exit 1
  log "Backup directory $backup_dir created"
else
  log "Backup directory exists.. Checking mysql login credentials for $db_user to $db_name"
fi
# Check MySQL login
mysql -h "$db_host" -u "$db_user" -p"$db_pass" -e "exit" 2>/dev/null
if [ $? -ne 0 ]; then
  log "Error: Cannot login to MySQL with provided credentials."
  exit 1
else
  log "MySQL login for $db_user to $db_name successfull.. Checking backupfile path to ensure not overwriting."
fi
# Check if backup file already exists
if [ -f "$backup_file" ]; then
  log "Error: Backup file $backup_file already exists."
  exit 1
else
  log "Backup file not exists in the backup path.... Checking for enough free space on $backup_dir partition."
fi

# check free space: Calculate required disk space
db_size=$(mysql -h "$db_host" -u "$db_user" -p"$db_pass" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.tables WHERE table_schema = '$db_name';" -s -N 2>>"$log_file")
available_space=$(df "$backup_dir" | awk 'NR==2 {print $4}')
required_space=$(echo "$db_size * (1 + $required_space_percentage / 100)" | bc)
available_space_mb=$(echo "$available_space / 1024" | bc)
if (( $(echo "$available_space_mb < $required_space" | bc -l) )); then
  log "Error: Not enough disk space available. Required: ${required_space}MB, Available: ${available_space_mb}MB."
  exit 1
else
 log "All checks are OK. Dumping mysql database: $db_name (mysql raw data size: $db_size MB) to gzip and openssl into file: $backup_file"
fi

# mysqldump
log "Starting backup of database $db_name."
mysqldump --single-transaction --routines --triggers --events --master-data=2 -h "$db_host" -u "$db_user" -p"$db_pass" "$db_name" 2>>"$log_file" | pigz -p 8 2>>"$log_file" | openssl enc $openssl_opts -pass pass:$dump_enc_pass -out "$backup_file" 2>>"$log_file"

if [ $? -eq 0 ]; then
  log "Backup completed successfully."
else
  log "Error: Backup failed."
  exit 1
fi
