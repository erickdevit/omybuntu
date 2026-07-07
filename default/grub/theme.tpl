# Omybuntu GRUB Theme - Default Omybuntu Palette
# Theme directory: /boot/grub/themes/omybuntu

# ---- Global ----
title-text: ""
title-font: "unicode.pf2"
title-color: "#f5e6d3"
desktop-color: "#140a05"


# ---- Branding Label ----
+ label {
  text = "Omybuntu"
  font = "unicode.pf2"
  color = "#f59e0b"
  align = "center"
  left = 0%
  top = 8%
  width = 100%
  height = 40
}

+ label {
  text = "{{ grub_select_os }}"
  font = "unicode.pf2"
  color = "#5c4033"
  align = "center"
  left = 0%
  top = 14%
  width = 100%
  height = 24
}

# ---- Boot Menu ----
+ boot_menu {
  left = 30%
  top = 22%
  width = 40%
  height = 60%
  item_font = "unicode.pf2"
  item_color = "#f5e6d3"
  item_height = 36
  item_padding = 8
  item_spacing = 4
  item_icon_space = 10
  selected_item_color = "#f59e0b"
  selected_item_font = "unicode.pf2"
  selected_item_pixmap_style = "select_*.png"
  scrollbar = true
  scrollbar_width = 6
  scrollbar_thumb = "scrollbar_thumb.png"
}

# ---- Progress Bar (for timeout) ----
+ progress_bar {
  id = "__timeout__"
  left = 0%
  top = 97%
  width = 100%
  height = 4
  border_color = "#140a05"
  bg_color = "#140a05"
  fg_color = "#f59e0b"
}

# ---- Footer ----
+ label {
  text = "{{ grub_footer }}"
  font = "unicode.pf2"
  color = "#5c4033"
  align = "center"
  left = 0%
  top = 92%
  width = 100%
  height = 24
}