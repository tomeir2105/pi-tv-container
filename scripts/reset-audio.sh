#!/usr/bin/env bash

set -eu

AUDIO_OUTPUT_PREFERENCE="${AUDIO_OUTPUT_PREFERENCE:-hdmi}"
AUDIO_VOLUME="${AUDIO_VOLUME:-1.0}"
ALSA_BEEP_DEVICE="${ALSA_BEEP_DEVICE:-default}"
PI_BEEP_SOUND_PATH="${PI_BEEP_SOUND_PATH:-/usr/share/sounds/alsa/Front_Center.wav}"
WPCTL_BIN="${WPCTL_BIN:-wpctl}"

log() {
  printf '%s\n' "$*"
}

find_sink_id() {
  sink_pattern="$1"
  "$WPCTL_BIN" status | sed -n "s/^[[:space:]]*[*[:space:]]*\\([0-9]\\+\\)\\. .*${sink_pattern}.*/\\1/p" | head -n 1
}

if ! command -v "$WPCTL_BIN" >/dev/null 2>&1; then
  log "wpctl_not_found"
  exit 1
fi

case "$AUDIO_OUTPUT_PREFERENCE" in
  hdmi)
    sink_pattern='Digital Stereo \(HDMI\)'
    ;;
  analog)
    sink_pattern='Built-in Audio Stereo'
    ;;
  *)
    sink_pattern=''
    ;;
esac

sink_id=''
if [ -n "$sink_pattern" ]; then
  sink_id="$(find_sink_id "$sink_pattern")"
fi

if [ -z "$sink_id" ]; then
  sink_id="$("$WPCTL_BIN" status | sed -n 's/^[[:space:]]*[*[:space:]]*\([0-9]\+\)\. .*/\1/p' | head -n 1)"
fi

if [ -z "$sink_id" ]; then
  log "sink_not_found"
  exit 1
fi

"$WPCTL_BIN" set-default "$sink_id"
"$WPCTL_BIN" set-volume "$sink_id" "$AUDIO_VOLUME" || true
"$WPCTL_BIN" set-mute "$sink_id" 0 || true

if [ -f "$PI_BEEP_SOUND_PATH" ] && command -v aplay >/dev/null 2>&1; then
  aplay -D "$ALSA_BEEP_DEVICE" "$PI_BEEP_SOUND_PATH" >/dev/null 2>&1 || true
elif command -v speaker-test >/dev/null 2>&1; then
  speaker-test -t sine -f 880 -l 1 >/dev/null 2>&1 || true
fi

log "sink_id=$sink_id"
"$WPCTL_BIN" inspect "$sink_id" | sed -n 's/^[[:space:]]*\\*\\{0,1\\}[[:space:]]*node.description = \"\\(.*\\)\"$/sink_description=\\1/p'
"$WPCTL_BIN" get-volume "$sink_id" | sed 's/^/sink_volume=/'
