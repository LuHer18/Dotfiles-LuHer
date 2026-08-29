local colors = require("colors")

local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function trim(value)
  return (value or ""):match("^%s*(.-)%s*$")
end

local function truncate(value, max_chars)
  local length = utf8.len(value)
  if not length or length <= max_chars then
    return value
  end

  local boundary = utf8.offset(value, max_chars)
  return value:sub(1, boundary - 1) .. "…"
end

local function media_label(artist, title, max_chars)
  if artist == "" or title == "" then
    return truncate(artist .. title, max_chars)
  end

  local separator = " — "
  local available = max_chars - utf8.len(separator)
  local artist_length = utf8.len(artist) or 0
  local title_length = utf8.len(title) or 0
  local artist_limit = math.min(artist_length, math.floor(available * 0.4))
  local title_limit = math.min(title_length, available - artist_limit)
  artist_limit = math.min(artist_length, available - title_limit)

  return truncate(artist, artist_limit) .. separator .. truncate(title, title_limit)
end

return function(sbar, config_dir)
  local aerospace_helper = config_dir .. "/helpers/aerospace.sh"
  local app_icon_helper = config_dir .. "/helpers/app_icon.sh"
  local media_watcher = config_dir .. "/helpers/media_watcher.py"
  local media_command = shell_quote(media_watcher)
  local workspace_items = {}
  local additional_items = {}
  local overflow
  local expanded = false

  sbar.add("event", "aerospace_workspace_change")
  sbar.add("event", "workspace_overflow_toggle")

  local function update_workspace(workspace, item, focused_workspace)
    local selected = workspace == focused_workspace
    item:set({
      label = { color = selected and colors.dark_text or colors.text },
      background = {
        color = selected and colors.accent or colors.surface,
        border_color = selected and colors.accent_soft or colors.border,
      },
    })
  end

  local function set_expanded(value)
    expanded = value and #additional_items > 0

    for _, entry in ipairs(additional_items) do
      entry.item:set({ drawing = expanded })
    end

    if overflow then
      overflow:set({
        icon = {
          string = expanded and "" or "",
          color = expanded and colors.dark_text or colors.accent,
        },
        background = {
          color = expanded and colors.accent or colors.surface,
          border_color = expanded and colors.accent_soft or colors.border,
        },
      })
    end
  end

  local function select_workspace(focused_workspace)
    if focused_workspace == "" then
      return
    end

    for _, entry in ipairs(additional_items) do
      if entry.workspace == focused_workspace and not expanded then
        set_expanded(true)
        break
      end
    end

    for workspace, item in pairs(workspace_items) do
      update_workspace(workspace, item, focused_workspace)
    end
  end

  for number = 1, 5 do
    local workspace = tostring(number)
    local item = sbar.add("item", "workspace." .. workspace, {
      position = "left",
      icon = { drawing = false },
      label = { string = workspace, padding_left = 9, padding_right = 9 },
      background = { color = colors.surface },
    })

    workspace_items[workspace] = item

    item:subscribe("aerospace_workspace_change", function(env)
      update_workspace(workspace, item, trim(env.FOCUSED_WORKSPACE or env.INFO))
    end)

    item:subscribe("mouse.clicked", function()
      sbar.exec(
        "/bin/bash "
          .. shell_quote(aerospace_helper)
          .. " focus "
          .. shell_quote(workspace)
      )
    end)
  end

  sbar.exec("/bin/bash " .. shell_quote(aerospace_helper) .. " list", function(result)
    local workspaces = {}
    for line in (result or ""):gmatch("[^\r\n]+") do
      local workspace = trim(line)
      if workspace ~= "" and not workspace:match("^[1-5]$") then
        table.insert(workspaces, workspace)
      end
    end

    table.sort(workspaces, function(left, right)
      local left_number = tonumber(left)
      local right_number = tonumber(right)
      if left_number and right_number then
        return left_number < right_number
      elseif left_number then
        return true
      elseif right_number then
        return false
      end
      return left < right
    end)

    for index, workspace in ipairs(workspaces) do
      local item = sbar.add("item", "workspace.additional." .. index, {
        position = "left",
        drawing = false,
        icon = { drawing = false },
        label = { string = workspace, padding_left = 9, padding_right = 9 },
        background = { color = colors.surface },
      })

      workspace_items[workspace] = item
      table.insert(additional_items, { workspace = workspace, item = item })

      item:subscribe("aerospace_workspace_change", function(env)
        select_workspace(trim(env.FOCUSED_WORKSPACE or env.INFO))
      end)
      item:subscribe("mouse.clicked", function()
        sbar.exec(
          "/bin/bash "
            .. shell_quote(aerospace_helper)
            .. " focus "
            .. shell_quote(workspace)
        )
      end)
    end

    overflow = sbar.add("item", "workspace.overflow", {
      position = "left",
      drawing = #additional_items > 0,
      icon = { string = "", padding_left = 8, padding_right = 8 },
      label = { drawing = false },
      background = { color = colors.surface },
    })

    local function toggle_overflow()
      set_expanded(not expanded)
    end

    overflow:subscribe({ "mouse.clicked", "workspace_overflow_toggle" }, toggle_overflow)

    local front_app = sbar.add("item", "front_app", {
      position = "left",
      drawing = false,
      icon = {
        drawing = false,
        font = { family = "sketchybar-app-font", style = "Normal", size = 16.0 },
      },
      label = { string = "", max_chars = 28 },
      background = { color = colors.surface_strong },
    })

    local now_playing = sbar.add("item", "now_playing", {
      position = "left",
      drawing = false,
      icon = { string = "󰎈", color = colors.accent_soft },
      label = { string = "", max_chars = 24 },
      background = { color = colors.surface_strong },
    })

    sbar.add("event", "media_control_update")
    now_playing:subscribe("media_control_update", function(env)
      local state = trim(env.STATE):lower()
      local artist = trim(env.ARTIST)
      local title = trim(env.TITLE)

      if state ~= "playing" or (artist == "" and title == "") then
        now_playing:set({ drawing = false, label = { string = "" } })
        return
      end

      now_playing:set({
        drawing = true,
        label = { string = media_label(artist, title, 24) },
      })
    end)

    local focused_workspace = ""
    local front_app_request = 0

    local function refresh_front_app(workspace)
      workspace = trim(workspace)
      front_app_request = front_app_request + 1
      local request = front_app_request
      focused_workspace = workspace
      front_app:set({
        drawing = false,
        icon = { drawing = false, string = "" },
        label = { string = "" },
      })

      if workspace == "" then
        return
      end

      sbar.exec(
        "/bin/bash "
          .. shell_quote(aerospace_helper)
          .. " front-app "
          .. shell_quote(workspace),
        function(result)
          if request ~= front_app_request or workspace ~= focused_workspace then
            return
          end

          local app = trim(result)
          if app == "" then
            return
          end

          sbar.exec(
            "/bin/bash "
              .. shell_quote(app_icon_helper)
              .. " "
              .. shell_quote(app),
            function(icon_result)
              if request ~= front_app_request or workspace ~= focused_workspace then
                return
              end

              local icon = trim(icon_result)
              if icon == "" then
                icon = ":default:"
              end

              front_app:set({
                drawing = true,
                icon = { drawing = true, string = icon },
                label = { string = app },
              })
            end
          )
        end
      )
    end

    front_app:subscribe("aerospace_workspace_change", function(env)
      local workspace = trim(env.FOCUSED_WORKSPACE or env.INFO)
      select_workspace(workspace)
      refresh_front_app(workspace)
    end)

    front_app:subscribe("front_app_switched", function()
      refresh_front_app(focused_workspace)
    end)

    sbar.exec("/bin/bash " .. shell_quote(aerospace_helper) .. " query", function(focused)
      focused = trim(focused)
      select_workspace(focused)
      refresh_front_app(focused)
    end)
    sbar.exec(media_command .. " start")
  end)
end
