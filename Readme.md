# pmrb - Podcast Manager for Rockbox

`pmrb` is a utility to sync podcasts to a Rockback playback device with the goal of emulating the functionality of a modern podcast app.

**WARNING** - This script deletes source files when syncing. It is recommended to run a separate Docker container or instance for your podcast downloading utility if you are already using one for other purposes.

## Features
- Automatic queuing of new episodes in the order that they were downloaded.
- Decide which podcasts to auto-queue and which don't.
- Auto cleanup of old episodes based on a specified age and file modified time.
- Auto cleanup of the Queue based on the most recent bookmark.
- Auto mount and unmount of the device.

## Dependencies

- udisks2
- rsync
- ssh (if remote sync is enabled)

## Also Required

A podcast downloading utility like Gpodder (recommended) or Podgrab

## Usage

1. Set the configuration options and optionally remote configuration options to match your setup.
2. If using remote sync setup ssh passwordless login ([guide](https://www.tecmint.com/ssh-passwordless-login-using-ssh-keygen-in-5-easy-steps/)).
3. Recommended Rockbox settings
    * `Settings > General Settings > Bookmarks > Bookmark on Stop > Ask` (or Yes, but Yes will create bookmarks for non-podcasts)
    * `Settings > General Settings > Bookmarks > Update on Stop > Yes`
4. Recommended Gpodder settings
    * Go to `Preferences > Extensions > Edit Config`
    * Ensure `extensions.rename_download.add_podcast_title` is checked.
    * Ensure `extensions.rename_download.add_sort_date` is checked.
    * This will add readability to your queue.
6. Manually run script or use cron jobs or systemd timers to automate.

## Configuration

Refer to the script for the configuration options. You need to set the paths for your podcasts, the device you want to sync to, and the podcasts you want to auto queue. If you want to sync from a remote source, you need to set the remote configuration options.

## Script

The script mounts the drive, creates a temporary directory for syncing, syncs the podcasts from the source to the temporary directory, deletes the source mp3 files after syncing, renames each file to include the parent folder name, creates a sorted list of files based on modified date, appends the newly synced episodes to the m3u8 playlist, moves the synced files to the device path. It then optionally checks for files in your podcast path with file modification dates older than the max age for deletion, and also optionally cleans your queue based on the last bookmark created for the queue by Rockbox. It then unmounts the drive.

## Workflow Tips

* After running the script, Resume Playback will generally not work, this is because Resume Playback will try to carry on with your previous dynamic playlist, but your queue and episode positions have likely been modified. Instead, the proper way to begin playback again is to go to your Queue playlist and start playback from your most recent bookmark, which will have been edited to be in position 1 in the queue.
* If you have a new episode that you want to listen to immediately but you are currently in the middle of an episode, there is a certain order of operations that is ideal to save the position of the current episode. Your first option is to just remember and skip to it, but if you don't want to do that here's what you can do. It's a bit hacky, but we're working around the limitations of the Rockbox interface here:
    1. In the While Playing Screen long press the select button and go to `Current Playlist > View Current Playlist` and then long press and move the new episode you want to listen to to the top of the queue.
    2. Long press the select button (on any episode) and Save the current playlist.
    3. Go back to the While Playing Screen and now you can create a bookmark for the in-progress episode (I use long press play/pause for this but you can also long press select and choose `Bookmark > Create Bookmark` from the menu.
    4. Now you can begin the new episode by going to you queue and clicking don't resume.
    5. Unfortunately when the new episode is over you will have to go back and select the most recent bookmark for the in-progress episode, I don't know of a way around this, Rockbox will not check for the bookmark while the Current Playlist is in progress.
 It's kind of a pain at first but becomes second nature quickly. This is all necessary because of how Bookmarks work in Rockbox, they point to a file in a certain queue position. If you move an episode around in your Current Playlist, the previous Bookmark will no longer be able to find that file in that position and will throw an error.
