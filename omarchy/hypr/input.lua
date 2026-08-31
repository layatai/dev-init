-- Personal input overrides installed by layatai/dev-init.

hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
    },
  },
})

-- Three-finger horizontal swipe changes workspaces.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
