#!/bin/sh

# ============================================================
#  Keenetic Router Info — расширенный дашборд
#  Источники: RCI (порт 79) + /proc + /sys
#  Без jq, только grep/awk/sed (POSIX sh, busybox-friendly)
# ============================================================

# --- Цвета ---
C_RESET='\033[0m'
C_GREEN='\033[1;32m'
C_CYAN='\033[1;36m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_WHITE='\033[1;37m'

RCI="http://localhost:79/rci"

# --- Файлы данных (тянем один раз, парсим много) ---
VER_FILE="/tmp/kn_ver.json"
IFACE_FILE="/tmp/kn_iface.json"
SYS_FILE="/tmp/kn_system.json"
NET_FILE="/tmp/kn_inet.json"
HOTSPOT_FILE="/tmp/kn_hotspot.json"

curl -s "$RCI/show/version"          > "$VER_FILE"     2>/dev/null
curl -s "$RCI/show/interface"        > "$IFACE_FILE"   2>/dev/null
curl -s "$RCI/show/system"           > "$SYS_FILE"     2>/dev/null
curl -s "$RCI/show/internet/status"  > "$NET_FILE"     2>/dev/null
curl -s "$RCI/show/ip/hotspot"       > "$HOTSPOT_FILE" 2>/dev/null

# --- Парсер плоского ключа: первое значение "key": "val" ---
get_json_val() {
    grep -o "\"$1\": *\"[^\"]*\"" "$2" 2>/dev/null | head -1 | cut -d'"' -f4
}
# Числовое значение "key": 123  (без кавычек)
get_json_num() {
    grep -o "\"$1\": *[0-9.]*" "$2" 2>/dev/null | head -1 | grep -o '[0-9.]*$'
}

# ============================================================
#  1. СБОР ДАННЫХ — версия
# ============================================================
MODEL_RAW=$(get_json_val "model"   "$VER_FILE")
ARCH=$(get_json_val      "arch"    "$VER_FILE")
RELEASE=$(get_json_val   "release" "$VER_FILE")
TITLE=$(get_json_val     "title"   "$VER_FILE")
SANDBOX=$(get_json_val   "sandbox" "$VER_FILE")
HW_ID=$(get_json_val     "hw_id"   "$VER_FILE")
REGION=$(get_json_val    "region"  "$VER_FILE")
BUILD_DATE=$(grep -A 4 '"ndm":' "$VER_FILE" | grep '"cdate":' | cut -d'"' -f4)

COMPONENTS=$(grep '"components":' "$VER_FILE")
FEATURES=$(grep   '"features":'   "$VER_FILE")

# ============================================================
#  2. ВЕНДОР И ПОРТ (логика без изменений)
# ============================================================
PORT_FLAG=""
VENDOR_DETECTED=""
case "$MODEL_RAW" in
  *Cudy*|*WBR3000*|*TR3000*|*WR3000*)     VENDOR_DETECTED="Cudy";     PORT_FLAG=" [Port]" ;;
  *CMCC*|*RAX3000M*)                      VENDOR_DETECTED="CMCC";     PORT_FLAG=" [Port]" ;;
  *Netis*|*NX31*|*NX32*|*N6*)             VENDOR_DETECTED="Netis";    PORT_FLAG=" [Port]" ;;
  *Redmi*)                                VENDOR_DETECTED="Redmi";    PORT_FLAG=" [Port]" ;;
  *Xiaomi*|*AX3000T*|*3G*|*3P*|*4A*|*4C*) VENDOR_DETECTED="Xiaomi";   PORT_FLAG=" [Port]" ;;
  *Mercusys*)                             VENDOR_DETECTED="Mercusys"; PORT_FLAG=" [Port]" ;;
  *SmartBox*)                             VENDOR_DETECTED="SmartBox"; PORT_FLAG=" [Port]" ;;
  *TP-Link*|*EC330*|*Archer*)             VENDOR_DETECTED="TP-Link";  PORT_FLAG=" [Port]" ;;
  *Linksys*)                              VENDOR_DETECTED="Linksys";  PORT_FLAG=" [Port]" ;;
  *WiFire*)                               VENDOR_DETECTED="WiFire";   PORT_FLAG=" [Port]" ;;
  *Vertell*)                              VENDOR_DETECTED="Vertell";  PORT_FLAG=" [Port]" ;;
  *MTS*|*WG430*)                          VENDOR_DETECTED="MTS";      PORT_FLAG=" [Port]" ;;
  *HLK*)                                  VENDOR_DETECTED="HLK";      PORT_FLAG=" [Port]" ;;
  *Keenetic*)                             VENDOR_DETECTED="Keenetic";;
  *)                                      VENDOR_DETECTED="Keenetic";;
