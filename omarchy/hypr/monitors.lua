-- Personal monitor overrides installed by layatai/dev-init.
-- Use the preferred mode at native 1x scale on the automatically placed output.

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
