include("autorun/sh_mgs4.lua")

-- === Handling the CQC buttons ===
-- Not gonna lie, I have no idea if this is even a good way to do this. It seems to convoluted, but it works so screw it.

hook.Add("PlayerButtonDown", "MGS4PlayerButtonDown", function(ply, button)
    -- Players need to have a client convar set for the CQC button. By default its 110 (Mouse 4)
    local cqc_button = ply:GetInfoNum("mgs4_cqc_button", 110)

    if button == cqc_button then
        ply:SetNW2Bool("cqc_button_held", true)
    end
end)

hook.Add("PlayerButtonUp", "MGS4PlayerButtonUp", function(ply, button)
    local cqc_button = ply:GetInfoNum("mgs4_cqc_button", 110)

    if button == cqc_button then
        ply:SetNW2Bool("cqc_button_held", false)
    end
end)

hook.Add("KeyPress", "MGS4PlayerKeyPress", function(ply, key)
    if key == IN_FORWARD or key == IN_BACK or key == IN_MOVELEFT or key == IN_MOVERIGHT then
        ply:SetNW2Bool("will_grab", false)
    end
end)

hook.Add("KeyRelease", "MGS4PlayerKeyRelease", function(ply, key)
    if key == IN_FORWARD or key == IN_BACK or key == IN_MOVELEFT or key == IN_MOVERIGHT then
        ply:SetNW2Bool("will_grab", true)
    end
end)

-- === Knockout Loop ===
function KnockoutLoop(entity)
    if entity:GetNW2Float("psyche", 100) >= 100 then
        entity:SetNW2Bool("is_knocked_out", false)
        entity:SetNW2Float("psyche", 100)
        entity:GetUp()
    else
        entity:SetNW2Bool("animation_playing", true)
        entity:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
        entity:SetVelocity(-entity:GetVelocity())

        local psyche = entity:GetNW2Float("psyche", 100)
        if psyche < 100 then
            psyche = psyche + GetConVar("mgs4_psyche_recovery"):GetFloat() * FrameTime()
            entity:SetNW2Float("psyche", math.min(psyche, 100)) -- Cap at 100
        end

        if entity:IsPlayer() and entity:KeyPressed(IN_USE) then
            psyche = psyche + GetConVar("mgs4_psyche_recovery_action"):GetFloat()
            entity:SetNW2Float("psyche", math.min(psyche, 100)) -- Cap at 100
        end
    end
end

-- === Initialization ===
hook.Add("OnEntityCreated", "MGS4EntitySpawn", function(ent)
    --- Only affects players
    ent:SetNW2Bool("animation_playing", false)

    ent:SetNW2Bool("will_grab", false)
    ent:SetNW2Entity("cqc_grabbing", Entity(0))

    ent:SetNW2Bool("is_in_cqc", false)
    ent:SetNW2Bool("is_grabbed", false)
    ent:SetNW2Bool("is_choking", false)

    --- Type of CQC action currently performing
    --- 0 = Nothing
    --- 1 = Throw
    --- 2 = Grab loop
    --- 3 = Grab front
    --- 4 = Grab behind
    ent:SetNW2Int("cqc_type", 0)

    --- Each CQC Level grants you:
    --- -2 = Nothing
    --- -1 = Punch punch kick combo
    ---  0 = CQC throw
    ---  1 = (CQC+1) Grabs
    ---  2 = (CQC+2) Higher stun damage
    ---  3 = (CQC+3) Higher stun damage and take weapons from enemies
    ---  4 = (CQCEX) Counter CQC and maximum stun damage
    ent:SetNW2Int("cqc_level", GetConVar("mgs4_base_cqc_level"):GetInt())

    -- How long the player is holding the CQC button for (for knowing if they want to grab or punch)
    ent:SetNW2Bool("cqc_button_held", false)
    ent:SetNW2Float("cqc_button_hold_time", 0)

    -- Time of the punch punch kick combo. Keep pressing to complete the combo, press it once to just punch once.
    ent:SetNW2Float("cqc_punch_time_left", 0)
    ent:SetNW2Int("cqc_punch_combo", 0) -- 1 = First punch, 2 = Second punch, 3 = Kick

    --- Grab abilities, requires at least CQC level 1
    ent:SetNW2Bool("blades3", true)
    ent:SetNW2Bool("scanner3", true)

    --- Psyche
    --- If it reaches 0, the entity will be knocked out
    --- Only regenerates when knocked out or if reading a magazine
    ent:SetNW2Float("psyche", 100)

    ent:SetNW2Bool("is_knocked_out", false)

    ---- Last Non-Lethal Damage Type
    --- 0 = CQC Stun
    --- 1 = Tranquilizers
    --- 2 = Generic Stun
    ent:SetNW2Int("last_nonlethal_damage_type", 0)
end)

