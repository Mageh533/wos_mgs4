hook.Add("OnEntityCreated", "MGS4EntitySpawn", function(ent)
    --- Ensure only valve biped models are affected
    if ent:LookupBone("ValveBiped.Bip01_Pelvis") == nil then return end

    --- Only affects players
    ent:SetNW2Bool("animation_playing", false)

    --- CQC Related Variables
    ent:SetNW2Entity("cqc_target", Entity(0))

    ent:SetNW2Bool("is_in_cqc", false)

    --- CQC Level
    --- 0 = None (Only punch punch kick combo)
    --- 1 = Basic (Adds basic throws)
    --- 2 = Advanced (Adds holds and higher stun damage)
    --- 3 = Expert (Adds hold abilities such as the sop scanner and higher stun damage)
    --- 4 = Master (Adds counters anyone with a lower CQC level and maximum stun damage)
    ent:SetNW2Int("cqc_level", 0)

    --- Psyche
    --- If it reaches 0, the entity will be knocked out
    --- Only regenerates when knocked out or if reading a magazine
    ent:SetNW2Float("psyche", 100)

    ---- Last Non-Lethal Damage Type
    --- 0 = Generic Stun
    --- 1 = Tranquilizers
    --- 2 = CQC Stun
    ent:SetNW2Int("last_nonlethal_damage_type", 0)
end)

-- Camera during CQC
hook.Add( "CalcView", "MGS4Camera", function( ply, pos, angles, fov )
    local is_in_anim = ply:GetNW2Bool("animation_playing", false)

    if is_in_anim == false then return end

    local function hide_player_head(bool)
        local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if not bone or bone < 1 then return end

        if bool then
            ply:ManipulateBoneScale(bone, Vector(0,0,0))
        else
            ply:ManipulateBoneScale(bone, Vector(1,1,1))
        end
    end

    local thirdperson = GetConVar("mgs4_actions_in_thirdperson"):GetBool()

    hide_player_head(!thirdperson)

    -- position adjust for each
    
    local head_bone = ply:LookupBone("ValveBiped.Bip01_Head1")
    local head_pos = head_bone and ply:GetBonePosition(head_bone) or pos

    local pelvis_bone = ply:LookupBone("ValveBiped.Bip01_Pelvis")
    local pelvis_pos = pelvis_bone and ply:GetBonePosition(pelvis_bone) or pos
    pelvis_pos = pelvis_pos + Vector(0, 0, 30) -- Adjust pelvis position slightly up

    local view = {
        origin = (thirdperson and pelvis_pos or head_pos) - ( angles:Forward() * (thirdperson and 60 or 0) ),
        angles = angles,
        fov = fov,
        drawviewer = true
    }

    return view
end )

-- Targets for players
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

hook.Add("CalcMainActivity", "!MGS4Anims", function(ply, vel)
    local str = ply:GetNWString('SVAnim')
    local num = ply:GetNWFloat('SVAnimDelay')
    local st = ply:GetNWFloat('SVAnimStartTime')
    if str ~= "" then
        ply:SetCycle((CurTime()-st)/num)
        local current_anim = ply:LookupSequence(str)
        return -1, current_anim
    end
end)
