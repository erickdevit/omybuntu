echo "Add Logout option to system menu"

omybuntu-refresh-sddm

if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  sudo sed -i 's/^Current=.*/Current=omybuntu/' /etc/sddm.conf.d/autologin.conf
fi
