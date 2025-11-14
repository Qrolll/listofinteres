#!/bin/sh
###############################################################################
# INSTALL.SH — автообновление файла domlist.lst с GitHub
# с логированием, автозапуском и перезапуском службы podkop
# перезапуск только при реальном обновлении файла
###############################################################################

echo "=== Installing GitHub auto-update service (update-triggered podkop restart) ==="

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

# Флаг, был ли файл обновлён
UPDATED=0

# Если файл не изменился — ничего не делаем
if [ ! -f "$DEST_FILE" ] || ! cmp -s "$TMP_FILE" "$DEST_FILE"; then
    # Обновляем основной файл
    mv "$TMP_FILE" "$DEST_FILE"
    UPDATED=1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] File updated." >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] File not modified. Nothing to update." >> "$LOG_FILE"
fi

# -------------------------------
# Перезапуск службы podkop только при обновлении
# -------------------------------
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
# 2. Добавляем cron на каждый день в 03:45
# -------------------------------
CRON_LINE_DAILY="45 3 * * * $SCRIPT"
if ! grep -Fq "$SCRIPT" /etc/crontabs/root 2>/dev/null; then
    echo "$CRON_LINE_DAILY" >> /etc/crontabs/root
    echo "=== Added daily cron job: 03:45 ==="
else
    echo "=== Daily cron job already exists. Skipped. ==="
fi

# -------------------------------
# 3. Добавляем @reboot запуск с задержкой 60 секунд
# -------------------------------
CRON_LINE_BOOT="@reboot sleep 60 && $SCRIPT"
if ! grep -Fq "@reboot" /etc/crontabs/root 2>/dev/null; then
    echo "$CRON_LINE_BOOT" >> /etc/crontabs/root
    echo "=== Added @reboot cron job ==="
else
    echo "=== @reboot cron job already exists. Skipped. ==="
fi

# Перезапускаем cron
/etc/init.d/cron restart

# -------------------------------
# 4. Запускаем скрипт сразу
# -------------------------------
echo "=== Running first update ==="
"$SCRIPT"

echo "=== Installation complete! ==="
echo "File domlist.lst will sync from GitHub at boot and daily at 03:45."
echo "Service 'podkop' will be restarted only if the file is updated."
echo "Logs are available at $LOG_FILE"
