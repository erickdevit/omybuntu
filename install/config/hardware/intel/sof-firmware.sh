# Install Sound Open Firmware for the audio DSP on non-XPS Intel Panther
# Lake systems. XPS PTL stays on linux-ptl, which hard-deps sof-firmware.
# Mainline `linux` only optdeps it, so without this the DSP fails to boot
# and only auto_null shows up in PipeWire.

if omybuntu-hw-intel-ptl && ! omybuntu-hw-match "XPS"; then
  omybuntu-pkg-add sof-firmware
fi
