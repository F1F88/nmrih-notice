# NMRIH Notice

**Document :** [English](./readme.md) | [中文](./readme-CN.md)

### Feature

1. When the following situations occur, the plugin will send a reminder in the game's chat box
    - Player bleeding
    - Player infection
    - One player is attacked by another player
    - One player is killed by another player
    - A player has set off `keycode_enter` event

2. By using the `ConVar` provided by this plugin, you can control which situations in `(1)` to issue reminders in

   | ConVar | Default | Description |
   |-------------------------|-----|---------------|
   | sm_notice_bleeding | 1 | Prompt the player to bleed in the chat box |
   | sm_notice_infected | 1 | Prompt the player to be infected in the chat box |
   | sm_notice_ff | 1 | Prompt teammates to attack in the chat box |
   | sm_notice_fk | 1 | Prompt teammates to kill in the chat box |
   | sm_notice_fk_rp | 0 | Prompt teammates in the chat box on how to report killing |
   | sm_notice_ffmsg_interval | 1.0 | Minimum interval for each friendly injury reminder (in seconds) |
   | sm_notice_keycode | 1 | The password entered on the keyboard when prompted in the chat box |

3. Support clientprefs, players can use `!Settings` in the game to control which situations in `(1)` to receive reminders
    - Plugin delayed loading supported
    - Supports 'hot swapping' (even without clientprefs, all considered received)

4. Provided **5** items `native` to obtain player status
    - Specific reference [nmrih-notice.inc](./scripting/include/nmrih-notice.inc)

5. Provided **4** item `forward` to simplify the process of player infection and bleeding during detours
    - Specific reference [nmrih-notice.inc](./scripting/include/nmrih-notice.inc)

This project is equivalent to an upgraded version
of [[NMRiH] Infection/Bledding Notification](https://forums.alliedmods.net/showthread.php?p=2335718)

Warning: This plugin is no longer supported on windows, you need to update the signature of [nmrih-notice.games.txt](./gamedata/nmrih-notice.games.txt) if you want to use it on windows

## Requirements

- [SourceMod 1.12](https://www.sourcemod.net/downloads.php?branch=stable) or higher

- [multicolors](https://github.com/Bara/Multi-Colors)

- plugin clientprefs.smx (option)

## Installation

- Grab the latest ZIP from releases
- Extract the contents into `addons/sourcemod`
- Load the plugin: `sm plugins load nmrih-notice`