esac

if [ -n "$VENDOR_DETECTED" ] && [ "$VENDOR_DETECTED" != "Keenetic" ]; then
    case "$MODEL_RAW" in
        *"$VENDOR_DETECTED"*) MODEL_DISPLAY="$MODEL_RAW" ;;
        *) MODEL_DISPLAY="$VENDOR_DETECTED $MODEL_RAW" ;;
    esac
else
    MODEL_DISPLAY="$MODEL_RAW"
fi

# ============================================================
#  3. СИСТЕМНЫЕ РЕСУРСЫ
# ============================================================
# CPU модель
if [ "$ARCH" = "mips" ]; then
  CPU_INFO=$(grep 'system type' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm" ]; then
  CPU_INFO=$(grep 'Hardware' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
  [ -z "$CPU_INFO" ] && CPU_INFO=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
else
  CPU_INFO="Unknown"
fi
CPU_DISPLAY="${CPU_INFO} (${ARCH})"

# Загрузка CPU % — из RCI show/system (ключ "cpuload"), fallback на loadavg
CPU_LOAD=$(get_json_num "cpuload" "$SYS_FILE")
[ -z "$CPU_LOAD" ] && CPU_LOAD=$(get_json_num "cpu" "$SYS_FILE")

# RAM из /proc (надёжнее, чем парсить вложенный json)
MEM_TOTAL=$(grep MemTotal     /proc/meminfo | awk '{print int($2/1024)}')
MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
if [ "$MEM_TOTAL" -gt 0 ]; then
    MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))
else
    MEM_PERC=0
fi

# Uptime
UP_SECONDS=$(cut -d. -f1 /proc/uptime)
UP_DAYS=$((UP_SECONDS / 86400))
UP_HOURS=$(( (UP_SECONDS % 86400) / 3600 ))
UP_MINS=$(( (UP_SECONDS % 3600) / 60 ))
UPTIME_STR="${UP_DAYS}d ${UP_HOURS}h ${UP_MINS}m"

LOAD_AVG=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')

# ============================================================
#  4. ТЕМПЕРАТУРЫ  (CPU + Wi-Fi 2.4/5)
# ============================================================
# Wi-Fi: ищем "temperature": N внутри блоков WifiMaster0 / WifiMaster1.
# Парсер блока: вырезаем от "WifiMasterX" до следующей "}," — берём temperature.
get_iface_temp() {
    # $1 = имя интерфейса (WifiMaster0). Возвращает число или пусто.
    awk -v key="\"$1\"" '
        $0 ~ key {found=1}
        found && /"temperature"/ {
            match($0, /"temperature": *[0-9]+/)
            if (RSTART>0){ s=substr($0,RSTART,RLENGTH); gsub(/[^0-9]/,"",s); print s; exit }
        }
        found && /^[[:space:]]*}/ {found=0}
    ' "$IFACE_FILE"
}

TEMP_2=$(get_iface_temp "WifiMaster0")
TEMP_5=$(get_iface_temp "WifiMaster1")

