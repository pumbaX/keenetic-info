Скрипт для просмотра информации о роутере на KeeneticOS (оригинал и порт).
Выводит: модель, процессор, память, версию ПО, аптайм, нагрузку и компоненты (VPN, Storage, Features).
Для чего? Да просто похвастаться железом 😄

```bash
curl -s https://raw.githubusercontent.com/pumbaX/pumbaX/main/kn-info.sh | sh
```


Мои варианты:
```===================================================
   Keenetic Router Info
===================================================
📦 Устройство:
   Модель:      Skipper (KN-1910)
   HW ID:       KN-1910 (Region: EU)
   Процессор:   MediaTek MT7621 SoC (mips)
   Память:      59 MB / 121 MB занято (48%)
⚙️  Система:
   Версия ПО:   5.1 Alpha 3 (5.01.A.3.0-0)
   Канал:       draft
   Дата сборки: 28 Feb 2026
   Uptime:      0d 3h 3m
   Load Avg:    0.06, 0.03, 0.00
🔌 Компоненты:
   VPN:         WireGuard
   Storage:     NTFS ExFAT EXT4 SMB FTP
   Features:    HW-NAT Wi-Fi 5GHz WPA3
===================================================
```
