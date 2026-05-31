#!/bin/bash

#=======================================================================================#
#     Authors:  @fiskce / @tootlejack / @thelastnoc / @haywardgg         Date: 28/11/2024
#=======================================================================================#
#
#                       DayZ Standalone Linux Server Manager
#
#=======================================================================================#

### NO NEED TO EDIT ANYTHING IN THIS FILE ###
### Changes should be made in config.ini ###

if [ "${ansi}" != "off" ]; then
        # echo colors
        default="\e[0m"
        red="\e[31m"
        green="\e[32m"
        yellow="\e[33m"
        lightyellow="\e[93m"
        blue="\e[34m"
        lightblue="\e[94m"
        magenta="\e[35m"
        cyan="\e[36m"
        # carriage return & erase to end of line
        creeol="\r\033[K"
fi

# Define the config file path
CONFIG_FILE="config.ini"

# Default content of the config.ini file
DEFAULT_CONFIG="
# DayZ SteamID
appid=223350
dayz_id=221100
#stable=223350
#exp_branch=1042420

# Game Port (Not Steam QueryPort. Add/Change that in your serverDZ.cfg file)
port=2301

# IMPORTANT PARAMETERS
steamlogin=CHANGEME
config=serverDZ.cfg
BEpath=\"-BEpath=\${HOME}/serverfiles/battleye/\"
profiles=\"-profiles=\${HOME}/serverprofile/\"
# optional - just remove the # to enable
#logs=\"-dologs -adminlog -netlog\"

# Discord Notifications.
discord_webhook_url=\"\"

# DayZ Mods from Steam Workshop
# Edit the workshop.cfg and add one Mod Number per line.
# To enable mods, remove the # below and list the Mods like this: \"@mod1;@mod2;@spaces work\". Lowercase only.
#workshop=\"\"
# To enable serverside mods, remove the # below and list the Mods like this: \"@servermod1;@server mod2\". Lowercase only.
#servermods=\"\"

# modify carefully! server won't start if syntax is corrupt!
dayzparameter=\" -config=\${config} -port=\${port} -freezecheck \${BEpath} \${profiles} \${logs}\""

# Check if the config.ini file exists
if [ ! -f "$CONFIG_FILE" ]; then
    printf "[ ${yellow}Warning${default} ] ${CONFIG_FILE} file not found.\n"
    echo -e "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    printf "[ ${green}Fixed${default} ] Default ${lightyellow}${CONFIG_FILE}${default} created.\n"
    printf "[ ${red}Important${default} ] Please edit the ${CONFIG_FILE} file before running this script again.\n"
    chmod 600 "$CONFIG_FILE"
    exit 1
else
    printf "[ ${green}Success${default} ] Config file found. Reading values...\n"
    # Source the config file to load its variables
    source "$CONFIG_FILE"
    printf "[ ${green}Finished${default} ] Configuration file loaded.\n"
    chmod 600 "$CONFIG_FILE"
fi

# Check if steamlogin is set to CHANGEME
if [ "$steamlogin" = "CHANGEME" ]; then
	printf "[ ${red}Error${default} ] Please update ${CONFIG_FILE} before running this script again.\n"
	exit 1
fi

fn_checkroot_dayz(){
	if [ "$(whoami)" == "root" ]; then
	  printf "[ ${red}FAIL${default} ] ${yellow}Do NOT run this script as root!\n"
	  printf "\tSwitch to the dayz user!${default}\n"
	  exit 1
	fi
}

check_dependencies(){
	    missing_tools=()
	    tools=("tmux" "curl" "jq" "wget")
	    libraries=("lib32gcc-s1")

	    # Check executables
	    for tool in "${tools[@]}"; do
	        if ! command -v "$tool" &>/dev/null; then
	            missing_tools+=("$tool")
	        fi
	    done

	    # Check libraries
	    for lib in "${libraries[@]}"; do
	        if ! dpkg -l | grep -q "$lib"; then
	            missing_tools+=("$lib")
	        fi
	    done

	    if [ "${#missing_tools[@]}" -ne 0 ]; then
	        echo -e "[ ${red}ERROR${default} ] The following dependencie(s) are missing and must be installed:"
	        for tool in "${missing_tools[@]}"; do
	            echo "  - $tool"
	        done
	        echo -e "[ ${yellow}INFO${default} ] Install these dependencie(s) using your package manager. For example:"
	        echo "      sudo apt install ${missing_tools[*]}   # For Debian/Ubuntu"
	        echo "      sudo yum install ${missing_tools[*]}   # For CentOS/RHEL"
	        echo "      sudo dnf install ${missing_tools[*]}   # For Fedora"
	        echo "      sudo pacman -S ${missing_tools[*]}     # For Arch"
	        exit 1
	    else
	        echo -e "[ ${green}OK${default} ] All required tools are installed."
	    fi
}


