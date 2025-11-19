#!/bin/sh
###############################################################################
# INSTALL.SH — автообновление domlist.lst и firstlist.lst с GitHub на OpenWrt
# с логированием, автозапуском и перезапуском podkop
###############################################################################

echo "=== Installing GitHub auto-update service ==="

URL1="https://raw.githubusercontent.com/Qrolll/listofinteres/refs/heads/main/domlist.lst"
URL2="https://raw.githubusercontent.com/Qrolll/listofinteres/refs/heads/main/firstlist.lst"

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

URL1="https://raw.githubusercontent.com/Qrolll/listofinteres/refs/heads/main/domlist.lst"
URL2="https://raw.githubusercontent.com/Qrolll/listofinteres/refs/heads/main/firstlist.lst"

DEST_DIR="/etc/myfiles"
TMP_DIR="/tmp/github_download"
LOG_FILE="/var/log/getgithub.log"

FILES="
domlist.lst $URL1
firstlist.lst $URL2
"

mkdir -p "$DEST_DIR" "$TMP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting update..." >> "$LOG_FILE"

# Проверка интернета
ping -c1 -W2 8.8.8.8 >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No internet. Aborting." >> "$LOG_FILE"
    exit 1
fi

UPDATED=0

# Обработка всех файлов
echo "$FILES" | while read FILENAME URL; do
    [ -z "$FILENAME" ] && continue

    DEST_FILE="$DEST_DIR/$FILENAME"
    TMP_FILE="$TMP_DIR/$FILENAME"

    # Скачивание
    curl -fsSL "$URL" -o "$TMP_FILE" 2>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Download failed for $FILENAME." >> "$LOG_FILE"
        continue
    fi

    # Проверка обновления
    if [ ! -f "$DEST_FILE" ] || ! cmp -s "$TMP_FILE" "$DEST_FILE"; then
        mv "$TMP_FILE" "$DEST_FILE"
        UPDATED=1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updated $FILENAME." >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $FILENAME not modified." >> "$LOG_FILE"
    fi
done

# Перезапуск podkop
if [ $UPDATED -eq 1 ]; then
    if [ -x /etc/init.d/podkop ]; then
        /etc/init.d/podkop restart
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service 'podkop' restarted." >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service 'podkop' not found, skipping restart." >> "$LOG_FILE"
    fi
fi

# ----------------------
# Вывод итоговой информации
# ----------------------

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Final file info:" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

for F in domlist.lst firstlist.lst; do
    FILE_PATH="$DEST_DIR/$F"

    if [ -f "$FILE_PATH" ]; then
        SIZE=$(wc -c < "$FILE_PATH")
        HASH=$(sha256sum "$FILE_PATH" | awk '{print $1}')

        echo "$FILE_PATH"
        echo "Size: $SIZE bytes"
        echo "SHA256: $HASH"
        echo ""

        echo "$FILE_PATH" >> "$LOG_FILE"
        echo "   Size: $SIZE bytes" >> "$LOG_FILE"
        echo "   SHA256: $HASH" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    else
        echo "$FILE_PATH (NOT FOUND)"
        echo "$FILE_PATH (NOT FOUND)" >> "$LOG_FILE"
    fi
done

exit 0
EOF

chmod +x "$SCRIPT"

# -------------------------------
# 2. Init-скрипт
# -------------------------------
cat << 'EOF' > "$INIT_SCRIPT"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
PROG="/usr/bin/getgithub.sh"

start_service() {
    procd_open_instance
    procd_set_param command sh -c "sleep 30 && $PROG"
    procd_close_instance
}
EOF

chmod +x "$INIT_SCRIPT"
$INIT_SCRIPT enable

# -------------------------------
# 3. Cron
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
# 4. Первый запуск
# -------------------------------
echo "=== Running first update ==="
"$SCRIPT"

echo "=== Installation complete! ==="
echo "Files domlist.lst and firstlist.lst will sync from GitHub at boot and daily at 03:45."
echo "Service 'podkop' will be restarted only if any file is updated."
echo "Logs are available at $LOG_FILE"

echo ""
echo "=== Target file paths: ==="
echo "/etc/myfiles/domlist.lst"
echo "/etc/myfiles/firstlist.lst"
