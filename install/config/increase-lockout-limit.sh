# Increase lockout limit to 10 and decrease timeout to 2 minutes
sudo sed -i 's|^\(auth\s\+required\s\+pam_faillock.so\)\s\+preauth.*$|\1 preauth silent deny=10 unlock_time=120|' "/etc/pam.d/system-auth" 2>/dev/null || true
sudo sed -i 's|^\(auth\s\+\[default=die\]\s\+pam_faillock.so\)\s\+authfail.*$|\1 authfail deny=10 unlock_time=120|' "/etc/pam.d/system-auth" 2>/dev/null || true

# Keep SDDM autologin on pam_permit only; faillock breaks passwordless live boot.
sudo sed -i '/pam_faillock\.so/d' /etc/pam.d/sddm-autologin 2>/dev/null || true
