#!/bin/bash

DEVICE="$1"
if [[ -z "$DEVICE" ]]; then
  echo "❌ Użycie: $0 SERIAL_URZĄDZENIA"
  exit 1
fi

# Wspólna funkcja do kliknięcia czegokolwiek po fragmencie tekstu
find_partial_text_coordinates() {
  local part="$1"
  local xml="/sdcard/window_dump.xml"

  >&2 echo "[*] Dumpuję aktualny widok UI..."
  adb -s "$DEVICE" shell uiautomator dump "$xml" > /dev/null
  adb -s "$DEVICE" pull "$xml" /tmp/window_dump.xml > /dev/null

  bounds=$(xmllint --xpath "string(//node[contains(translate(@text, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo "$part" | tr '[:upper:]' '[:lower:]')') or contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo "$part" | tr '[:upper:]' '[:lower:]')')]/@bounds)" /tmp/window_dump.xml 2>/dev/null)

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

# Nowa funkcja: klik po resource-id
tap_by_resource_id() {
  local res_id="$1"
  >&2 echo "[*] Szukam elementu z resource-id: $res_id"

  adb -s "$DEVICE" shell uiautomator dump /sdcard/dump.xml > /dev/null
  adb -s "$DEVICE" pull /sdcard/dump.xml /tmp/dump.xml > /dev/null

  bounds=$(xmllint --xpath "string(//*[@resource-id='$res_id']/@bounds)" /tmp/dump.xml 2>/dev/null)

  if [[ -z "$bounds" ]]; then
    echo "❌ Nie znaleziono przycisku z resource-id: $res_id"
    return 1
  fi

  x1=$(echo "$bounds" | cut -d']' -f1 | tr -d '[' | cut -d',' -f1)
  y1=$(echo "$bounds" | cut -d']' -f1 | tr -d '[' | cut -d',' -f2)
  x2=$(echo "$bounds" | cut -d']' -f2 | tr -d '[' | cut -d',' -f1)
  y2=$(echo "$bounds" | cut -d']' -f2 | tr -d '[' | cut -d',' -f2)

  x=$(( (x1 + x2) / 2 ))
  y=$(( (y1 + y2) / 2 ))

  >&2 echo "[*] Klikam: ($x, $y)"
  adb -s "$DEVICE" shell input tap "$x" "$y"
  sleep 2
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

drag_language_to_top() {
  >&2 echo "[*] Przeciągam 'English' na górę listy..."

  coords=$(find_partial_text_coordinates "English")
  if [[ $? -ne 0 ]]; then
    echo "❌ Nie znaleziono 'English' do przeciągnięcia"
    exit 1
  fi

  x=$(echo "$coords" | cut -d' ' -f1)
  y=$(echo "$coords" | cut -d' ' -f2)

  y_target=$((y - 300))
  if [[ $y_target -lt 200 ]]; then
    y_target=200
  fi

  >&2 echo "[*] Swipe z ($x,$y) do ($x,$y_target)"
  adb -s "$DEVICE" shell input swipe "$x" "$y" "$x" "$y_target" 300
  sleep 2
}

# ================ START ================

echo "[*] Otwieram ustawienia języka"
adb -s "$DEVICE" shell am start -a android.settings.LOCALE_SETTINGS
sleep 2

tap_on_text "Dodaj"
tap_on_text "English"
tap_on_text "United"

drag_language_to_top

tap_by_resource_id "android:id/button1"

echo "✅ English (United States) ustawiony jako domyślny"