fn_checkscreen(){
	if [ -n "${STY}" ]; then
		printf "[ ${red}FAIL${default} ] The Script creates a tmux session when starting the server.\n"
		printf "\tIt is not possible to run a tmux session inside screen session\n"
		exit 1
	fi
}

fn_status_dayz(){
	dayzstatus=$(tmux list-sessions -F $(whoami)-tmux 2> /dev/null | grep -Ecx $(whoami)-tmux)
}

fn_clear_logs(){
	# Delete *.RPT, *.log, and *.mdmp files from the profiles directory
	profiles_dir="${HOME}/serverprofile" # Update this path if necessary
	if [ -d "${profiles_dir}" ]; then
		find "${profiles_dir}" -type f \( -name "*.RPT" -o -name "*.log" -o -name "*.mdmp" \) -delete
		printf "[ ${green}DayZ${default} ] Cleared old .RPT, .log, and .mdmp files from profiles directory.\n"
	fi
}


fn_start_dayz(){
	fn_status_dayz
	if [ "${dayzstatus}" == "1" ]; then
		printf "[ ${yellow}DayZ${default} ] Server already running.\n"
		exit 1
	else
                fn_backup_dayz
                # fn_update_dayz and fn_workshop_mods moved to the dedicated `u` / `ws`
                # commands so start/restart paths stay fast and have no Steam dependency.
                # Run `./dayzserver.sh u` manually or via a daily cron to apply updates.
                fn_clear_logs
		printf "[ ${green}DayZ${default} ] Starting server...\n"
		sleep 0.5
		sleep 0.5
		cd ${HOME}/serverfiles
		tmux new-session -d -x 23 -y 80 -s $(whoami)-tmux ./DayZServer $dayzparameter -mod="$workshop" -servermod="$servermods"
		sleep 1
		cd ${HOME}
		date > ${HOME}/.dayzlockfile
	fi
}

fn_stop_dayz(){
	fn_status_dayz
	if [ "${dayzstatus}" == "1" ]; then
		printf "[ ${magenta}...${default} ] Stopping Server graceful."
		# waits up to 90 seconds giving the server time to shutdown gracefuly
		for seconds in {1..90}; do
			fn_status_dayz
			if [ "${dayzstatus}" == "0" ]; then
				printf "\r[ ${green}OK${default} ] Stopping Server graceful.\n"
				rm -f ${HOME}/.dayzlockfile
				break
			fi
			printf "\r[ ${magenta}...${default} ] Stopping Server graceful: ${seconds} seconds"
			tmux send-keys C-c -t $(whoami)-tmux > /dev/null 2>&1
			sleep 1
		done
		fn_status_dayz
		if [ "${dayzstatus}" != "0" ]; then
			printf "\n[ ${red}FAIL${default} ] Stopping Server graceful failed. Stop Signal.\n"
			sleep 2
			rm -f ${HOME}/.dayzlockfile
			tmux kill-session -t $(whoami)-tmux
			#killall -u $(whoami)
		fi
	else
		printf "[ ${yellow}DayZ${default} ] Server not running.\n"
	fi
}

fn_restart_dayz(){
	fn_stop_dayz
	sleep 1
	fn_start_dayz
}

fn_monitor_dayz(){
	if [ ! -f ".dayzlockupdate" ]; then
		fn_status_dayz
		if [ "${dayzstatus}" == "0" ] && [ -f "${HOME}/.dayzlockfile" ]; then
			fn_restart_dayz
		elif [ "${dayzstatus}" != "0" ] && [ -f "${HOME}/.dayzlockfile" ]; then
			printf "[ ${lightblue}INFO${default} ] Server should be online!\n"
		else
			printf "[ ${yellow}INFO${default} ] Don't use monitor to start the server. Use the start command.\n"
		fi
	else
		printf "[ ${yellow}INFO${default} ] Serverfiles being updated\n."
	fi
}

fn_console_dayz(){
	printf "[${yellow} Warning ${default}] Press \"CTRL+b\" then \"d\" to exit console.\n    Do NOT press CTRL+c to exit.\n\n"
	sleep 0.1
	while true; do
                read -e -i "Y" -p "Continue? [Y/n] " -r answer
                case "${answer}" in
                        [Yy]|[Yy][Ee][Ss]) tmux a -t $(whoami)-tmux
                                           return 0;;
                        [Nn]|[Nn][Oo]) return 1 ;;
                *) echo "Please answer yes or no." ;;
                esac
        done
}


