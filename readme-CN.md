# NMRIH Notice

**文档 :** [中文](./readme-CN.md) | [English](./readme.md)

### 特性

1. 当出现以下情况时，插件会在游戏的聊天框内发出提醒
    - 玩家流血
    - 玩家感染
    - 一名玩家被另一名玩家攻击
    - 一名玩家被另一名玩家击杀
    - 一名玩家触发 `keycode_enter` 事件

2. 使用此插件提供的 `ConVar`，可以控制在 `(1)` 中的哪些情况下发出提醒

   | ConVar                  | 默认值 | 描述            |
   |-------------------------|-----|---------------|
   | sm_notice_bleeding      | 1   | 在聊天框提示玩家流血    |
   | sm_notice_infected      | 1   | 在聊天框提示玩家感染    |
   | sm_notice_ff            | 1   | 在聊天框提示队友攻击    |
   | sm_notice_fk            | 1   | 在聊天框提示队友击杀    |
   | sm_notice_fk_rp         | 0   | 在聊天框提示队友击杀如何举报 |
   | sm_notice_ffmsg_interval | 1.0 | 每条友伤提醒最短间隔（秒） |
   | sm_notice_keycode       | 1   | 在聊天框提示键盘输入的密码 |

3. 支持 `clientprefs`，玩家可以在游戏里使用 `!settings` 控制在 `(1)` 中的哪些情况下接收提醒
    - 已支持插件延迟加载
    - 已支持 "热插拔" （即使卸载 clientprefs 插件也不影响运行, 默认客户全部接收）

4. 提供了 **5** 项 `native` 供其他插件获取玩家状态
    - 具体参考 [nmrih-notice.inc](./scripting/include/nmrih-notice.inc)

5. 提供了 **4** 项 `forward` 供其他插件绕行玩家感染、流血
    - 具体参考 [nmrih-notice.inc](./scripting/include/nmrih-notice.inc)

此项目相当于 [[NMRiH] Infection/Bledding Notification](https://forums.alliedmods.net/showthread.php?p=2335718) 的升级版

警告：此插件不再支持 windows 平台，如果想 windows 平台使用，你需要更新 [nmrih-notice.games.txt](./gamedata/nmrih-notice.games.txt) 的签名

## 依赖

- [SourceMod 1.11](https://www.sourcemod.net/downloads.php?branch=stable) 或更高版本

- [multicolors](https://github.com/Bara/Multi-Colors) (utils_clientprefs.inc 依赖于此)

- [clients_methodmap](https://forums.alliedmods.net/showthread.php?t=307157) (只需要其中的 IsValidClient)

- [log_methodmap](https://github.com/F1F88/sm-logdebug)

- 插件 clientprefs.smx（可选）

## 使用方法

- 下载最新的 releases 压缩包
- 将压缩包解压到服务器的 `addons/sourcemod` 文件夹
- 重启服务器或使用 `sm plugins load nmrih-notice` 加载插件
