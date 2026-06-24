echo "Install socat so we can reactivate internal display when external display is removed"

omybuntu-pkg-add socat
uwsm-app -- omybuntu-hyprland-monitor-watch &
