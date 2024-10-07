# psync - Podcast Sync Utility

`psync` is a utility to sync podcasts to a playback device with the goal of emulating the functionality of a modern podcast app. It automatically queues new episodes in the order that they were downloaded. 

**WARNING** - This script deletes source files when syncing. It is recommended to run a separate Docker container or instance for your podcast downloading utility if you are already using one for other purposes.

## Dependencies

- udisks2
- rsync
- ssh (if remote sync is enabled)

## Also Required

A podcast downloading utility like Podgrab or Gpodder

## Usage

1. Set the configuration options and optionally remote configuration options to match your setup.
2. If using remote sync setup ssh passwordless login ([guide](https://www.tecmint.com/ssh-passwordless-login-using-ssh-keygen-in-5-easy-steps/)).
3. Manually run script or use cron jobs or systemd timers to automate.

## Configuration

Refer to the script for the configuration options. You need to set the paths for your podcasts, the device you want to sync to, and the podcasts you want to auto queue. If you want to sync from a remote source, you need to set the remote configuration options.

## Script

The script mounts the drive, creates a temporary directory for syncing, syncs the podcasts from the source to the temporary directory, deletes the source mp3 files after syncing, renames each file to include the parent folder name, creates a sorted list of files based on modified date, appends the newly synced episodes to the m3u8 playlist, moves the synced files to the device path, and unmounts the drive.
