#!/bin/bash
#admins@remote-admins.com


### Backups retention policies ###
daily_keep_last="31"   # Keep last 31 daily  backup files created ( 1 backup per 1 day )
weekly_keep_last="52"  # Keep last 52 weekly backup files created ( 1 backup per 1 week )
monthly_keep_last="60" # Keep last 60 montly backup files created ( 1 backup per 1 month )

if [ -z "$1" ]; then
  echo "Error: No argument provided. Please use the syntrax: $0 database_name"
  exit 1
fi

archive_name="$1"

bucket="{YOUR_BUCKET_NAME}"
backups_dir="{YOUR_BACKUPS_DIR_FULL_PATH}"
today=$(date +%Y-%m-%d)
host=$(hostname -s)
today_folder="$(date +%Y.%m.%d)"
last_day_of_month=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%Y.%m.%d)

# UPLOADING to S3 ###
#upload today's daily backups
echo "Copy backups to s3 daily path"
aws s3 sync $backups_dir/$today_folder s3://$bucket/daily/$today_folder/$host 1>/dev/null

# Check if today is the last day of the month and upload daily backup to s3 if yes
if [ "$today" == "$last_day_of_month" ]; then
	echo "Today is the last day of the month.... Copy backups to monthly path"
	aws s3 cp s3://$bucket/daily/$today_folder/$host/ s3://$bucket/monthly/$today_folder/$host --recursive 1>/dev/null
fi

# Check if today is the last day of the week and upload daily backup to s3 if yes
if [ "$(date +%u)" -eq "7" ]; then
	echo "Today is Sunday.... Copy backups to weekly path"
	aws s3 cp s3://$bucket/daily/$today_folder s3://$bucket/weekly/$today_folder --recursive 1>/dev/null
fi

# DELETE OLDEST from S3 ###

#Clean Daily backups
echo "Cleaning daily backups older than $daily_keep_last num of files"
for key in $(aws s3api list-objects-v2 --bucket $bucket --query "reverse(sort_by(Contents[?contains(Key, '${archive_name}') && contains(Key, '${host}') && contains(Key, 'sql.gz.enc') && starts_with(Key, 'name') == \`false\`], &LastModified))[${daily_keep_last}:].Key" --prefix "daily" --output text); do
	echo aws s3 rm s3://${bucket}/${key}
done

#Clean Weekly backups
echo "Cleaning weekly backups older than $weekly_keep_last num of files"
aws s3api list-objects-v2 --bucket $bucket --query "reverse(sort_by(Contents[?contains(Key, '${archive_name}') && contains(Key, 'sql.gz.enc') && starts_with(Key, 'name') == \`false\`], &LastModified))[${weekly_keep_last}:].Key" --prefix "weekly" --output text|
while read -r key; do
        aws s3 rm s3://${bucket}/${key}
done

#Clean Monthly backups
echo "Cleaning monthly backups older than $monthly_keep_last num of files"
aws s3api list-objects-v2 --bucket $bucket --query "reverse(sort_by(Contents[?contains(Key, '${archive_name}') && contains(Key, 'sql.gz.enc') && starts_with(Key, 'name') == \`false\`], &LastModified))[${monthly_keep_last}:].Key" --prefix "monthly" --output text|
while read -r key; do
        aws s3 rm s3://${bucket}/${key}
done

#Clean local backups
echo "Cleaning local backups dirs, keeping last 15"
find $BACKUP_DIRECTORY_FULL_PATH -type d -printf "%T@ %p\n"|sort -n|head -n -16|awk '{print $2}'|while read -r dir; do rm -rf "$dir";done
echo "Cleaning Finished..."

echo S3 Bucket: $bucket usage Info:

for a in daily weekly monthly;
 do
	echo RAW TOTAL Usage for $a PREFIX: $(aws s3 ls $bucket/$a/  --recursive --summarize --human-readable |tail -2|tr -d '\n')
 done
	echo --------------------
for a in daily weekly monthly;
 do
	let size=$(aws s3api list-objects --bucket $bucket --query "Contents[?contains(Key, '${host}')].[Size]" --output text |  awk '{sum+=$1} END {print sum}')/1024/1024
        echo RAW host: $host Usage for $a PREFIX: $size Mbytes
 done
