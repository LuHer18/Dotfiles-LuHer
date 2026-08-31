local colors = require("colors")

return function(sbar)
  sbar.bar({
    height = 34,
    color = colors.background,
    topmost = "window",
    padding_left = 7,
    padding_right = 7,
  })

  sbar.default({
    padding_left = 3,
    padding_right = 3,
    icon = {
      color = colors.accent,
      font = { family = "JetBrainsMono Nerd Font", style = "Bold", size = 14.0 },
      padding_left = 7,
      padding_right = 3,
    },
    label = {
      color = colors.text,
      font = { family = "JetBrainsMono Nerd Font", style = "SemiBold", size = 12.0 },
      padding_left = 3,
      padding_right = 7,
    },
    background = {
      color = colors.surface,
      border_color = colors.border,
      border_width = 1,
      corner_radius = 8,
      height = 26,
    },
  })
end
