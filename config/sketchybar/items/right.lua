local colors = require("colors")

local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function trim(value)
  return (value or ""):match("^%s*(.-)%s*$")
end

local function add_status_item(sbar, name, icon, update_freq)
  return sbar.add("item", name, {
    position = "right",
    update_freq = update_freq,
    icon = { string = icon },
    label = { string = "--" },
  })
end

return function(sbar, config_dir)
  local status_helper = config_dir .. "/helpers/status.sh"
  local status_command = "/bin/bash " .. shell_quote(status_helper)
  local clock = add_status_item(sbar, "clock", "󰥔", 30)
  local battery = add_status_item(sbar, "battery", "󰁹", 120)
  local wifi = add_status_item(sbar, "wifi", "󰤨", 45)
  local disk = add_status_item(sbar, "disk", "󰋊", 120)
  local ram = add_status_item(sbar, "ram", "󰍛", 30)
  local cpu = add_status_item(sbar, "cpu", "󰻠", 15)
  local volume = add_status_item(sbar, "volume", "󰕾", 0)
  local weekdays = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }
  local months = {
    "ene", "feb", "mar", "abr", "may", "jun",
    "jul", "ago", "sep", "oct", "nov", "dic",
  }

  local function update_clock()
    local now = os.date("*t")
    clock:set({
      label = {
        string = string.format(
          "%s %02d %s · %02d:%02d",
          weekdays[now.wday],
          now.day,
          months[now.month],
          now.hour,
          now.min
        ),
      },
    })
  end

  local function set_volume(value)
    local level_text, muted_text = trim(value):match("^(%d+),(%a+)$")
    local level = tonumber(level_text)
    if not level or (muted_text ~= "true" and muted_text ~= "false") then
      volume:set({ label = { string = "--" } })
      return
    end

    level = math.max(0, math.min(100, math.floor(level + 0.5)))
    local muted = muted_text == "true"

    volume:set({
      icon = {
        string = muted and "󰝟" or (level == 0 and "󰖁" or "󰕾"),
        color = muted and colors.warning or colors.accent,
      },
      label = {
        string = muted and "Silencio" or string.format("%d%%", level),
        color = muted and colors.warning or colors.text,
      },
      background = {
        color = muted and colors.surface_strong or colors.surface,
        border_color = muted and colors.warning or colors.border,
      },
    })
  end

  local function query_volume()
    sbar.exec(status_command .. " volume", set_volume)
  end

  local function update_battery()
    sbar.exec(status_command .. " battery", function(result)
      local charge = result and result:match("(%d+)%%")
      if not charge then
        battery:set({ label = { string = "--" } })
        return
      end

      local on_ac_power = result:find("AC Power", 1, true) ~= nil
      local level = math.max(0, math.min(100, tonumber(charge) or 0))
      battery:set({
        icon = { string = on_ac_power and "󰂄" or "󰁹" },
        label = { string = string.format("%d%%", level) },
      })
    end)
  end

  local function set_wifi(value)
    local connected = trim(value) == "connected"
    wifi:set({
      icon = {
        string = connected and "󰤨" or "󰤭",
        color = connected and colors.accent or colors.warning,
      },
      label = { string = connected and "Conectado" or "Sin conexión" },
    })
  end

  local function query_wifi()
    sbar.exec(status_command .. " wifi", set_wifi)
  end

  local function query_percentage(item, metric)
    sbar.exec(status_command .. " " .. metric, function(result)
      local value = tonumber(trim(result))
      if not value then
        item:set({ label = { string = "--" } })
        return
      end

      value = math.max(0, math.min(100, math.floor(value + 0.5)))
      item:set({ label = { string = string.format("%d%%", value) } })
    end)
  end

  clock:subscribe("routine", update_clock)
  volume:subscribe({ "volume_change", "system_woke" }, query_volume)
  battery:subscribe({ "routine", "power_source_change", "system_woke" }, update_battery)
  wifi:subscribe({ "routine", "wifi_change", "system_woke" }, query_wifi)
  disk:subscribe({ "routine", "system_woke" }, function()
    query_percentage(disk, "disk")
  end)
  ram:subscribe({ "routine", "system_woke" }, function()
    query_percentage(ram, "ram")
  end)
  cpu:subscribe({ "routine", "system_woke" }, function()
    query_percentage(cpu, "cpu")
  end)
  volume:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "left" then
      sbar.exec(status_command .. " volume-toggle", set_volume)
    end
  end)
  volume:subscribe("mouse.scrolled", function(env)
    local delta = tonumber(env.SCROLL_DELTA)
    if not delta or delta ~= delta or math.abs(delta) > 1000 or delta == 0 then
      return
    end

    local direction = delta > 0 and "down" or "up"
    sbar.exec(status_command .. " volume-step " .. direction, set_volume)
  end)

  update_clock()
  query_volume()
  update_battery()
  query_wifi()
  query_percentage(disk, "disk")
  query_percentage(ram, "ram")
  query_percentage(cpu, "cpu")
end
