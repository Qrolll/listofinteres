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

    # Скачиваем
    curl -fsSL "$URL" -o "$TMP_FILE" 2>> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Download failed for $FILENAME." >> "$LOG_FILE"
        continue
    fi

    # Проверяем изменения
    if [ ! -f "$DEST_FILE" ] || ! cmp -s "$TMP_FILE" "$DEST_FILE"; then
        mv "$TMP_FILE" "$DEST_FILE"
        UPDATED=1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updated $FILENAME." >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $FILENAME not modified." >> "$LOG_FILE"
    fi
done

# Перезапуск podkop если что-то обновилось
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