fn_install_dayz(){
	if [ ! -f "${HOME}/steamcmd/steamcmd.sh" ]; then
		mkdir ${HOME}/steamcmd &> /dev/null
		curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxf - -C steamcmd
		printf "[ ${yellow}STEAM${default} ] Steamcmd installed\n"
	else
		printf "[ ${lightblue}STEAM${default} ] Steamcmd already installed\n"
	fi
	if [ ! -f "${HOME}/serverfiles/DayZServer" ]; then
		mkdir ${HOME}/serverfiles &> /dev/null
		mkdir ${HOME}/serverprofile &> /dev/null
		printf "[ ${yellow}DayZ${default} ] Downloading DayZ Server-Files!\n"
		fn_runvalidate_dayz
	else
		printf "[ ${lightblue}DayZ${default} ] The Server is already installed.\n"
		fn_opt_usage
	fi
}

fn_runupdate_dayz(){
	${HOME}/steamcmd/steamcmd.sh +force_install_dir ${HOME}/serverfiles +login "${steamlogin}"  +app_update "${appid}" +quit
}

fn_update_dayz(){
	appmanifestfile=${HOME}/serverfiles/steamapps/appmanifest_"${appid}".acf
	printf "[ ... ] Checking for update: SteamCMD"
	# gets currentbuild
	currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d \  -f3)
	# Removes appinfo.vdf as a fix for not always getting up to date version info from SteamCMD
	if [ -f "${HOME}/Steam/appcache/appinfo.vdf" ]; then
		rm -f "${HOME}/Steam/appcache/appinfo.vdf"
		sleep 1
	fi
	# check for new build
	availablebuild=$(${HOME}/steamcmd/steamcmd.sh +login "${steamlogin}" +app_info_update 1 +app_info_print "${appid}" +app_info_print "${appid}" +quit | sed -n '/branch/,$p' | grep -m 1 buildid | tr -cd '[:digit:]')
	if [ -z "${availablebuild}" ]; then
		printf "\r[ ${red}FAIL${default} ] Checking for update: SteamCMD\n"
		sleep 0.5
		printf "\r[ ${red}FAIL${default} ] Checking for update: SteamCMD: Not returning version info\n"
		exit
	else
		printf "\r[ ${green}OK${default} ] Checking for update: SteamCMD"
		sleep 0.5
	fi
	# compare builds
	if [ "${currentbuild}" != "${availablebuild}" ]; then
		printf "\r[ ${green}OK${default} ] Checking for update: SteamCMD: Update available\n"
		printf "Update available:\n"
		sleep 0.5
		printf "\tCurrent build: ${red}${currentbuild}${default}\n"
		printf "\tAvailable build: ${green}${availablebuild}${default}\n"
		printf "\thttps://steamdb.info/app/${appid}/\n"
		sleep 0.5
		date > ${HOME}/.dayzlockupdate
		printf "\nApplying update"
		for seconds in {1..3}; do
			printf "."
			sleep 1
		done
		printf "\n"
		# run update
		fn_status_dayz
		if [ "${dayzstatus}" == "0" ]; then
			fn_runupdate_dayz
			fn_workshop_mods
			rm -f ${HOME}/.dayzlockupdate
		else
			fn_stop_dayz
			fn_runupdate_dayz
			fn_workshop_mods
			fn_start_dayz
			rm -f ${HOME}/.dayzlockupdate
		fi
	else
		printf "\r[ ${green}OK${default} ] Checking for update: SteamCMD: No update available\n"
		printf "\nNo update available:\n"
		printf "\tCurrent version: ${green}${currentbuild}${default}\n"
		printf "\tAvailable version: ${green}${availablebuild}${default}\n"
		printf "\thttps://steamdb.info/app/${appid}/\n\n"
	fi
}

fn_runvalidate_dayz(){
	${HOME}/steamcmd/steamcmd.sh +force_install_dir ${HOME}/serverfiles +login "${steamlogin}" +app_update "${appid}" validate +quit
}

fn_validate_dayz(){
	if [ "${dayzstatus}" == "0" ]; then
		fn_runvalidate_dayz
	else
		date > ${HOME}/.dayzlockupdate
		fn_stop_dayz
		fn_runvalidate_dayz
		fn_workshop_mods
		rm -f ${HOME}/.dayzlockupdate
		fn_start_dayz
	fi
}

