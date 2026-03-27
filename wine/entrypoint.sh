#!/bin/bash
set -euo pipefail

cd /home/container

export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
export TZ=Etc/GMT-9
export TERM=xterm
export XDG_RUNTIME_DIR=/tmp/runtime-root
export WINEPREFIX=/home/container/.wine
export DISPLAY=:0

stty cols 250 || true

echo "Running on Debian $(cat /etc/debian_version 2>/dev/null || echo unknown)"
echo "Current timezone: $(cat /etc/timezone 2>/dev/null || echo unknown)"
echo "Now time: $(date)"
wine --version || true

if [ "${STEAM_USER:-}" = "" ]; then
    STEAM_USER=anonymous
    STEAM_PASS=""
    STEAM_AUTH=""
fi

if [ -z "${AUTO_UPDATE:-}" ] || [ "${AUTO_UPDATE}" = "1" ]; then
    if [ -n "${SRCDS_APPID:-}" ]; then
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} $( [[ "${WINDOWS_INSTALL:-0}" = "1" ]] && printf %s '+@sSteamCmdForcePlatformType windows' ) +app_update 1007 +app_update ${SRCDS_APPID} $( [[ -z "${SRCDS_BETAID:-}" ]] || printf %s "-beta ${SRCDS_BETAID}" ) $( [[ -z "${SRCDS_BETAPASS:-}" ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) $( [[ -z "${VALIDATE:-}" ]] || printf %s "validate" ) +quit
    fi
fi

mkdir -p "$WINEPREFIX"

if [ "${XVFB:-1}" = "1" ]; then
    Xvfb :0 -screen 0 ${DISPLAY_WIDTH:-1024}x${DISPLAY_HEIGHT:-768}x${DISPLAY_DEPTH:-16} >/tmp/xvfb-run.log 2>&1 &
    sleep 1
fi

MODIFIED_STARTUP=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"
eval "${MODIFIED_STARTUP}"
