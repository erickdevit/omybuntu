#!/bin/bash

if [[ -f "$HOME/.local/state/omybuntu/toggles/idle-lock-off" ]]; then
  echo '{"text": "󱫖", "tooltip": "Idle lock disabled", "class": "active"}'
elif ! pgrep -x hypridle >/dev/null; then
  echo '{"text": "󱫖", "tooltip": "Hypridle is not running", "class": "active"}'
else
  echo '{"text": ""}'
fi
