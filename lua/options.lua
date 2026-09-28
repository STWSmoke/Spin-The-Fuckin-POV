local mod_path = ModPath
local save_path = (rawget(_G, "SavePath") or mod_path) .. "speenpov_settings.txt"
local strings_added = false
local settings = rawget(_G, "SpinPOVSettings") or {}
_G.SpinPOVSettings = settings

local defaults = {
    enabled = true,
    cop_angle = 10,
    civilian_angle = 30
}

local function clamp_angle(value, default_value)
    value = tonumber(value)
    if not value then
        return default_value
    end

    return math.floor(math.max(-360, math.min(360, value)))
end

local function sync_mod_settings()
    local mod = rawget(_G, "SpinPOV")
    if not mod then
        return
    end

    mod.enabled = settings.enabled
    mod.cop_angle = settings.cop_angle
    mod.civilian_angle = settings.civilian_angle

    if not mod.enabled and type(mod.ResetOrientation) == "function" then
        mod:ResetOrientation()
    end
end

local function load_settings()
    for key, default_value in pairs(defaults) do
        if settings[key] == nil then
            settings[key] = default_value
        end
    end

    local file = io.open(save_path, "r")
    if file then
        local contents = file:read("*all") or ""
        file:close()

        local ok, decoded = pcall(json.decode, contents)
        if ok and type(decoded) == "table" then
            if type(decoded.enabled) == "boolean" then
                settings.enabled = decoded.enabled
            end
            settings.cop_angle = clamp_angle(decoded.cop_angle, settings.cop_angle)
            settings.civilian_angle = clamp_angle(decoded.civilian_angle, settings.civilian_angle)
        end
    end

    sync_mod_settings()
end

local function save_settings()
    local file = io.open(save_path, "w+")
    if file then
        file:write(json.encode({
            enabled = settings.enabled,
            cop_angle = settings.cop_angle,
            civilian_angle = settings.civilian_angle
        }))
        file:close()
    else
        log("[SpinPOV] Could not save settings: " .. save_path)
    end
end

_G.SpinPOVSettings_Load = load_settings

local function add_localized_strings(localization)
    if not localization or strings_added then
        return
    end

    strings_added = true
    localization:add_localized_strings({
        spinpov_options_menu_title = "Spin the fuckin POV",
        spinpov_options_menu_desc = "Configure camera rotation on kills.",
        spinpov_enabled_title = "Enable Spin POV",
        spinpov_enabled_desc = "Enable or disable camera rotation on kills.",
        spinpov_cop_angle_title = "Rotation per cop kill",
        spinpov_cop_angle_desc = "Camera roll added for each cop kill.",
        spinpov_civilian_angle_title = "Rotation per civilian kill",
        spinpov_civilian_angle_desc = "Camera roll added for each civilian kill."
    })
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_SpinPOV", function(localization)
    add_localized_strings(localization)
end)

Hooks:Add("MenuManagerInitialize", "SpinPOV_MenuManagerInitialize", function()
    load_settings()

    if managers and managers.localization then
        add_localized_strings(managers.localization)
    end

    MenuCallbackHandler.spinpov_enabled_changed = function(self, item)
        settings.enabled = item:value() == "on"
        sync_mod_settings()
        save_settings()
    end

    MenuCallbackHandler.spinpov_cop_angle_changed = function(self, item)
        settings.cop_angle = clamp_angle(item:value(), defaults.cop_angle)
        sync_mod_settings()
        save_settings()
    end

    MenuCallbackHandler.spinpov_civilian_angle_changed = function(self, item)
        settings.civilian_angle = clamp_angle(item:value(), defaults.civilian_angle)
        sync_mod_settings()
        save_settings()
    end

    MenuCallbackHandler.spinpov_options_save = function()
        save_settings()
    end

    local options_path = mod_path .. "menu/options.json"
    local options_file = io.open(options_path, "r")
    if not options_file then
        log("[SpinPOV] Options file not found: " .. options_path)
        return
    end

    options_file:close()
    log("[SpinPOV] Loading mod options")
    MenuHelper:LoadFromJsonFile(options_path, settings, settings)
end)