fn_workshop_mods(){
    declare -a workshopID
    workshopfolder="${HOME}/serverfiles/steamapps/workshop/content/${dayz_id}"
    workshop_cfg="${HOME}/workshop.cfg"
    timestamp_file="${HOME}/mod_timestamps.json"

    if [ ! -f "$workshop_cfg" ]; then
        touch "$workshop_cfg"
        chmod 600 "$workshop_cfg"
    fi

    if [ ! -f "$timestamp_file" ]; then
        echo "{}" > "$timestamp_file"
    fi

    mapfile -t workshopID < "$workshop_cfg"

    echo "[ DayZ ] Downloading workshop mods..."

    local updated_workshop_cfg=""

    for i in "${workshopID[@]}"; do
        # Strip surrounding whitespace; skip empty lines.
        i=$(echo "$i" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$i" ] && continue

        mod_id=$(echo "$i" | awk '{print $1}')
        mod_name_from_cfg=$(echo "$i" | cut -d' ' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # cut -f2- on a single-token line returns the whole token; treat that as no name.
        [ "$mod_name_from_cfg" = "$mod_id" ] && mod_name_from_cfg=""

        if [[ ! "$mod_id" =~ ^[0-9]+$ ]]; then
            continue
        fi

        echo "[ INFO ] Downloading mod $mod_id"

        local mod_meta_file="${workshopfolder}/${mod_id}/meta.cpp"
        local steamcmd_log
        steamcmd_log=$(mktemp -t steamcmd.XXXXXX.log) || steamcmd_log="${HOME}/.steamcmd_last.log"

        success=0
        for attempt in {1..5}; do
            echo "[ INFO ] Attempt $attempt for mod $mod_id"

            : > "$steamcmd_log"
            ${HOME}/steamcmd/steamcmd.sh \
                +force_install_dir ${HOME}/serverfiles \
                +login "${steamlogin}" \
                +workshop_download_item "${dayz_id}" "$mod_id" validate \
                +quit 2>&1 | tee "$steamcmd_log"

            # SteamCMD prints "Success. Downloaded item <id> to ..." only on a real success.
            # A non-empty mod folder is NOT a reliable signal because timeouts leave partial
            # content behind. Require BOTH the success line AND meta.cpp present.
            if grep -q "Success\. Downloaded item ${mod_id}" "$steamcmd_log" && [ -f "$mod_meta_file" ]; then
                echo "[ OK ] Mod $mod_id downloaded"
                success=1
                break
            fi

            if grep -q "Timeout downloading item ${mod_id}" "$steamcmd_log"; then
                echo "[ WARN ] SteamCMD timeout on attempt $attempt for mod $mod_id"
            elif grep -qE "ERROR! .*${mod_id}" "$steamcmd_log"; then
                echo "[ WARN ] SteamCMD reported an error on attempt $attempt for mod $mod_id"
            else
                echo "[ WARN ] Attempt $attempt incomplete for mod $mod_id (no meta.cpp)"
            fi

            # Wipe the partial folder so the next attempt starts from a clean state.
            if [ -d "${workshopfolder}/${mod_id}" ]; then
                rm -rf "${workshopfolder}/${mod_id}"
            fi

            sleep 5
        done

        rm -f "$steamcmd_log"

        if [ "$success" -ne 1 ]; then
            echo "[ ERROR ] Failed to download mod $mod_id after 5 attempts"
            # Drop any partial folder left behind so we don't symlink to garbage on the next pass.
            if [ -d "${workshopfolder}/${mod_id}" ]; then
                rm -rf "${workshopfolder}/${mod_id}"
            fi
            # Preserve the existing cfg line so we don't lose a user-provided name.
            updated_workshop_cfg+="${mod_id}${mod_name_from_cfg:+ }${mod_name_from_cfg}"$'\n'
            continue
        fi

        # Resolve the mod's display name. Priority: meta.cpp > workshop.cfg > bare mod_id.
        local mod_meta_file="${workshopfolder}/$mod_id/meta.cpp"
        local resolved_name=""

        if [ -f "$mod_meta_file" ]; then
            # Anchor on a real `name = "..."` field to avoid matches like `title = "...Name..."`.
            resolved_name=$(grep -E '^[[:space:]]*name[[:space:]]*=' "$mod_meta_file" | head -n1 | cut -d '"' -f 2)
        fi

        if [ -z "$resolved_name" ]; then
            resolved_name="$mod_name_from_cfg"
        fi

        if [ -z "$resolved_name" ]; then
            # Last-resort fallback: use the mod id as the name so the symlink is `@<id>`
            # (functional, just not pretty). Loud warning so it's obvious in logs.
            resolved_name="$mod_id"
            echo "[ WARN ] No name from meta.cpp or workshop.cfg for mod $mod_id; using bare id"
        fi

		# Lowercase + replace spaces for the symlink path.
        local mod_link_name
		mod_link_name=$(echo "$resolved_name" | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g' -e 's/---*/-/g')
        local desired_link="${HOME}/serverfiles/@${mod_link_name}"

        # Clean up any stale symlinks pointing to this mod's folder under a different name
        # (e.g. a previous run created `@mod_<id>` because meta.cpp was unavailable, or
        # the mod author renamed the mod since the last run).
        for stale in ${HOME}/serverfiles/@*; do
            [ -L "$stale" ] || continue
            [ "$(readlink "$stale")" = "${workshopfolder}/${mod_id}" ] || continue
            if [ "$stale" != "$desired_link" ]; then
                echo "[ INFO ] Removing stale symlink: $(basename "$stale")"
                rm "$stale"
            fi
        done

        if [ ! -L "$desired_link" ]; then
            ln -s "${workshopfolder}/${mod_id}" "$desired_link"
            echo "[ OK ] Linked @${mod_link_name}"
        fi

        # Detect updates via meta.cpp mtime; notify Discord on actual upgrades only.
        if [ -f "$mod_meta_file" ]; then
            local mod_last_modified prev_timestamp
            mod_last_modified=$(date -r "$mod_meta_file" +%s 2>/dev/null || echo 0)
            prev_timestamp=$(jq -r --arg mod "$mod_id" '.[$mod] // 0' "$timestamp_file" 2>/dev/null || echo 0)

            # Only notify when we have a previous baseline (avoids first-run spam).
            if [ "$mod_last_modified" -gt "$prev_timestamp" ] && [ "$prev_timestamp" -gt 0 ]; then
                if [ -n "$discord_webhook_url" ]; then
                    curl -sS -H "Content-Type: application/json" -X POST \
                        -d "{\"content\": \"Mod '${resolved_name}' (ID: ${mod_id}) has been updated.\"}" \
                        "$discord_webhook_url" >/dev/null || true
                fi
            fi

            # Always update the recorded timestamp so future runs detect future changes.
            jq --arg mod "$mod_id" --argjson time "$mod_last_modified" \
                '.[$mod] = $time' "$timestamp_file" > "${timestamp_file}.tmp" \
                && mv "${timestamp_file}.tmp" "$timestamp_file"
        fi

        updated_workshop_cfg+="${mod_id} ${mod_link_name}"$'\n'
    done

	# Write resolved names back so subsequent runs can use them as a fallback.
    if [ -n "$updated_workshop_cfg" ]; then
        printf "%s" "$updated_workshop_cfg" > "$workshop_cfg"
        echo "[ OK ] Updated workshop.cfg with mod names"
    fi

    # Copy keys (handles paths containing spaces).
    echo "[ DayZ ] Copying keys..."
    find ${HOME}/serverfiles -type d \( -iname "keys" -o -iname "key" \) | while read -r dir; do
        cp -vu "$dir"/*.bikey "${HOME}/serverfiles/keys/" 2>/dev/null
    done

    echo "[ DayZ ] Current mod list:"
    echo "----------------------------------------"
    for link in "${HOME}/serverfiles"/@*; do
        [ -L "$link" ] && basename "$link"
    done | sort
    echo "----------------------------------------"

    fn_update_workshop_line

    echo "[ OK ] Workshop mods done"
}

# Build the workshop="@..." line from workshop.cfg and write it into config.ini,
# replacing any existing (commented or uncommented) workshop= line.
fn_update_workshop_line(){
    local workshop_cfg="${HOME}/workshop.cfg"
    local config_file="${CONFIG_FILE}"

    if [ ! -f "$config_file" ]; then
        printf "[ ${yellow}WARN${default} ] Config file ${config_file} not found - cannot update workshop line.\n"
        return 1
    fi

    local mod_line=""
    if [ -f "$workshop_cfg" ]; then
        while read -r line; do
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$line" ] && continue

            local mod_id_part name_part
            mod_id_part=$(echo "$line" | awk '{print $1}')
            name_part=$(echo "$line" | cut -d' ' -f2-)

            # Skip lines without a resolved mod name.
            [ -z "$name_part" ] && continue
            [ "$name_part" = "$mod_id_part" ] && continue

            if [ -z "$mod_line" ]; then
                mod_line="@${name_part}"
            else
                mod_line="${mod_line};@${name_part}"
            fi
        done < "$workshop_cfg"
    fi

    # Replace any existing workshop= line (with or without leading #), otherwise append one.
    if grep -qE '^[[:space:]]*#?[[:space:]]*workshop[[:space:]]*=' "$config_file"; then
        # Use | as sed delimiter so @ and ; in the value don't conflict.
        sed -i.bak -E "s|^[[:space:]]*#?[[:space:]]*workshop[[:space:]]*=.*|workshop=\"${mod_line}\"|" "$config_file"
        rm -f "${config_file}.bak"
        printf "[ ${green}OK${default} ] Updated workshop= line in ${config_file}\n"
    else
        printf 'workshop="%s"\n' "$mod_line" >> "$config_file"
        printf "[ ${green}OK${default} ] Added workshop= line to ${config_file}\n"
    fi

    printf "[ ${cyan}INFO${default} ] workshop=\"${green}${mod_line}${default}\"\n"
}

# Remove ALL installed mods and wipe player/storage data.
# Cleans: workshop content folder, @symlinks in serverfiles, mod-shipped bikeys,
# workshop.cfg, mod_timestamps.json, the workshop= line in config.ini, and finally
# runs the player/CE wipe. serverprofile is intentionally left alone — there is no
# reliable way to map a mod to the folder name it picks under serverprofile/.
# DESTRUCTIVE — intended for fresh setup, not running production servers.
fn_clean_mods(){
    local workshopfolder="${HOME}/serverfiles/steamapps/workshop/content/${dayz_id}"
    local workshop_cfg="${HOME}/workshop.cfg"
    local keys_dir="${HOME}/serverfiles/keys"
    local timestamp_file="${HOME}/mod_timestamps.json"

    printf "[ ${red}WARNING${default} ] This will remove ALL installed mods AND wipe player/storage data.\n"
    printf "[ ${red}WARNING${default} ] Intended for initial setup only. Do NOT run on a live/production server.\n"
    for seconds in {5..1}; do
        printf "\r\tProceeding in ${red}${seconds}${default} seconds... (Ctrl+C to cancel)"
        sleep 1
    done
    printf "\n"

    # First pass: collect every bikey filename actually shipped by an installed mod,
    # so we only delete those from serverfiles/keys/ and leave official game keys
    # (dayz.bikey, dayz_server.bikey, etc.) untouched.
    local -a mod_keynames=()
    if [ -d "$workshopfolder" ]; then
        while IFS= read -r -d '' kdir; do
            for keyfile in "$kdir"/*.bikey; do
                [ -f "$keyfile" ] || continue
                mod_keynames+=("$(basename "$keyfile")")
            done
        done < <(find "$workshopfolder" -type d \( -iname "keys" -o -iname "key" \) -print0 2>/dev/null)
    fi

    # Remove every @symlink under serverfiles. We intentionally do not touch
    # serverprofile/ because mods are free to pick any folder name there.
    if [ -d "${HOME}/serverfiles" ]; then
        for link in "${HOME}/serverfiles"/@*; do
            [ -e "$link" ] || [ -L "$link" ] || continue
            rm -rf "$link"
            printf "[ ${green}OK${default} ] Removed: ${link}\n"
        done
    fi

    # Wipe downloaded workshop content for this app.
    if [ -d "$workshopfolder" ]; then
        rm -rf "${workshopfolder:?}"/*
        printf "[ ${green}OK${default} ] Cleared workshop content in ${workshopfolder}\n"
    fi

    # Remove ONLY the bikeys that were collected from installed mods above.
    # Official keys (dayz.bikey, dayz_server.bikey, etc.) are left in place.
    if [ -d "$keys_dir" ] && [ ${#mod_keynames[@]} -gt 0 ]; then
        local removed_keys=0
        for keyname in "${mod_keynames[@]}"; do
            if [ -f "${keys_dir}/${keyname}" ]; then
                rm -f "${keys_dir}/${keyname}"
                removed_keys=$((removed_keys + 1))
            fi
        done
        printf "[ ${green}OK${default} ] Removed ${removed_keys} mod key(s) from ${keys_dir}\n"
    fi

    if [ -f "$workshop_cfg" ]; then
        : > "$workshop_cfg"
        printf "[ ${green}OK${default} ] Cleared workshop.cfg\n"
    fi

    if [ -f "$timestamp_file" ]; then
        echo "{}" > "$timestamp_file"
    fi

    fn_update_workshop_line
    printf "[ ${green}DayZ${default} ] All mods removed.\n"

    # Drop SteamCMD/workshop caches so the next `ws` starts from a clean manifest.
    fn_clean_dayz

    # Wipe player + Central Economy state. fn_wipe_dayz reads dayzstatus to decide
    # whether to stop/restart the server around the wipe, so refresh it first.
    fn_status_dayz
    fn_wipe_dayz
}


fn_backup_dayz(){
    fn_status_dayz

    # Ensure backup directory exists
    if [ ! -d "${HOME}/backup" ]; then
        mkdir -p ${HOME}/backup &> /dev/null
    fi

    # Get the mission folder name
    missionfolder=$(grep template ${HOME}/serverfiles/serverDZ.cfg | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d \  -f3)

    # Format for backup files: missionfolder-Month-Day-Hour-Minute.tar
    backup_file="${HOME}/backup/${missionfolder}-$(date +%m-%d-%H-%M).tar"
    profile_backup_file="${HOME}/backup/serverprofile-$(date +%m-%d-%H-%M).tar"

    # Create the backup of the mission folder
    if [ "${dayzstatus}" == "0" ]; then
        printf "[ ${green}DayZ${default} ] Creating backup of Missionfolder: ${cyan}${missionfolder}${default}\n"
        tar -cf "$backup_file" -C "${HOME}/serverfiles/mpmissions" "${missionfolder}"
	    # Backup the serverprofile directory while excluding .log and .RPT files
	    printf "[ ${green}DayZ${default} ] Creating backup of Serverprofile directory: ${cyan}${HOME}/serverprofile${default}\n"
	    tar --exclude='*.log' --exclude='*.RPT' -cf "$profile_backup_file" -C "${HOME}" "serverprofile"
    else
        fn_stop_dayz
        fn_start_dayz
    fi

    # Delete backups older than 2 days
    printf "[ ${green}DayZ${default} ] Cleaning up backups older than 2 days...\n"
    find "${HOME}/backup" -type f -name "${missionfolder}-*.tar" -mtime +2 -exec rm -f {} \;
    find "${HOME}/backup" -type f -name "serverprofile-*.tar" -mtime +2 -exec rm -f {} \;
}


fn_wipe_dayz(){
	missionfolder=$(grep template ${HOME}/serverfiles/serverDZ.cfg | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d \  -f3)
	printf "[ ${red}WARNING${default} ] Wiping Players and reset Central Economy state from...\n"
	for seconds in {9..0}; do
		printf "\r\t    Selected Mission: ${cyan}${missionfolder}${default} in ${red}"${seconds}"${default} seconds."
		sleep 1
	done
	printf "\n"
	if [ "${dayzstatus}" == "0" ]; then
		rm -f ${HOME}/serverfiles/mpmissions/${missionfolder}/storage_1/players.db
		rm -f ${HOME}/serverfiles/mpmissions/${missionfolder}/storage_1/data/*
		printf "[ ${yellow}DayZ${default} ] Player.db and Storage-data wiped!\n"
	else
		fn_stop_dayz
		rm -f ${HOME}/serverfiles/mpmissions/${missionfolder}/storage_1/players.db
		rm -f ${HOME}/serverfiles/mpmissions/${missionfolder}/storage_1/data/*
		printf "[ ${yellow}DayZ${default} ] Player.db and Storage-data wiped!\n"
		sleep 0.5
		fn_start_dayz
	fi
}

fn_clean_dayz(){
	printf "[ ${magenta}...${default} ] Clearing SteamCMD / workshop caches...\n"

	rm -rf "${HOME}/Steam/appcache"
	printf "[ ${green}OK${default} ] Removed ${HOME}/Steam/appcache\n"

	rm -rf "${HOME}/serverfiles/steamapps/downloading"
	printf "[ ${green}OK${default} ] Removed ${HOME}/serverfiles/steamapps/downloading\n"

	rm -f "${HOME}/serverfiles/steamapps/workshop/appworkshop_${dayz_id}.acf"
	printf "[ ${green}OK${default} ] Removed ${HOME}/serverfiles/steamapps/workshop/appworkshop_${dayz_id}.acf\n"

	printf "[ ${green}DayZ${default} ] Cache cleared.\n"
}

cmd_start=( "st;start" "fn_start_dayz" "Start the server." )
cmd_stop=( "sp;stop" "fn_stop_dayz" "Stop the server." )
cmd_restart=( "r;restart" "fn_restart_dayz" "Restart the server.")
cmd_monitor=( "m;monitor" "fn_monitor_dayz" "Check server status and restart if crashed." )
cmd_console=( "c;console" "fn_console_dayz" "Access server console." )
cmd_install=( "i;install" "fn_install_dayz" "Install steamcmd and DayZ Server-Files." )
cmd_update=( "u;update" "fn_update_dayz" "Check and apply any server updates." )
cmd_validate=( "v;validate" "fn_validate_dayz" "Validate server files with SteamCMD." )
cmd_workshop=( "ws;workshop" "fn_workshop_mods" "Download Mods from Steam Workshop." )
cmd_backup=( "b;backup" "fn_backup_dayz" "Create backup archives of the server (mpmission)." )
cmd_wipe=( "wi;wipe" "fn_wipe_dayz" "Wipe your server data (Player and Storage)." )
cmd_cleancache=( "cc;cleancache" "fn_clean_dayz" "Clear SteamCMD / workshop caches." )
cmd_cleanmods=( "cm;cleanmods" "fn_clean_mods" "DESTRUCTIVE: Remove ALL mods and wipe player/storage data. Setup-only; NOT for production." )

### Set specific opt here ###
currentopt=( "${cmd_start[@]}" "${cmd_stop[@]}" "${cmd_restart[@]}" "${cmd_monitor[@]}" "${cmd_console[@]}" "${cmd_install[@]}" "${cmd_update[@]}" "${cmd_validate[@]}" "${cmd_workshop[@]}" "${cmd_backup[@]}" "${cmd_wipe[@]}" "${cmd_cleancache[@]}" "${cmd_cleanmods[@]}" )

### Build list of available commands
optcommands=()
index="0"
for ((index="0"; index < ${#currentopt[@]}; index+=3)); do
	cmdamount="$(echo "${currentopt[index]}" | awk -F ';' '{ print NF }')"
	for ((cmdindex=1; cmdindex <= ${cmdamount}; cmdindex++)); do
		optcommands+=( "$(echo "${currentopt[index]}" | awk -F ';' -v x=${cmdindex} '{ print $x }')" )
	done
done

# Shows LinuxGSM usage
fn_opt_usage(){
        printf "\nDayZ - Linux Game Server"
	printf "\nUsage:${lightblue} $0 [command]${default}\n\n"
        printf "${lightyellow}Commands${default}\n"
        # Display available commands
        index="0"
        {
        for ((index="0"; index < ${#currentopt[@]}; index+=3)); do
                # Hide developer commands
                if [ "${currentopt[index+2]}" != "DEVCOMMAND" ]; then
                        echo -e "${cyan}$(echo "${currentopt[index]}" | awk -F ';' '{ print $2 }')\t${default}$(echo "${currentopt[index]}" | awk -F ';' '{ print $1 }')\t|${currentopt[index+2]}"
                fi
        done
        } | column -s $'\t' -t
        exit 1
}

# start functions
fn_checkroot_dayz
check_dependencies
fn_checkscreen

getopt=$1
if [ ! -f "${HOME}/steamcmd/steamcmd.sh" ] || [ ! -f "${HOME}/serverfiles/DayZServer" ] && [ "${getopt}" != "cfg" ]; then
	printf "[ ${yellow}INFO${default} ] No installed steamcmd and/or serverfiles found!\n"
	chmod u+x ${HOME}/dayzserver
	fn_install_dayz
	if [ -f "${HOME}/steamcmd/steamcmd.sh" ] && [ -f "${HOME}/serverfiles/DayZServer" ]; then
		fn_opt_usage
	fi
	exit
else
	### Check if user commands exist and run corresponding scripts, or display script usage
	if [ -z "${getopt}" ]; then
		fn_opt_usage
	fi
fi

# Command exists
for i in "${optcommands[@]}"; do
	if [ "${i}" == "${getopt}" ] ; then
		# Seek and run command
		index="0"
		for ((index="0"; index < ${#currentopt[@]}; index+=3)); do
			currcmdamount="$(echo "${currentopt[index]}" | awk -F ';' '{ print NF }')"
			for ((currcmdindex=1; currcmdindex <= ${currcmdamount}; currcmdindex++)); do
				if [ "$(echo "${currentopt[index]}" | awk -F ';' -v x=${currcmdindex} '{ print $x }')" == "${getopt}" ]; then
					# Run command
					eval "${currentopt[index+1]}"
                                        exit 1
					break
				fi
			done
		done
	fi
done

# If we're executing this, it means command was not found
echo -e "${red}Unknown command${default}: $0 ${getopt}"
fn_opt_usage
