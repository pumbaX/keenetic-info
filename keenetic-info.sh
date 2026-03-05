curl -s http://localhost:79/rci/show/version > /tmp/ver.json && \

ARCH=$(grep -o '"arch": *"[^"]*"' /tmp/ver.json | cut -d'"' -f4) && \

if [ "$ARCH" = "mips" ]; then

  CPU=$(cat /proc/cpuinfo | grep 'system type' | head -1 | cut -d: -f2 | xargs) && CPU="$CPU ($ARCH)"

else

  CPU=$ARCH

fi && \

echo "=============================" && \

echo "   Keenetic Router Info" && \

echo "=============================" && \

echo "✅ Модель:    $(grep -o '"model": *"[^"]*"' /tmp/ver.json | cut -d'"' -f4)" && \

echo "✅ Версия ПО: $(grep -o '"title": *"[^"]*"' /tmp/ver.json | cut -d'"' -f4)" && \

echo "✅ Процессор: $CPU" && \

echo "✅ RAM:       $(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}') MB (свободно: $(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}') MB)" && \

echo "============================="
