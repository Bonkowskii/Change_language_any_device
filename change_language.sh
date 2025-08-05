#!/bin/bash

DEVICE_ID=$1
TARGET_LANGUAGE="English"
TARGET_REGION="United States"
MAX_RETRIES=5
UI_XML="/sdcard/ui_dump.xml"
LOCAL_XML="ui_dump.xml"

if [ -z "$DEVICE_ID" ]; then
  echo "❌ Usage: $0 <DEVICE_ID>"
  exit 1
fi

function dump_ui() {
  adb -s "$DEVICE_ID" shell uiautomator dump "$UI_XML" >/dev/null 2>&1
  adb -s "$DEVICE_ID" pull "$UI_XML" "$LOCAL_XML" >/dev/null 2>&1
  adb -s "$DEVICE_ID" shell rm "$UI_XML" >/dev/null 2>&1
}

function find_coords_by_text_in_id() {
  local id=$1
  local keyword=$2
  local xpath="//node[@resource-id='$id' and (contains(@text,'$keyword') or contains(@content-desc,'$keyword'))]"
  local bounds
  bounds=$(xmllint --xpath "$xpath/@bounds" "$LOCAL_XML" 2>/dev/null | sed 's/.*="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/')

  if [ -z "$bounds" ]; then
    echo ""
    return
  fi

  read x1 y1 x2 y2 <<< "$bounds"
  cx=$(( (x1 + x2) / 2 ))
  cy=$(( (y1 + y2) / 2 ))
  echo "$cx $cy"
}

function find_coords_by_id() {
  local id=$1
  local xpath="//node[@resource-id='$id']"
  local bounds
  bounds=$(xmllint --xpath "$xpath[1]/@bounds" "$LOCAL_XML" 2>/dev/null | sed 's/.*="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/')

  if [ -z "$bounds" ]; then
    echo ""
    return
  fi

  read x1 y1 x2 y2 <<< "$bounds"
  cx=$(( (x1 + x2) / 2 ))
  cy=$(( (y1 + y2) / 2 ))
  echo "$cx $cy"
}

function tap_coords() {
  local coords=$1
  adb -s "$DEVICE_ID" shell input tap $coords
  sleep 1
}

function tap_by_id() {
  local id=$1
  local attempt=1
  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    echo "[*] ($attempt/$MAX_RETRIES) Looking for ID: $id"
    dump_ui
    coords=$(find_coords_by_id "$id")
    if [ -n "$coords" ]; then
      echo "[*] Tapping at $coords (ID: $id)"
      tap_coords "$coords"
      return 0
    fi
    echo "[!] Not found yet, retrying..."
    sleep 1
    attempt=$((attempt + 1))
  done
  echo "❌ Could not tap: $id"
  return 1
}

function tap_by_id_and_keyword() {
  local id=$1
  local keyword=$2
  local attempt=1
  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    echo "[*] ($attempt/$MAX_RETRIES) Looking for ID: $id with text/content: $keyword"
    dump_ui
    coords=$(find_coords_by_text_in_id "$id" "$keyword")
    if [ -n "$coords" ]; then
      echo "[*] Tapping at $coords (ID: $id, keyword: $keyword)"
      tap_coords "$coords"
      return 0
    fi
    echo "[!] Not found yet, retrying..."
    sleep 1
    attempt=$((attempt + 1))
  done
  echo "❌ Could not tap $keyword ($id)"
  return 1
}

echo "[*] Launching language settings"
adb -s "$DEVICE_ID" shell am start -a android.settings.LOCALE_SETTINGS
sleep 2

echo "[*] Tapping 'Add language'"
tap_by_id "com.android.settings:id/add_language" || exit 1

echo "[*] Tapping desired language: $TARGET_LANGUAGE"
tap_by_id_and_keyword "android:id/locale" "$TARGET_LANGUAGE" || exit 1

echo "[*] Tapping desired region: $TARGET_REGION"
tap_by_id_and_keyword "android:id/locale" "$TARGET_REGION" || echo "[!] Region not found, maybe no region list"

echo "[*] Tapping 'Set as default' if shown"
tap_by_id "android:id/button1" || echo "[!] No confirmation dialog"

echo "✅ Language change should be complete"
