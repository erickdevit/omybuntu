echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/60-omybuntu-apparmor.conf >/dev/null
echo "kernel.unprivileged_userns_clone=1" | sudo tee -a /etc/sysctl.d/60-omybuntu-apparmor.conf >/dev/null
sudo sysctl --system >/dev/null 2>&1 || true
