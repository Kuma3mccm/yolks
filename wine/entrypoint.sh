#!/bin/bash
cd /home/container

# 環境変数・ロケール・タイムゾーン設定
export TZ=Asia/Tokyo
export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
export TERM=xterm-256color
export COLUMNS=120
export LINES=30
stty cols 120 rows 30

# 情報出力
echo "Running on Debian $(cat /etc/debian_version)"
echo "Current timezone: $(cat /etc/timezone)"
wine --version

# Docker内部IP取得
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Steam認証処理
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

# XVFB仮想ディスプレイ
if [[ $XVFB == 1 ]]; then
    Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} &
fi

echo "First launch will throw some errors. Ignore them"

# WINEPREFIX 初期化
mkdir -p $WINEPREFIX

# Gecko/MONO/winetricks
if [[ $WINETRICKS_RUN =~ gecko ]]; then
    echo "Installing Gecko"
    WINETRICKS_RUN=${WINETRICKS_RUN/gecko}
    wget -q -O $WINEPREFIX/gecko_x86.msi http://dl.winehq.org/wine/wine-gecko/2.47.4/wine_gecko-2.47.4-x86.msi
    wget -q -O $WINEPREFIX/gecko_x86_64.msi http://dl.winehq.org/wine/wine-gecko/2.47.4/wine_gecko-2.47.4-x86_64.msi
    wine msiexec /i $WINEPREFIX/gecko_x86.msi /qn /quiet /norestart
    wine msiexec /i $WINEPREFIX/gecko_x86_64.msi /qn /quiet /norestart
fi

if [[ $WINETRICKS_RUN =~ mono ]]; then
    echo "Installing mono"
    WINETRICKS_RUN=${WINETRICKS_RUN/mono}
    wget -q -O $WINEPREFIX/mono.msi https://dl.winehq.org/wine/wine-mono/9.1.0/wine-mono-9.1.0-x86.msi
    wine msiexec /i $WINEPREFIX/mono.msi /qn /quiet /norestart
fi

for trick in $WINETRICKS_RUN; do
    echo "Installing $trick"
    winetricks -q $trick
done

# スタートアップコマンド展開
MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

# 直接実行、STDOUTをPterodactylに即時反映
exec env -u LD_PRELOAD -u STDBUF_PTS ${MODIFIED_STARTUP}
