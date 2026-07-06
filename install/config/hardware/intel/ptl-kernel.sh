# Install Panther Lake kernel support for Dell XPS Panther Lake systems on Ubuntu
if omybuntu-hw-match "XPS" && omybuntu-hw-intel-ptl; then
  echo "Detected Dell XPS Panther Lake, installing OEM kernel..."

  omybuntu-pkg-add linux-oem-24.04
fi