# CPU temp — только там где есть thermal_zone (обычно aarch64)
TEMP_CPU=""
if [ -r /sys/devices/virtual/thermal/thermal_zone0/temp ]; then
    raw=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | tr -d -c '0-9')
    if [ -n "$raw" ] && [ "$raw" -gt 0 ] 2>/dev/null; then
        # значение обычно в милли-°C (45000 -> 45); если уже малое (45) — оставляем
        if [ "$raw" -gt 1000 ]; then TEMP_CPU=$((raw / 1000)); else TEMP_CPU="$raw"; fi
    fi
fi

# Собираем строку температур
TEMP_STR=""
[ -n "$TEMP_CPU" ] && TEMP_STR="CPU: ${TEMP_CPU}°C"
if echo "$TEMP_2" | grep -qE '^[0-9]+$'; then
    if echo "$TEMP_5" | grep -qE '^[0-9]+$'; then
        diff=$((TEMP_5 - TEMP_2)); [ $diff -lt 0 ] && diff=$((-diff))
        if [ $diff -lt 3 ]; then
            WIFI_T="Wi-Fi: ${TEMP_5}°C"
        else
            WIFI_T="2.4G: ${TEMP_2}°C | 5G: ${TEMP_5}°C"
        fi
    else
        WIFI_T="2.4G: ${TEMP_2}°C"
    fi
    [ -n "$TEMP_STR" ] && TEMP_STR="$TEMP_STR | $WIFI_T" || TEMP_STR="$WIFI_T"
fi

# ============================================================
#  5. ИНТЕРНЕТ-СТАТУС
# ============================================================
# show/internet/status -> "internet": true / "gateway-accessible" и т.п.
INET_RAW=$(grep -o '"internet": *[a-z]*' "$NET_FILE" | head -1 | grep -o '[a-z]*$')
case "$INET_RAW" in
    true)  INET_STR="${C_GREEN}● ONLINE${C_RESET}" ;;
    false) INET_STR="${C_RED}● OFFLINE${C_RESET}" ;;
    *)     INET_STR="${C_YELLOW}● неизвестно${C_RESET}" ;;
esac

# WAN-интерфейс: ищем активный с global -> "connected":"yes" и адресом.
# Берём первое "address" после "global". Бест-эффорт, без падений.
WAN_IP=$(grep -o '"address": *"[0-9.]*"' "$IFACE_FILE" | head -1 | cut -d'"' -f4)

# ============================================================
#  6. КЛИЕНТЫ В СЕТИ  (show/ip/hotspot)
# ============================================================
# Считаем активных: количество вхождений "active": true.
CLIENTS_ACTIVE=$(grep -o '"active": *true' "$HOTSPOT_FILE" 2>/dev/null | wc -l | tr -d ' ')
CLIENTS_TOTAL=$(grep -o '"mac": *"' "$HOTSPOT_FILE" 2>/dev/null | wc -l | tr -d ' ')
[ -z "$CLIENTS_ACTIVE" ] && CLIENTS_ACTIVE=0
[ -z "$CLIENTS_TOTAL" ]  && CLIENTS_TOTAL=0

# ============================================================
#  7. USB-НАКОПИТЕЛИ  (/proc/mounts)
# ============================================================
# Ищем смонтированные разделы из /tmp/mnt или /mnt (типичные точки Keenetic).
USB_STR=""
USB_LINES=$(grep -E '^/dev/sd' /proc/mounts 2>/dev/null \
            | grep -E '/tmp/mnt|/run/mnt' \
            | grep -vE 'tmpfs|overlay|squashfs|proc|sysfs')
if [ -n "$USB_LINES" ]; then
    USB_STR=$(echo "$USB_LINES" | while read -r dev mnt fstype rest; do
        # размер из df, бест-эффорт
        size=$(df -h "$mnt" 2>/dev/null | awk 'NR==2{print $3"/"$2" ("$5")"}')
        echo "      ${mnt##*/}: ${fstype} ${size}"
    done)
fi

