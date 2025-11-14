#!/bin/sh
###############################################################################
# INSTALL.SH — установка автообновления файла domlist.lst с GitHub
# с логированием ошибок на OpenWrt
###############################################################################

echo "=== Installing GitHub auto-update service (with logging) ==="

GITHUB_URL="https://raw.githubusercontent.com/Qrolll/listofinteres/refs/heads/main/domlist.lst"
SCRIPT="/usr/bin/getgithub.sh"
DEST_DIR="/etc/myfiles"
TMP_DIR="/tmp/github_download"
LOG_FILE="/var/log/getgithub.log"

# -------------------------------
# 1. Создаём рабочий скрипт с логированием
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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting update..." >> "$LOG_FILE"

mkdir -p "$DEST_DIR" "$TMP_DIR"

# Проверка интернета
ping -c1 -W2 8.8.8.8 >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No internet. Aborting." >> "$LOG_FILE"
    exit 1
fi

# Скачиваем через curl с логированием ошибок
curl -fsSL "$URL" -o "$TMP_FILE" 2>> "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Download failed. Aborting." >> "$LOG_FILE"
    exit 1
fi

# Если файл не изменился — ничего не делаем
if [ -f "$DEST_FILE" ] && cmp -s "$TMP_FILE" "$DEST_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] File not modified. Nothing to update." >> "$LOG_FILE"
    exit 0
fi

# Обновляем основной файл
mv "$TMP_FILE" "$DEST_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Update complete." >> "$LOG_FILE"
EOF

# Подставляем URL
sed -i "s|__REPLACE_URL__|$GITHUB_URL|g" "$SCRIPT"
chmod +x "$SCRIPT"

# -------------------------------
# 2. Добавляем cron на каждый день в 03:45
# -------------------------------
CRON_LINE="45 3 * * * $SCRIPT"
if ! grep -Fq "$SCRIPT" /etc/crontabs/root 2>/dev/null; then
    echo "$CRON_LINE" >> /etc/crontabs/root
    echo "=== Added cron job: 03:45 daily ==="
else
    echo "=== Cron job already exists. Skipped. ==="
fi

# Перезапускаем cron
/etc/init.d/cron restart

# -------------------------------
# 3. Добавляем запуск при старте
# -------------------------------
RC_LOCAL="/etc/rc.local"
if ! grep -Fq "$SCRIPT" "$RC_LOCAL" 2>/dev/null; then
    sed -i -e "/^exit 0/i $SCRIPT &" "$RC_LOCAL"
    echo "=== Added boot-time execution ==="
fi

# -------------------------------
# 4. Запускаем скрипт сразу
# -------------------------------
echo "=== Running first update ==="
"$SCRIPT"

echo "=== Installation complete! ==="
echo "File domlist.lst will sync from GitHub at boot and daily at 03:45."
echo "Logs are available at $LOG_FILE"
