include("autorun/sh_mgs4.lua")

-- === CQC ===
function Cqc_check(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local is_in_cqc = ply:GetNW2Bool("is_in_cqc", false)
    local cqc_target = ply:GetNW2Entity("cqc_target", Entity(0))
    local cqc_level = ply:GetNW2Int("cqc_level", 1)

    local will_grab = true -- Temp, will figure out how to handle grab controls later

    if is_in_cqc or cqc_level < 0 then return end

    if (ply:IsOnGround() and !IsValid(cqc_target)) or (cqc_target:GetNW2Bool("is_in_cqc", false) or cqc_target:GetNW2Bool("is_knocked_out", false)) then
        Cqc_fail(ply)
    elseif ply:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() and will_grab and cqc_level >= 1 and !cqc_target:GetNW2Bool("is_in_cqc", false) and !cqc_target:GetNW2Bool("is_knocked_out", false) then
        Cqc_grab(ply, cqc_target)
    elseif ply:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() and !cqc_target:GetNW2Bool("is_in_cqc", false) and !cqc_target:GetNW2Bool("is_knocked_out", false) then
        Cqc_throw(ply, cqc_target)
    end
end

-- Fail, play anim to punish the player
function Cqc_fail(ply)
    local crouched = ply:Crouching()
    if crouched then
        ply:SetSVAnimation("mgs4_cqc_fail_crouched", true)
    else
        ply:SetSVAnimation("mgs4_cqc_fail", true)
    end

    ply:SetNW2Bool("is_in_cqc", true)

    ply:SVAnimationPrep("mgs4_cqc_fail", function()
        ply:SetNW2Bool("is_in_cqc", false)
    end)

end

-- CQC Throw mechanic
function Cqc_throw(ply, target)
    ply:SetNW2Bool("is_in_cqc", true)
    ply:SetNW2Entity("cqc_grabbing", target)
    ply:SetNW2Int("cqc_type", 1)

    ply:SVAnimationPrep("mgs4_cqc_throw", function()
        ply:SetNW2Bool("is_in_cqc", false)
        ply:SetNW2Entity("cqc_grabbing", Entity(0))
    end)

    target:SetNW2Int("last_nonlethal_damage_type", 0)

    target:SVAnimationPrep("mgs4_cqc_throw_victim", function()
        target:SetNW2Bool("is_in_cqc", false)

        -- CQC level stun damage
        local cqc_level = ply:GetNW2Int("cqc_level", 4)
        local stun_damage = 25 * cqc_level

        local target_psyche = target:GetNW2Float("psyche", 100)

        target:SetNW2Float("psyche", target_psyche - stun_damage)

    end)
    
    ply:SetSVAnimation("mgs4_cqc_throw", true)
    target:SetSVAnimation("mgs4_cqc_throw_victim", true)

end

-- CQC grab mechanic
function Cqc_grab(ply, target)
    if not IsValid(ply) or not IsValid(target) then return end

    ply:SetNW2Bool("is_in_cqc", true)
    ply:SetNW2Entity("cqc_grabbing", target)

    target:SetNW2Bool("is_in_cqc", true)
    
    -- Find out if grabbing from front or back
    local vec = ( ply:GetPos() - target:GetPos() ):GetNormal():Angle().y
    local targetAngle = target:EyeAngles().y
    
    if targetAngle > 360 then
        targetAngle = targetAngle - 360
    end
    if targetAngle < 0 then
        targetAngle = targetAngle + 360
    end
    
    local angleAround = vec - targetAngle
    
    if angleAround > 360 then
        angleAround = angleAround - 360
    end
    if angleAround < 0 then
        angleAround = angleAround + 360
    end

    if angleAround > 135 and angleAround <= 225 then
        -- Grabbing from back
        ply:SetNW2Int("cqc_type", 4)
        ply:SVAnimationPrep("mgs4_grab_behind", function ()
            ply:SetNW2Int("cqc_type", 2)
        end)
        target:SVAnimationPrep("mgs4_grabbed_behind", function (ent)
            ent:SetNW2Bool("is_grabbed", true)
        end)

        ply:SetSVAnimation("mgs4_grab_behind", true)
        target:SetSVAnimation("mgs4_grabbed_behind", true)
    else
        -- Grabbing from front
        ply:SetNW2Int("cqc_type", 3)
        ply:SVAnimationPrep("mgs4_grab_front", function ()
            ply:SetNW2Int("cqc_type", 2)
        end)
        target:SVAnimationPrep("mgs4_grabbed_front", function (ent)
            ent:SetNW2Bool("is_grabbed", true)
        end)

        ply:SetSVAnimation("mgs4_grab_front", true)
        target:SetSVAnimation("mgs4_grabbed_front", true)
    end
end

function Cqc_loop(ply, type)
    if not IsValid(ply) then return end

    local target = ply:GetNW2Entity("cqc_grabbing", Entity(0))
    if not IsValid(target) then return end

    if type == "" then return end

    -- If target or player dies, stop the loop
    if not target:Alive() or not ply:Alive() then
        ply:SetNW2Entity("cqc_grabbing", Entity(0))
        ply:SetNW2Bool("is_in_cqc", false)
        target:SetNW2Bool("is_in_cqc", false)
        return
    end

    if type == 1 then
        -- Ensure target is facing the player
        local player_pos = ply:GetPos()
        local player_angle = ply:GetAngles()
        
        target:SetPos(player_pos + (player_angle:Forward() * 30)) -- Move the target slightly forward
        target:SetAngles(player_angle)

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
        end
    elseif type == 2 then
        local player_pos = ply:GetPos()
        local player_angle = ply:GetAngles()
        
        target:SetPos(player_pos + (player_angle:Forward() * 10)) -- Move the target slightly forward
        target:SetAngles(player_angle)

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle) -- Set the target's eye angles to face the player
        end
    elseif type == 4 then
        -- Ensure target is facing the player
        local player_pos = ply:GetPos()
        local player_angle = ply:GetAngles()

        target:SetPos(player_pos) -- Move the target slightly forward
        target:SetAngles(player_angle)

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle) -- Set the target's eye angles to face the player
        end
    elseif type == 3 then
        -- Ensure target is facing the player
        local player_pos = ply:GetPos()
        local player_angle = ply:GetAngles()

        target:SetPos(player_pos) -- Move the target slightly forward
        target:SetAngles(player_angle + Angle(0, 180, 0))

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
        end
    end

