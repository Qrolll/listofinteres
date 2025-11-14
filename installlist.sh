#!/bin/sh

###############################################################################
# INSTALL.SH — установка службы обновления файла domlist.lst с GitHub
# + автозапуск при загрузке
# + cron каждый день в 03:45
###############################################################################

echo "=== Installing GitHub auto-update service ==="

#############################################
# 1. URL файла на GitHub
#############################################

GITHUB_URL="https://raw.githubusercontent.com/Qrolll/listofinteres/refs/heads/main/domlist.lst"

#############################################
# 2. Создаём рабочий скрипт /usr/bin/getgithub.sh
#############################################

cat << 'EOF' > /usr/bin/getgithub.sh
#!/bin/sh

# -------------------------------
# Конфигурация
# -------------------------------

URL="__REPLACE_URL__"

# Основной файл
DEST_DIR="/etc/myfiles"
DEST_FILE="$DEST_DIR/domlist.lst"

# Временные файлы
TMP_DIR="/tmp/github_download"
TMP_FILE="$TMP_DIR/domlist.lst"

mkdir -p "$DEST_DIR" "$TMP_DIR"

echo "[getgithub] Checking internet..."

# -------------------------------
# Проверка интернета
# -------------------------------
if ! ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
    echo "[getgithub] No internet. Aborting."
    exit 1
fi

echo "[getgithub] Internet OK. Downloading from GitHub..."

# -------------------------------
# Скачиваем файл только при изменении
# -------------------------------
if ! wget -N -P "$TMP_DIR" "$URL" >/tmp/getgithub_wget.log 2>&1; then
    echo "[getgithub] wget failed. GitHub may be unavailable. Aborting."
    exit 1
fi

# Если файл не изменился, TMP_FILE не создаётся
if [ ! -f "$TMP_FILE" ]; then
    echo "[getgithub] File not modified. Nothing to update."
    exit 0
fi

# -------------------------------
# Обновляем основной файл
# -------------------------------
echo "[getgithub] New file downloaded. Updating $DEST_FILE..."
mv "$TMP_FILE" "$DEST_FILE"

echo "[getgithub] Update complete."
exit 0
EOF

# Подставляем URL внутрь скрипта
sed -i "s|__REPLACE_URL__|$GITHUB_URL|g" /usr/bin/getgithub.sh
chmod +x /usr/bin/getgithub.sh

#############################################
# 3. Создаём init-скрипт /etc/init.d/getgithub
#############################################

cat << 'EOF' > /etc/init.d/getgithub
#!/bin/sh /etc/rc.common

# Init-скрипт для procd
START=90
USE_PROCD=1
PROG="/usr/bin/getgithub.sh"

start_service() {
    procd_open_instance
    procd_set_param command $PROG
    procd_close_instance
}
EOF

chmod +x /etc/init.d/getgithub

echo "=== Enabling autostart ==="
/etc/init.d/getgithub enable

#############################################
# 4. Добавляем cron на каждый день в 03:45
#############################################

CRON_LINE="45 3 * * * /usr/bin/getgithub.sh"

# добавляем запись только если её ещё нет
if ! grep -Fq "/usr/bin/getgithub.sh" /etc/crontabs/root 2>/dev/null; then
    echo "$CRON_LINE" >> /etc/crontabs/root
    echo "=== Added cron job: 03:45 daily ==="
else
    echo "=== Cron job already exists. Skipped. ==="
fi

# перезапускаем cron
/etc/init.d/cron restart

#############################################
# 5. Запускаем службу сразу
#############################################

echo "=== Running first update ==="
/etc/init.d/getgithub start

echo "=== Installation complete! ==="
echo "File domlist.lst will sync from GitHub at every boot and daily at 03:45."
