#!/bin/bash

DEVICE="$1"
if [[ -z "$DEVICE" ]]; then
  echo "❌ Użycie: $0 SERIAL_URZĄDZENIA"
  exit 1
fi

# Wymaga: sudo apt install libxml2-utils
find_partial_text_coordinates() {
  local part="$1"
  local xml="/sdcard/window_dump.xml"

  >&2 echo "[*] Dumpuję aktualny widok UI..."
  adb -s "$DEVICE" shell uiautomator dump "$xml" > /dev/null
  adb -s "$DEVICE" pull "$xml" /tmp/window_dump.xml > /dev/null

  bounds=$(xmllint --xpath "string(//node[contains(translate(@text, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo $part | tr '[:upper:]' '[:lower:]')') or contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo $part | tr '[:upper:]' '[:lower:]')')]/@bounds)" /tmp/window_dump.xml)

  if [[ -z "$bounds" ]]; then
    return 1
  fi

  >&2 echo "[DEBUG] BOUNDS: $bounds"

  x1=$(echo "$bounds" | cut -d']' -f1 | tr -d '[' | cut -d',' -f1)
  y1=$(echo "$bounds" | cut -d']' -f1 | tr -d '[' | cut -d',' -f2)
  x2=$(echo "$bounds" | cut -d']' -f2 | tr -d '[' | cut -d',' -f1)
  y2=$(echo "$bounds" | cut -d']' -f2 | tr -d '[' | cut -d',' -f2)

  x=$(( (x1 + x2) / 2 ))
  y=$(( (y1 + y2) / 2 ))

  echo "$x $y"
  return 0
}

tap_on_text() {
  local label="$1"
  >&2 echo "[*] Szukam: $label"
  coords=$(find_partial_text_coordinates "$label")
  if [[ $? -eq 0 ]]; then
    >&2 echo "[*] Klikam: $coords"
    adb -s "$DEVICE" shell input tap $coords
    sleep 2
  else
    echo "❌ Nie udało się kliknąć: $label"
    exit 1
  fi
}

# ================= START =================

echo "[*] Otwieram ustawienia języka"
adb -s "$DEVICE" shell am start -a android.settings.LOCALE_SETTINGS
sleep 2

tap_on_text "Dodaj"       # Dodaj język
tap_on_text "English"     # Wybór języka
tap_on_text "United"      # Region
tap_on_text "staw"        # Ustaw domyślny / Set as default

echo "✅ English (United States) ustawiony jako domyślny język"
