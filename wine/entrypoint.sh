#!/bin/bash
cd /home/container

# ロケールとタイムゾーン環境変数を再設定
export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
export TZ=Etc/GMT-9
export TERM=xterm
stty cols 250

# Information output
echo "Running on Debian $(cat /etc/debian_version)"
echo "Current timezone: $(cat /etc/timezone)"
echo "Now time: $(date)"
wine --version

# Show current Wine timezone before change
echo "[Wine] Current Windows TimeZone before change:"
wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation" || echo "Not set"

# 書き込み用 .reg ファイルを作成してTokyo Standard Timeへ設定
echo "[Wine] Setting full Tokyo Standard Time timezone data"
cat <<EOF > /tmp/tokyo_timezone.reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation]
"ActiveTimeBias"=dword:fffffde4
"Bias"=dword:fffffde4
"DaylightBias"=dword:ffffffc4
"DaylightName"="@tzres.dll,-631"
"DaylightStart"=hex:00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
"DynamicDaylightTimeDisabled"=dword:00000000
"StandardBias"=dword:00000000
"StandardName"="@tzres.dll,-632"
"StandardStart"=hex:00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
"TimeZoneKeyName"="Tokyo Standard Time"
EOF

wine regedit /tmp/tokyo_timezone.reg

# Reinitialize Wine environment
echo "[Wine] Reinitializing Wine environment"
wineboot -u

# 再確認
echo "[Wine] Current Windows TimeZone after change:"
wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation" || echo "Failed to confirm"

# Make internal Docker IP address available to processes.
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Steam認証設定
if [ "${STEAM_USER}" == "" ]; then
    echo -e "steam user is not set.\n"
    echo -e "Using anonymous user.\n"
    STEAM_USER=anonymous
    STEAM_PASS=""
    STEAM_AUTH=""
else
    echo -e "user set to ${STEAM_USER}"
fi

# 自動アップデート
if [ -z ${AUTO_UPDATE} ] || [ "${AUTO_UPDATE}" == "1" ]; then 
    if [ ! -z ${SRCDS_APPID} ]; then
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} $( [[ "${WINDOWS_INSTALL}" == "1" ]] && printf %s '+@sSteamCmdForcePlatformType windows' ) +app_update 1007 +app_update ${SRCDS_APPID} $( [[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}" ) $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) $( [[ -z ${HLDS_GAME} ]] || printf %s "+app_set_config 90 mod ${HLDS_GAME}" ) $( [[ -z ${VALIDATE} ]] || printf %s "validate" ) +quit
    else
        echo -e "No appid set. Starting Server"
    fi
else
    echo -e "Not updating game server as auto update was set to 0. Starting Server"
fi

if [[ $XVFB == 1 ]]; then
    Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} &
fi

# 初回起動用準備
echo "First launch will throw some errors. Ignore them"
mkdir -p $WINEPREFIX

# Geckoインストール
if [[ $WINETRICKS_RUN =~ gecko ]]; then
    echo "Installing Gecko"
    WINETRICKS_RUN=${WINETRICKS_RUN/gecko}

    if [ ! -f "$WINEPREFIX/gecko_x86.msi" ]; then
        wget -q -O $WINEPREFIX/gecko_x86.msi http://dl.winehq.org/wine/wine-gecko/2.47.4/wine_gecko-2.47.4-x86.msi
    fi
    if [ ! -f "$WINEPREFIX/gecko_x86_64.msi" ]; then
        wget -q -O $WINEPREFIX/gecko_x86_64.msi http://dl.winehq.org/wine/wine-gecko/2.47.4/wine_gecko-2.47.4-x86_64.msi
    fi

    wine msiexec /i $WINEPREFIX/gecko_x86.msi /qn /quiet /norestart /log $WINEPREFIX/gecko_x86_install.log
    wine msiexec /i $WINEPREFIX/gecko_x86_64.msi /qn /quiet /norestart /log $WINEPREFIX/gecko_x86_64_install.log
fi

# Monoインストール
if [[ $WINETRICKS_RUN =~ mono ]]; then
    echo "Installing mono"
    WINETRICKS_RUN=${WINETRICKS_RUN/mono}

    if [ ! -f "$WINEPREFIX/mono.msi" ]; then
        wget -q -O $WINEPREFIX/mono.msi https://dl.winehq.org/wine/wine-mono/9.1.0/wine-mono-9.1.0-x86.msi
    fi

    wine msiexec /i $WINEPREFIX/mono.msi /qn /quiet /norestart /log $WINEPREFIX/mono_install.log
fi

# その他パッケージをインストール
for trick in $WINETRICKS_RUN; do
    echo "Installing $trick"
    winetricks -q $trick
done

# スタートアップコマンドを置換して実行
MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval ${MODIFIED_STARTUP}
