#!/bin/sh
###############################################################################
# INSTALL.SH — автообновление domlist.lst с GitHub на OpenWrt
# с логированием, автозапуском и перезапуском podkop
###############################################################################

echo "=== Installing GitHub auto-update service ==="

GITHUB_URL="https://raw.githubusercontent.com/Qrolll/listofinteres/refs/heads/main/domlist.lst"
SCRIPT="/usr/bin/getgithub.sh"
INIT_SCRIPT="/etc/init.d/getgithub"
DEST_DIR="/etc/myfiles"
TMP_DIR="/tmp/github_download"
LOG_FILE="/var/log/getgithub.log"

# -------------------------------
# 1. Создаём рабочий скрипт /usr/bin/getgithub.sh
# -------------------------------
mkdir -p "$DEST_DIR" "$TMP_DIR" "/var/log"

cat << 'EOF' > "$SCRIPT"
#!/bin/sh
URL="__REPLACE_URL__"
DEST_DIR="/etc/myfiles"
DEST_FILE="$DEST_DIR/domlist.lst"
TMP_DIR="/tmp/github_download"
TMP_FILE="$TMP_DIR/domlist.lst"
LOG_FILE="/var/log/getgithub.log"

mkdir -p "$DEST_DIR" "$TMP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting update..." >> "$LOG_FILE"

# Проверка интернета
ping -c1 -W2 8.8.8.8 >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No internet. Aborting." >> "$LOG_FILE"
    exit 1
fi

# Скачиваем через curl
curl -fsSL "$URL" -o "$TMP_FILE" 2>> "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Download failed. Aborting." >> "$LOG_FILE"
    exit 1
fi

UPDATED=0
if [ ! -f "$DEST_FILE" ] || ! cmp -s "$TMP_FILE" "$DEST_FILE"; then
    mv "$TMP_FILE" "$DEST_FILE"
    UPDATED=1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] File updated." >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] File not modified." >> "$LOG_FILE"
fi

# Перезапуск службы podkop только при обновлении
if [ $UPDATED -eq 1 ]; then
    if [ -x /etc/init.d/podkop ]; then
        /etc/init.d/podkop restart
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service 'podkop' restarted." >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service 'podkop' not found, skipping restart." >> "$LOG_FILE"
    fi
fi
EOF

# Подставляем URL
sed -i "s|__REPLACE_URL__|$GITHUB_URL|g" "$SCRIPT"
chmod +x "$SCRIPT"

# -------------------------------
# 2. Создаём init-скрипт /etc/init.d/getgithub
# -------------------------------
cat << 'EOF' > "$INIT_SCRIPT"
#!/bin/sh /etc/rc.common
# Init-скрипт для обновления domlist.lst через procd
START=99
USE_PROCD=1
PROG="/usr/bin/getgithub.sh"

start_service() {
    # Ждем 30 секунд, чтобы сеть поднялась
    procd_open_instance
    procd_set_param command sh -c "sleep 30 && $PROG"
    procd_close_instance
}
EOF

chmod +x "$INIT_SCRIPT"
$INIT_SCRIPT enable

# -------------------------------
# 3. Настройка ежедневного cron
# -------------------------------
CRON_LINE_DAILY="45 3 * * * $SCRIPT"
if ! grep -Fq "$SCRIPT" /etc/crontabs/root 2>/dev/null; then
    echo "$CRON_LINE_DAILY" >> /etc/crontabs/root
    echo "=== Added daily cron job: 03:45 ==="
else
    echo "=== Daily cron job already exists. Skipped. ==="
fi

/etc/init.d/cron restart

# -------------------------------
# 4. Первый запуск скрипта
# -------------------------------
echo "=== Running first update ==="
"$SCRIPT"

echo "=== Installation complete! ==="
echo "File domlist.lst will sync from GitHub at boot and daily at 03:45."
echo "Service 'podkop' will be restarted only if the file is updated."
echo "Logs are available at $LOG_FILE"
