#!/bin/bash
set -e
echo "Instalando dependencias do Quickshell..."
sudo apt-get install -y cmake ninja-build build-essential pkg-config libglib2.0-dev libpam0g-dev libpipewire-0.3-dev libwayland-dev wayland-protocols qt6-base-dev qt6-declarative-dev qt6-declarative-private-dev qt6-wayland-dev qt6-svg-dev libdrm-dev spirv-tools qt6-shadertools-dev libxcb1-dev libxcb-util0-dev libgbm-dev libcli11-dev libjemalloc-dev libpolkit-agent-1-dev libvulkan-dev libunwind-dev
cd /tmp
if [ ! -d "quickshell" ]; then
  git clone https://github.com/outfoxxed/quickshell
fi
cd quickshell
git pull
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DVENDOR_CPPTRACE=ON
cmake --build build
sudo cmake --install build
echo "Quickshell compilado e instalado com sucesso!"
