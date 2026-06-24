o.bind("SUPER + SPACE", "Launch apps", { omybuntu = "walker" })
o.bind("SUPER + CTRL + E", "Emoji picker", { omybuntu = "walker -m symbols" })
o.bind_menu("SUPER + CTRL + C", "Capture menu", "capture")
o.bind_menu("SUPER + CTRL + O", "Toggle menu", "toggle")
o.bind_menu("SUPER + CTRL + H", "Hardware menu", "hardware")
o.bind_menu("SUPER + ALT + SPACE", "Omybuntu menu", nil)
o.bind_menu("SUPER + SHIFT + code:201", "Omybuntu menu", nil)
o.bind_menu("SUPER + ESCAPE", "System menu", "system")
o.bind_menu("XF86PowerOff", "Power menu", "system", { locked = true })
o.bind("SUPER + K", "Show key bindings", "omybuntu-menu-keybindings")
o.bind("SUPER + ALT + K", "Show Tmux key bindings", "omybuntu-menu-tmux-keybindings")
o.bind("XF86Calculator", "Calculator", "gnome-calculator")

o.bind("SUPER + SHIFT + SPACE", "Toggle top bar", "omybuntu-toggle-waybar")
o.bind("SUPER + SHIFT + CTRL + UP", "Move Waybar to top", "omybuntu-style-waybar-position top")
o.bind("SUPER + SHIFT + CTRL + DOWN", "Move Waybar to bottom", "omybuntu-style-waybar-position bottom")
o.bind("SUPER + SHIFT + CTRL + LEFT", "Move Waybar to left", "omybuntu-style-waybar-position left")
o.bind("SUPER + SHIFT + CTRL + RIGHT", "Move Waybar to right", "omybuntu-style-waybar-position right")
o.bind_menu("SUPER + CTRL + SPACE", "Background switcher", "background")
o.bind_menu("SUPER + SHIFT + CTRL + SPACE", "Theme menu", "theme")
o.bind("SUPER + BACKSPACE", "Toggle window transparency", "omybuntu-hyprland-window-transparency-toggle")
o.bind("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", "omybuntu-hyprland-window-gaps-toggle")
o.bind("SUPER + CTRL + BACKSPACE", "Toggle single-window square aspect", "omybuntu-hyprland-window-single-square-aspect-toggle")

o.bind("SUPER + COMMA", "Dismiss last notification", "makoctl dismiss")
o.bind("SUPER + SHIFT + COMMA", "Dismiss all notifications", "makoctl dismiss --all")
o.bind("SUPER + CTRL + COMMA", "Toggle silencing notifications", "omybuntu-toggle-notification-silencing")
o.bind("SUPER + ALT + COMMA", "Invoke last notification", "makoctl invoke")
o.bind("SUPER + SHIFT + ALT + COMMA", "Restore last notification", "makoctl restore")

o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")
o.bind("SUPER + CTRL + Delete", "Toggle laptop display", "omybuntu-hyprland-monitor-internal toggle")
o.bind("SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", "omybuntu-hyprland-monitor-internal-mirror toggle")
o.bind("switch:on:Lid Switch", nil, "omybuntu-hw-external-monitors && omybuntu-hyprland-monitor-internal off", { locked = true })
o.bind("switch:off:Lid Switch", nil, "omybuntu-hyprland-monitor-internal on", { locked = true })

o.bind("PRINT", "Screenshot", "omybuntu-capture-screenshot")
o.bind_menu("ALT + PRINT", "Screenrecording", "screenrecord")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", "omybuntu-capture-text-extraction")

o.bind_menu("SUPER + CTRL + S", "Share", "share")

o.bind("SUPER + CTRL + PERIOD", "Transcode", "omybuntu-transcode")

o.bind_menu("SUPER + CTRL + R", "Set reminder", "reminder-set")
o.bind("SUPER + CTRL + ALT + R", "Show reminders", "omybuntu-reminder show")
o.bind("SUPER + SHIFT + CTRL + R", "Clear reminders", "omybuntu-reminder clear")

o.bind("SUPER + CTRL + ALT + T", "Show time", "omybuntu-notification-time")
o.bind("SUPER + CTRL + ALT + B", "Show battery remaining", "omybuntu-notification-battery")
o.bind("SUPER + CTRL + ALT + W", "Show weather", "omybuntu-notification-weather")

o.bind("SUPER + CTRL + A", "Audio controls", { omybuntu = "audio" })
o.bind("SUPER + CTRL + B", "Bluetooth controls", { omybuntu = "bluetooth" })
o.bind("SUPER + CTRL + W", "Wifi controls", { omybuntu = "wifi" })
o.bind("SUPER + CTRL + T", "Activity", { tui = "btop" })

o.bind("SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)

o.bind("SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)

o.bind("SUPER + CTRL + L", "Lock system", "omybuntu-system-lock")