# ============================================================
#  8. АНАЛИЗ КОМПОНЕНТОВ (как было)
# ============================================================
check_comp() { echo "$COMPONENTS" | grep -q "$1" && echo -n "$2 "; }
check_feat() { echo "$FEATURES"   | grep -q "$1" && echo -n "$2 "; }

VPN_STR=$(
    check_comp "wireguard" "WireGuard"
    check_comp "openvpn"   "OpenVPN"
    check_comp "ipsec"     "IPsec/IKEv2"
    check_comp "l2tp"      "L2TP"
    check_comp "sstp"      "SSTP"
    check_comp "zerotier"  "ZeroTier"
)
STOR_STR=$(
    check_comp "ntfs"  "NTFS"
    check_comp "exfat" "ExFAT"
    check_comp "ext"   "EXT4"
    check_comp "tsmb"  "SMB"
    check_comp "ftp"   "FTP"
)
FEAT_STR=$(
    check_feat "hwnat"    "HW-NAT"
    check_feat "ppe"      "PPE"
    check_feat "wifi5ghz" "Wi-Fi 5GHz"
    check_feat "wpa3"     "WPA3"
    check_feat "usb"      "USB"
)

# ============================================================
#  9. ВЫВОД
# ============================================================
echo "==================================================="
echo -e "   ${C_CYAN}Router Info${C_RESET}"
echo "==================================================="

echo -e "${C_GREEN}📦 Устройство:${C_RESET}"
echo -e "   Модель:      ${C_WHITE}${MODEL_DISPLAY}${C_RED}${PORT_FLAG}${C_RESET}"
echo -e "   HW ID:       ${HW_ID} (Region: ${REGION})"
echo -e "   Процессор:   ${CPU_DISPLAY}"
echo -e "   Память:      ${C_WHITE}${MEM_USED} MB${C_RESET} / ${MEM_TOTAL} MB (${C_YELLOW}${MEM_PERC}%${C_RESET})"
[ -n "$CPU_LOAD" ] && echo -e "   Загрузка:    ${C_YELLOW}${CPU_LOAD}%${C_RESET} CPU"

echo -e "\n${C_GREEN}🌡️  Температура:${C_RESET}"
if [ -n "$TEMP_STR" ]; then
    echo -e "   ${C_WHITE}${TEMP_STR}${C_RESET}"
else
    echo -e "   ${C_YELLOW}датчики недоступны${C_RESET}"
fi

echo -e "\n${C_GREEN}🌐 Сеть:${C_RESET}"
echo -e "   Интернет:    ${INET_STR}"
[ -n "$WAN_IP" ] && echo -e "   WAN IP:      ${C_WHITE}${WAN_IP}${C_RESET}"
echo -e "   Клиенты:     ${C_WHITE}${CLIENTS_ACTIVE}${C_RESET} активно / ${CLIENTS_TOTAL} всего"

echo -e "\n${C_GREEN}⚙️  Система:${C_RESET}"
echo -e "   Версия ПО:   ${C_WHITE}${TITLE}${C_RESET} (${RELEASE})"
echo -e "   Канал:       ${SANDBOX}"
echo -e "   Дата сборки: ${BUILD_DATE}"
echo -e "   Uptime:      ${UPTIME_STR}"
echo -e "   Load Avg:    ${LOAD_AVG}"

if [ -n "$USB_STR" ]; then
    echo -e "\n${C_GREEN}💾 USB-накопители:${C_RESET}"
    echo -e "$USB_STR"
fi

echo -e "\n${C_GREEN}🔌 Компоненты:${C_RESET}"
[ -n "$VPN_STR" ]  && echo -e "   VPN:         ${VPN_STR}"
[ -n "$STOR_STR" ] && echo -e "   Storage:     ${STOR_STR}"
[ -n "$FEAT_STR" ] && echo -e "   Features:    ${FEAT_STR}"

echo "==================================================="

# Чистим временные файлы
rm -f "$VER_FILE" "$IFACE_FILE" "$SYS_FILE" "$NET_FILE" "$HOTSPOT_FILE" 2>/dev/null
