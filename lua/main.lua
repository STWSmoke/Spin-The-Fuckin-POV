SpinPOV = SpinPOV or {}

local load_saved_settings = rawget(_G, "SpinPOVSettings_Load")
if type(load_saved_settings) == "function" then
    load_saved_settings()
end

local saved_settings = rawget(_G, "SpinPOVSettings") or {}

SpinPOV.kills = 0
SpinPOV.enabled = saved_settings.enabled
if SpinPOV.enabled == nil then
    SpinPOV.enabled = true
end

SpinPOV.cop_angle = saved_settings.cop_angle or 10
SpinPOV.civilian_angle = saved_settings.civilian_angle or 30

SpinPOV.target_tilt = 0

function SpinPOV:ResetOrientation()
    local current_tilt = tonumber(self.target_tilt) or 0
    local neutral_tilt = math.floor(current_tilt / 360 + 0.5) * 360

    if neutral_tilt == current_tilt and math.abs(current_tilt) >= 360 then
        neutral_tilt = current_tilt - (current_tilt > 0 and 360 or -360)
    end

    self.target_tilt = neutral_tilt
end

log("[SpinPOV] main.lua loaded")

local function is_downed_state(state_name)
    return state_name == "bleed_out"
        or state_name == "fatal"
        or state_name == "arrested"
        or state_name == "incapacitated"
end

local function is_local_player_downed()
    local player_unit = managers.player and managers.player:player_unit()
    return player_unit and player_unit:movement():downed()
end

Hooks:PreHook(PlayerMovement, "change_state", "SpinPOV_ResetTiltOnDown", function(self, state_name)
    if not SpinPOV.enabled or self._unit ~= managers.player:player_unit() or not is_downed_state(state_name) then
        return
    end

    SpinPOV.target_tilt = 0

    local camera_unit = self._unit:camera():camera_unit()
    local camera_base = camera_unit and camera_unit:base()
    local camera_properties = camera_base and camera_base._camera_properties

    if camera_properties then
        camera_properties.target_tilt = 0
        camera_properties.current_tilt = 0
    end
end)


---------------------------------------------------------------
-- AJOUT DE ROTATION
---------------------------------------------------------------

function SpinPOV:AddRotation(amount)

    if not self.enabled then
        return
    end

    SpinPOV.target_tilt = SpinPOV.target_tilt + amount

    log(
        "[SpinPOV] Roll +" ..
        amount ..
        " | Target roll: " ..
        SpinPOV.target_tilt
    )

end


function SpinPOV:IsLocalPlayerOrSentry(attacker)
    local player = managers.player:player_unit()

    if not player or not attacker then
        return false
    end

    if attacker == player then
        return true
    end

    if not alive(attacker) then
        return false
    end

    local attacker_base = attacker:base()
    if not attacker_base or not attacker_base.sentry_gun or type(attacker_base.get_owner_id) ~= "function" then
        return false
    end

    local session = managers.network and managers.network:session()
    local local_peer = session and session:local_peer()
    local owner_id = attacker_base:get_owner_id()

    if owner_id and local_peer and owner_id == local_peer:id() then
        return true
    end

    return type(attacker_base.get_owner) == "function" and attacker_base:get_owner() == player
end


---------------------------------------------------------------
-- FLICS
---------------------------------------------------------------

Hooks:PostHook(
    CopDamage,
    "die",
    "SpinPOV_CopKill",
    function(self, attack_data)

        if not SpinPOV.enabled then
            return
        end

        if not attack_data then
            return
        end

        local attacker = attack_data.attacker_unit

        if not attacker then
            return
        end

        if not SpinPOV:IsLocalPlayerOrSentry(attacker) then
            return
        end

        SpinPOV.kills = SpinPOV.kills + 1

        log(
            "[SpinPOV] COP KILL #" ..
            SpinPOV.kills
        )

        SpinPOV:AddRotation(SpinPOV.cop_angle)

    end
)


---------------------------------------------------------------
-- CIVILS
---------------------------------------------------------------

Hooks:PostHook(
    CivilianDamage,
    "_on_damage_received",
    "SpinPOV_CivilianKill",
    function(self, damage_info)

        if not SpinPOV.enabled then
            return
        end

        if not damage_info then
            return
        end

        if not damage_info.result then
            return
        end

        if damage_info.result.type ~= "death" then
            return
        end

        local attacker = damage_info.attacker_unit

        if not attacker then
            return
        end

        if not SpinPOV:IsLocalPlayerOrSentry(attacker) then
            return
        end

        SpinPOV.kills = SpinPOV.kills + 1

        log(
            "[SpinPOV] CIVILIAN KILL #" ..
            SpinPOV.kills
        )

        SpinPOV:AddRotation(SpinPOV.civilian_angle)

    end
)


---------------------------------------------------------------
-- APPLICATION DU ROLL
---------------------------------------------------------------

Hooks:PostHook(
    FPCameraPlayerBase,
    "update",
    "SpinPOV_ApplyTilt",
    function(self, unit, t, dt)

        if not self._camera_properties then
            return
        end

        if not SpinPOV.enabled then
            return
        end

        if is_local_player_downed() then
            return
        end

        self._camera_properties.target_tilt =
            SpinPOV.target_tilt

    end
)