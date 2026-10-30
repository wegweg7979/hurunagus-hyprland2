-- Hurunagus: default every machine to a 1080p logical desktop.
--
-- Omarchy's shipped default is `preferred` with GDK_SCALE=2 and monitor scale
-- "auto". We pin 1920x1080 at 1x instead, so the desktop always starts at
-- 1080p regardless of what the display advertises.

hl.env("GDK_SCALE", "1")
hl.monitor({ output = "", mode = "1920x1080", position = "auto", scale = 1 })

-- Configure a specific monitor (find the name with `hyprctl monitors all`).
-- hl.monitor({ output = "DP-1", mode = "1920x1080", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90 degrees, 3 = 270).
-- hl.monitor({ output = "DP-2", mode = "1920x1080", position = "auto", scale = 1, transform = 1 })
