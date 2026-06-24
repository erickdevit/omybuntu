echo "Replace buggy native Zoom client with webapp"

if omybuntu-pkg-present zoom; then
  omybuntu-pkg-drop zoom
  omybuntu-webapp-install "Zoom" https://app.zoom.us/wc/home https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/zoom.png
fi
