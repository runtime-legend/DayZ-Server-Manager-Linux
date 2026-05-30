# DayZ Server Manager for Linux Server Instances

> **Community Maintained Fork**
>
> This project is a community-maintained fork of the original DayZ Server Manager for Linux project created by fiskce.
>
> Original repository:
> https://github.com/fiskce/DayZ-Server-Manager-Linux
>
> This fork exists to continue development, maintenance, bug fixes, and feature improvements for the DayZ community.

1. Attention! Make sure the Steam account you are using owns DayZ, otherwise the mod installation process may fail.
2. Attention! In some cases SteamCMD will not install the mission scripts. If this happens, create the `mpmissions` folder manually and download the mission scripts from [DayZ Central Economy](https://github.com/BohemiaInteractive/DayZ-Central-Economy).

![](https://edge-prodberiffagroup.b-cdn.net/web/dayzservermanagerheadlinegifsmall-revisedyellow.gif)

DayZ Server Manager for Linux is a comprehensive and user-friendly script designed to automate server installation, updates, backups, and monitoring.

### Alternative Cron Configuration

If you prefer to handle scheduled restarts and updates directly through Cron instead of using messages.xml, you can use the following example:
```
@reboot /home/dayz/dayzserver.sh start > /dev/null 2>&1
*/1 * * * * /home/dayz/dayzserver.sh monitor > /dev/null 2>&1
0 */3 * * * /home/dayz/dayzserver.sh restart > /dev/null 2>&1
0 4 * * * /home/dayz/dayzserver.sh u > /dev/null 2>&1
# */30 * * * * /home/dayz/dayzserver.sh backup > /dev/null 2>&1
```

Explanation:

* @reboot – Automatically starts the DayZ server when the system boots.
* monitor – Runs every minute and restarts the server if it crashes or is shut down through supported restart methods.
* restart – Performs a scheduled server restart every 3 hours.
* u – Checks for and installs DayZ server and Workshop mod updates daily at 04:00.
* backup – Optional periodic backup task (disabled by default).

Replace /home/dayz/ with the actual home directory of the Linux user running the server.