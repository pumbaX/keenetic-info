#!/bin/sh
# ============================================================
#  Installer для kn-info / kss
#  Запуск одной строкой:
#    curl -fsSL https://raw.githubusercontent.com/pumbaX/keenetic-info/main/install.sh | sh
#  После установки: kss   (показать)  |  kss update  (обновить)
# ============================================================

RAW_URL="https://raw.githubusercontent.com/pumbaX/keenetic-info/main/kn-info.sh"
BIN="/opt/bin/kss"
LOCAL="/opt/share/kn-info.sh"

echo "==> Установка kss..."

# 0) Проверка окружения
if [ ! -d /opt/bin ]; then
    echo "[!] /opt/bin не найден. Нужен Entware/OPKG. Прерываю."
    exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
    echo "[!] curl не установлен. Поставь: opkg install curl"
    exit 1
fi

mkdir -p /opt/share

# 1) Скачиваем сам скрипт в локальную копию
echo "==> Загрузка скрипта из репозитория..."
if curl -fsSL "$RAW_URL" -o "$LOCAL.tmp"; then
    if head -1 "$LOCAL.tmp" | grep -q '^#!'; then
        mv "$LOCAL.tmp" "$LOCAL"
        echo "[ok] скрипт сохранён: $LOCAL"
    else
        rm -f "$LOCAL.tmp"
        echo "[!] скачан невалидный файл (404? проверь URL). Прерываю."
        exit 1
    fi
else
    rm -f "$LOCAL.tmp"
    echo "[!] не удалось скачать скрипт. Проверь интернет/URL. Прерываю."
    exit 1
fi

# 2) Создаём команду-враппер kss
cat > "$BIN" << 'KSSWRAP'
#!/bin/sh
# kss — дашборд роутера.
#   kss          показать инфо (локальная копия, работает офлайн)
#   kss update   обновить скрипт из репозитория
RAW_URL="https://raw.githubusercontent.com/pumbaX/keenetic-info/main/kn-info.sh"
LOCAL="/opt/share/kn-info.sh"

if [ "$1" = "update" ]; then
    echo "Обновление из репозитория..."
    if curl -fsSL "$RAW_URL" -o "$LOCAL.tmp"; then
        if head -1 "$LOCAL.tmp" | grep -q '^#!'; then
            mv "$LOCAL.tmp" "$LOCAL"
            echo "[ok] обновлено: $LOCAL"
        else
            rm -f "$LOCAL.tmp"
            echo "[!] невалидный файл (404?), прежняя версия сохранена"
            exit 1
        fi
    else
        rm -f "$LOCAL.tmp"
        echo "[!] ошибка загрузки (нет интернета?)"
        exit 1
    fi
    exit 0
fi

if [ -f "$LOCAL" ]; then
    sh "$LOCAL"
else
    echo "[!] копия не найдена: $LOCAL — выполни: kss update"
    exit 1
fi
KSSWRAP

chmod +x "$BIN"

echo ""
echo "============================================"
echo "  [ok] Установлено!"
echo "  Команды:  kss   |   kss update"
echo "============================================"
echo ""

# 3) Сразу показываем результат
sh "$LOCAL"
