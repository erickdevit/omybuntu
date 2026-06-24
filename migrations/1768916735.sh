echo "Fix microphone gain and audio mixing on Asus ROG laptops"

source "$OMYBUNTU_PATH/install/config/hardware/asus/fix-mic.sh"
source "$OMYBUNTU_PATH/install/config/hardware/asus/fix-audio-mixer.sh"

if omybuntu-hw-asus-rog; then
  omybuntu-restart-pipewire
fi
