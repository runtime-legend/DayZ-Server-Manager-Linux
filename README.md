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
0 */2 * * * /home/dayz/dayzserver.sh checkmods > /dev/null 2>&1
0 */3 * * * /usr/local/bin/bercon-cli --ip 127.0.0.1 --port 2306 --password 12345678 "#shutdown"
# */30 * * * * /home/dayz/dayzserver.sh backup > /dev/null 2>&1
```

Explanation:

* @reboot – Automatically starts the DayZ server when the system boots.
* monitor – Runs every minute and restarts the server if it crashes or is shut down through supported restart methods.
* checkmods – Runs every 2 hours and checks for available DayZ server or Workshop mod updates. If updates are detected, an update flag is created and the updates will be installed automatically during the next server restart.
* bercon-cli "#shutdown" – Performs a scheduled server shutdown via BattlEye RCon every 3 hours. If the server runs as a `systemd` service with `Restart=always` (or the `monitor` task is active), it will be automatically started again, installing any pending updates before startup.
* backup – Optional periodic backup task (disabled by default).

Replace /home/dayz/ with the actual home directory of the Linux user running the server.

This configuration keeps crash recovery completely independent from Steam update checks while still allowing updates to be installed automatically during the next scheduled restart.

---

## Setting Up BattlEye RCon on Debian (DayZ Linux Server)

### 1. Stop the server

```bash
./dayzserver.sh stop
```

### 2. Open the BattlEye configuration

The file is located in the server directory:

```
~/serverfiles/battleye/baseserver_x64.cfg
```

or, after the first launch, an automatically generated file may be used instead:

```
~/serverfiles/battleye/beserver_x64_active_*.cfg
```

Add (or edit) the following parameters:

```
RConPassword 12345678
RConPort 2306
RestrictRCon 0
```

> Use your own strong password instead of `12345678`.

### 3. Start the server

```bash
./dayzserver.sh start
```

### 4. Verify that BattlEye opened the port

```bash
ss -lun | grep 2306
```

You should see something like:

```
UNCONN 0 0 0.0.0.0:2306
```

### 5. Test the RCon connection

Get the list of players:

```bash
bercon-cli \
  --ip 127.0.0.1 \
  --port 2306 \
  --password 12345678 \
  players
```

If everything is configured correctly, a table of players will appear.

### 6. Useful commands

List players:

```bash
bercon-cli -i 127.0.0.1 -p 2306 -P 12345678 players
```

Run any RCon command:

```bash
bercon-cli -i 127.0.0.1 -p 2306 -P 12345678 command "<command>"
```

For example:

```bash
bercon-cli -i 127.0.0.1 -p 2306 -P 12345678 command "players"
```

### Verifying it works

If the `players` command returns a list of players, it means:

* BattlEye started successfully;
* RCon is working;
* the password is correct;
* the server is ready for automation (restarts, notifications, monitoring, etc.).

---

## Installing bercon-cli (Debian/Linux)

### 1. Log in as root

```bash
su -
```

### 2. Download the client

```bash
curl -L -o /usr/bin/bercon-cli https://github.com/WoozyMasta/bercon-cli/releases/latest/download/bercon-cli-linux-amd64
```

### 3. Make it executable

```bash
chmod +x /usr/bin/bercon-cli
```

### 4. Verify the installation

```bash
bercon-cli --version
```

### Usage

After installation, a regular user can also run `bercon-cli`, because the binary is located in `/usr/bin` and has execute permissions for all users (`755`).

You can verify this with:

```bash
su - <your_user_name>
bercon-cli --version
```

or, if you are already logged in as a regular user:

```bash
bercon-cli --version
```

### Testing the connection

Verify that RCON is working and the server responds:

```bash
bercon-cli \
  --ip 127.0.0.1 \
  --port 2306 \
  --password 12345678 \
  players
```

If a list of players is displayed, the RCON connection is configured correctly.

### Shutting down the server

To shut down the server gracefully via RCON, use the following command:

```bash
bercon-cli \
  --ip 127.0.0.1 \
  --port 2306 \
  --password 12345678 \
  "#shutdown"
```

After receiving the command, the server will shut down. If it runs as a `systemd` service with `Restart=always`, it will be automatically started again.

### Automatic restarts via cron

Open the crontab:

```bash
crontab -e
```

Add a task to restart every 3 hours (00:00, 03:00, 06:00, ...):

```cron
0 */3 * * * /usr/local/bin/bercon-cli --ip 127.0.0.1 --port 2306 --password 12345678 "#shutdown"
```

> If needed, replace `/usr/local/bin/bercon-cli` with the path returned by the `which bercon-cli` command.