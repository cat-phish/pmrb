#!/bin/bash
################################################################################
# Script Name: pmrb.sh (Podcast Manager for Rockbox)
# Description: A utility to sync podcasts to a playback device with the goal of
#              emulating the functionality of a modern podcast app.
#              Features:
#                 * Automatic queuing of new episodes in the order that they
#                   were downloaded.
#                 * Decide which podcasts to auto-queue and which don't.
#                 * Auto cleanup of old episodes based on a specified age and
#                   file modified time.
#                 * Auto cleanup of the Queue based on the most recent
#                   bookmark.
#                 * Auto mount and unmount of the device.
#              WARNING - This script deletes source files when syncing. It is
#              recommended to run a separate docker container or instance for
#              your podcast downloading utility if you are already using one for
#              other purposes.
# Author: cat-phish
# Date: 2024-10-23
# Usage: Dependencies - udisks2, rsync, ssh (if remote sync is enabled)
#        Also Required - A podcast downloading utility like Gpodder
#                        (recommended) or Podgrab, and a Rockbox device.
#        1) Set the configuration options and optionally remote configuration
#           options to match your setup
#        2) If using remote sync setup ssh passwordless login
#           (https://www.tecmint.com/ssh-passwordless-login-using-ssh-keygen-in-5-easy-steps/)
#        3) Recommended Rockbox settings
#           a) Settings > General Settings > Bookmarks > Bookmark on Stop > Ask
#              (or Yes, but Yes will create bookmarks for non-podcasts)
#           b) Settings > General Settings > Bookmarks > Update on Stop > Yes
#        4) Manually run script or use cron jobs or systemd timers to automate
################################################################################

### CONFIGURATION ###

# Set the podcast path
# (No trailing slash!)
source_podcast_path="/path/to/your/source/podcasts"

# Set the device path you would like to sync your podcasts to (e.g. /Podcasts/Shows)
# It is recommended to use a separate folder for permenantly stored podcasts (e.g. /Podcasts/Archive)
# especially when using auto-cleanup
# (No trailing slash!)
device_sync_path="/Podcasts/Shows"

# Set the location you would like to sync your Queue.m3u8 to)
# (No trailing slash!)
device_queue_location="/Podcasts"

# Set the max age for auto-cleanup in days, 0 to disable (based on file modified time)
max_age=180

# Auto clean the Queue.m3u8 file based on the most recent bookmark from Queue.m3u8.bmark
auto_clean_queue="yes"

# Define the array of podcasts to auto queue (this should match case-sensitive to the folder names of each podcast)
auto_queue_shows=("Example Podcast 1" "Example Podcast 2" "Example Podcast 3")

# UUID (use "lsblk -f"" to find the UUID of the device)
uuid="0000-000A"

# Amount of time to sleep in seconds after mounting the drive in seconds
# (workaround for slow mounting of some devices while using Rockbox file transfer)
sleep_time=120

# Append podcast name to end of the episode file name? (yes or no)
# Podgrab does not add the podcast name to the episode file name, which can cause some
# confusion when viewing the queue
append_podcast_name="yes"

### REMOTE SYNC CONFIGURATION ###

# Remote Sync? (yes or no)
remote_sync="yes"

# Remote User (only relevant if remote_sync is set to yes)
remote_user="user"

# Remote Host (only relevant if remote_sync is set to yes)
remote_host="192.168.0.0"

# SSH port for a remote host (default is 22) (only relevant if remote_sync is set to yes)
ssh_port="22"

### SCRIPT ###

# Mount the drive
mount_point=$(udisksctl mount -b /dev/disk/by-uuid/$uuid | cut -d" " -f 4 | tr -d '\n')

# Wait for a specified period of time (e.g., 5 seconds)
sleep $sleep_time

# Create a temporary directory for syncing
mkdir -p "$mount_point/$device_sync_path/.tmp"