-- Cleanup on player death
hook.Add("PostPlayerDeath", "MGS4PlayerDeathCleanup", function(ply)
    ply:SetNW2Bool("animation_playing", false)
    ply:SetNW2Bool("will_grab", false)
    ply:SetNW2Entity("cqc_grabbing", Entity(0))
    ply:SetNW2Bool("is_in_cqc", false)
    ply:SetNW2Bool("is_grabbed", false)
    ply:SetNW2Bool("is_choking", false)
    ply:SetNW2Int("cqc_type", 0)
    ply:SetNW2Int("cqc_level", GetConVar("mgs4_base_cqc_level"):GetInt())
    ply:SetNW2Bool("cqc_button_held", false)
    ply:SetNW2Float("cqc_button_hold_time", 0)
    ply:SetNW2Float("cqc_punch_time_left", 0)
    ply:SetNW2Int("cqc_punch_combo", 0) -- 1 = First punch, 2 = Second punch, 3 = Kick
    ply:SetNW2Bool("blades3", true)
    ply:SetNW2Bool("scanner3", true)
    ply:SetNW2Float("psyche", 100)
    ply:SetNW2Bool("is_knocked_out", false)
    ply:SetNW2Int("last_nonlethal_damage_type", 0)
end)

-- === Non lethal Damage Handling ===
hook.Add("EntityTakeDamage", "MGS4EntityTakeDamage", function(ent, dmginfo)
    if not IsValid(ent) then return end

    -- Check if the entity is a player or NPC
    if ent:IsPlayer() or ent:IsNPC() then
        if ent:GetNW2Bool("is_knocked_out", false) then return end

        if dmginfo:GetDamageType() == DMG_CLUB or dmginfo:GetDamageType() == DMG_SONIC or dmginfo:GetDamageType() == DMG_CRUSH then
            local psyche = ent:GetNW2Float("psyche", 100)
            psyche = psyche - dmginfo:GetDamage() * 2
            ent:SetNW2Float("psyche", math.max(psyche, 0)) -- Cap at 0
            ent:SetNW2Int("last_nonlethal_damage_type", 2) -- Generic stun
        end
    end
end)

-- === Handles systems every tick like grabbing and psyche ===
hook.Add("Tick", "MGS4Tick", function()
    local npc_and_players = ents.FindByClass("player") -- Find all players
    npc_and_players = table.Add(npc_and_players, ents.FindByClass("npc_*")) -- Add all NPCs

    for _, entity in ipairs(npc_and_players) do
        if entity:LookupBone("ValveBiped.Bip01_Pelvis") == nil then return end

        if entity:GetNW2Float("psyche", 100) <= 0 and not entity:GetNW2Bool("is_knocked_out", false) and not entity:GetNW2Bool("animation_playing", false) then
            entity:Knockout() -- Knock out the player silently
        end

        if entity:GetNW2Bool("is_knocked_out", true) then
            KnockoutLoop(entity)
        end

        if entity:GetNW2Bool("cqc_button_held") then
            entity:SetNW2Float("cqc_button_hold_time", entity:GetNW2Float("cqc_button_hold_time", 0) + FrameTime())
        end

        -- Press it once for Punch
        if entity:GetNW2Bool("cqc_button_held", false) == false and entity:GetNW2Float("cqc_button_hold_time", 0) > 0 and entity:GetNW2Float("cqc_button_hold_time", 0) <= 0.5 then
            entity:SetNW2Float("cqc_button_hold_time", 0)
            entity:Cqc_punch()
        end

        -- Hold the button for CQC Throw and Grab
        if entity:GetNW2Float("cqc_button_hold_time", 0) > 0.2 and entity:GetNW2Int("cqc_type", 0) ~= 2 then
            entity:SetNW2Bool("cqc_button_held", false)
            entity:SetNW2Float("cqc_button_hold_time", 0)
            entity:Cqc_check()
        end

        if entity:GetNW2Float("cqc_punch_time_left", 0) > 0 then
            entity:SetNW2Float("cqc_punch_time_left", math.max(entity:GetNW2Float("cqc_punch_time_left", 0) - FrameTime(), 0))
            if entity:GetNW2Float("cqc_punch_time_left", 0) == 0 then
                entity:SetNW2Int("cqc_punch_combo", 0) -- Reset combo
            end
        end

        if entity:GetNW2Entity("cqc_grabbing", Entity(0)) ~= Entity(0) then
            entity:Cqc_loop()
        end

        if entity:GetNW2Bool("animation_playing", true) or entity:GetNW2Bool("is_grabbed", false) then
            if entity:IsPlayer() then
                entity:Freeze(true)
            else
                entity:SetCondition(COND.NPC_FREEZE)
            end
        else
            if entity:IsPlayer() then
                entity:Freeze(false)
            else
                entity:SetCondition(COND.NPC_UNFREEZE)
            end
        end
    end
end)