end

-- === Custom commands and keys ===
concommand.Add("mgs4_cqc_throw", Cqc_check)

-- === Knockout Loop ===
function KnockoutLoop(entity)
    if entity:GetNW2Float("psyche", 100) >= 100 then
        entity:SetNW2Bool("is_knocked_out", false)
        entity:SetNW2Float("psyche", 100)

        if entity:GetNW2Int("last_nonlethal_damage_type", 0) == 0 then
            entity:SVAnimationPrep("mgs4_stun_recover_faceup")
            entity:SetSVAnimation("mgs4_stun_recover_faceup", true)
        elseif entity:GetNW2Int("last_nonlethal_damage_type", 0) == 1 then
            entity:SVAnimationPrep("mgs4_sleep_recover_facedown")
            entity:SetSVAnimation("mgs4_sleep_recover_facedown", true)
        else
            entity:SVAnimationPrep("mgs4_stun_recover_facedown")
            entity:SetSVAnimation("mgs4_stun_recover_facedown", true)
        end

        if entity:IsPlayer() then
            entity:SetCollisionGroup(COLLISION_GROUP_PLAYER)
        else
            entity:SetCollisionGroup(COLLISION_GROUP_NPC)
        end

    else
        entity:SetNW2Bool("animation_playing", true)

        entity:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

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

    --- CQC Related Variables
    ent:SetNW2Entity("cqc_target", Entity(0))

    ent:SetNW2Entity("cqc_grabbing", Entity(0))

    ent:SetNW2Bool("is_in_cqc", false)
    ent:SetNW2Bool("is_grabbed", false)

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

    --- Grab abilities, requires at least CQC level 1
    ent:SetNW2Bool("blades3", false)
    ent:SetNW2Bool("scanner3", false)

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
    ply:SetNW2Entity("cqc_target", Entity(0))
    ply:SetNW2Entity("cqc_grabbing", Entity(0))
    ply:SetNW2Bool("is_in_cqc", false)
    ply:SetNW2Bool("is_grabbed", false)
    ply:SetNW2Int("cqc_type", 0)
    ply:SetNW2Int("cqc_level", GetConVar("mgs4_base_cqc_level"):GetInt())
    ply:SetNW2Bool("blades3", false)
    ply:SetNW2Bool("scanner3", false)
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

-- === Targets for players ===
hook.Add("PlayerPostThink", "MGS4CQCCheck", function(ply)
    -- Check if entity in front is a valid target
    local trace = ply:GetEyeTrace()
    if trace.Entity:LookupBone("ValveBiped.Bip01_Pelvis") == nil then
        ply:SetNW2Entity("cqc_target", Entity(0))
        return
    end

    local cqc_target = trace.Entity

    -- Ensure its relatively close

    if trace.HitPos:DistToSqr(ply:GetPos()) > 5000 then
        ply:SetNW2Entity("cqc_target", Entity(0))
        return
    end

    ply:SetNW2Entity("cqc_target", cqc_target)
end)

-- === Psyche Check ===
hook.Add("Tick", "MGS4PsycheCheck", function()
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

        if entity:GetNW2Entity("cqc_grabbing", Entity(0)) ~= Entity(0) then
            Cqc_loop(entity, entity:GetNW2Int("cqc_type", 0))
        end

        if entity:GetNW2Bool("animation_playing", true) then
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