if [ "$remote_sync" = "yes" ]; then
   # Sync the podcasts from the remote source to the temporary directory
   rsync -avz -e "ssh -p $ssh_port" --progress --times "$remote_user@$remote_host:$source_podcast_path/" "$mount_point/$device_sync_path/.tmp/"

   # Delete the source mp3 files after syncing
   ssh -p $ssh_port $remote_user@$remote_host "find $source_podcast_path/ -type f -name '*.mp3' -exec rm -f {} \;"
else
   # Sync the podcasts from the local source to the temporary directory
   rsync -av --progress --times "$source_podcast_path/" "$mount_point/$device_sync_path/.tmp/"

   # Delete the source mp3 files after syncing
   find "$source_podcast_path/" -type f -name '*.mp3' -exec rm -f {} \;
fi

# Rename each file to include the parent folder name
if [ "$append_podcast_name" = "yes" ]; then
   find "$mount_point/$device_sync_path/.tmp" -type f -name '*.mp3' -print0 | while IFS= read -r -d $'\0' file; do
      dir=$(dirname "$file")
      base=$(basename "$file")
      parent=$(basename "$dir")
      mv "$file" "$dir/${base%.*} - $parent.mp3"
   done
fi

# Create a sorted list of files based on modified date, only for podcasts in the auto_queue_shows array
for podcast in "${auto_queue_shows[@]}"; do
   find "$mount_point/$device_sync_path/.tmp/$podcast" -type f -name '*.mp3' -printf '%T@ %p\0' | sort -z -n | cut -z -d ' ' -f2- >>sorted_files.txt
done

# Append the newly synced auto-queue episodes to the m3u8 playlist queue
while IFS= read -r -d $'\0' line; do
   playlist_path="${line/$mount_point\/$device_sync_path\/.tmp/$device_sync_path}"
   echo "$playlist_path" >>"$mount_point/$device_queue_location/Queue.m3u8"
done <sorted_files.txt

# Move the synced files to the device path
rsync -av --remove-source-files "$mount_point/$device_sync_path/.tmp/" "$mount_point/$device_sync_path/"

# Clean up
rm sorted_files.txt
if [ "$mount_point/$device_sync_path/.tmp" == "$mount_point/$device_sync_path/.tmp" ]; then
   rm -rf "$mount_point/$device_sync_path/.tmp"
fi

# Auto-cleanup old files based on max_age
if [ "$max_age" -gt 0 ]; then
   find "$mount_point/$device_sync_path" -type f -name '*.mp3' -mtime +$max_age -exec rm -f {} \;
fi

# Check if auto_clean_queue is set to yes
if [ "$auto_clean_queue" == "yes" ]; then
    # Update Queue.m3u8 based on the most recent bookmark from Queue.m3u8.bmark
    bmark_file="$mount_point/$device_queue_location/Queue.m3u8.bmark"
    queue_file="$mount_point/$device_queue_location/Queue.m3u8"

    if [ -f "$bmark_file" ]; then
        # Read the first line and modify the second field to 0
        first_line=$(head -n 1 "$bmark_file")
        IFS=';' read -ra parts <<< "$first_line"
        parts[1]=0
        modified_first_line=$(IFS=';'; echo "${parts[*]}")

        # Write the modified first line back to the file and delete all other lines
        echo "$modified_first_line" > "$bmark_file"

        # Extract the podcast path from the modified first line
        podcast_path="${parts[-1]}"
        mapfile -t queue_lines < "$queue_file"
        matched_index=-1
        for i in "${!queue_lines[@]}"; do
            if [[ "${queue_lines[$i]}" =~ .*"$podcast_path".* ]]; then
                matched_index=$i
                break
            fi
        done
        if [ $matched_index -ne -1 ]; then
            new_queue_lines=("${queue_lines[@]:$matched_index}")
            printf "%s\n" "${new_queue_lines[@]}" > "$queue_file"
            echo "Updated $queue_file successfully."
        else
            echo "No matching line found in $queue_file. Exiting."
        fi
    else
        echo "$bmark_file does not exist. Exiting."
    fi
fi

# Unmount the drive
udisksctl unmount -b /dev/disk/by-uuid/$uuid
