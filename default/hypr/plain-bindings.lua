require("default.hypr.bindings.media")
require("default.hypr.bindings.clipboard")
require("default.hypr.bindings.tiling-v2")
require("default.hypr.bindings.utilities")

-- Application bindings without Omybuntu's preinstalled web apps, TUIs, or desktop apps.
o.bind("SUPER + RETURN", "Terminal", { omybuntu = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { omybuntu = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { omybuntu = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omybuntu = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { omybuntu = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { omybuntu = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { omybuntu = "editor" })
