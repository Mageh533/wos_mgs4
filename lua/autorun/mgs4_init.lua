local ent = FindMetaTable("Entity")

-- === Animation Helpers (Thanks to Hari and NizcKM) ===
function ent:SetSVAnimation(anim, autostop)
    if not self then return end

    self:SetNWString('SVAnim', anim)
    self:SetNWFloat('SVAnimDelay', select(2, self:LookupSequence(anim)))
    self:SetNWFloat('SVAnimStartTime', CurTime())
    self:SetCycle(0)
    if autostop then
        local delay = select(2, self:LookupSequence(anim))
        timer.Simple(delay, function()
            if !IsValid(self) then return end

            local anim2 = self:GetNWString('SVAnim')

            if anim == anim2 then
                self:SetSVAnimation("")
            end
        end)
    end
end

function ent:SVAnimationPrep(anim, callback)
    if not self then return end
    
    local current_anim = self:LookupSequence(anim)
    local duration = self:SequenceDuration(current_anim)

    local prevWeapon
    local prevWeaponClass

    self:SetNW2Bool("animation_playing", true)

    local current_pos = self:GetPos()
    local current_ang = self:GetAngles()
    
    local pelvis_pos
    local pelvis_ang

    if self:IsPlayer() then
        prevWeapon = self:GetActiveWeapon()
        if prevWeapon:IsValid() then
            prevWeaponClass = prevWeapon:GetClass()
            self:SetActiveWeapon( NULL )
        end
        current_ang = self:LocalEyeAngles()
    end

    self:SetVelocity(-self:GetVelocity())

    -- Get the bone positions from before the animation ends
    timer.Simple(duration - 0.1, function()
        local pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
        pelvis_pos = pelvis_matrix:GetTranslation()
        pelvis_ang = pelvis_matrix:GetAngles()
    end)

    timer.Simple(duration, function()
        self:SetPos(Vector(pelvis_pos.x, pelvis_pos.y, current_pos.z))
        
        if self:IsPlayer() then
            if ( !prevWeapon:IsValid() ) then
                prevWeapon = self:Give( prevWeaponClass )
            end

            self:SelectWeapon( prevWeapon )
            self:SetEyeAngles(Angle(current_ang.p, current_ang.y, current_ang.r))
        else
            self:SetAngles(Angle(current_ang.p, pelvis_ang.y, current_ang.r))
        end

        self:SetNW2Bool("animation_playing", false)

        if callback and type(callback) == "function" then
            callback(self)
        end

    end)
end

-- === Knockout ===

function ent:Knockout()
    if not self then return end

    self:SetNW2Bool("is_knocked_out", true)

    local knockout_type = self:GetNW2Int("last_nonlethal_damage_type", 0)
    local crouched

    if self:IsPlayer() then
        crouched = self:Crouching()
    else
        crouched = false
    end

    if knockout_type == 1 then
        if crouched then
            self:SVAnimationPrep("mgs4_sleep_crouched")
            self:SetSVAnimation("mgs4_sleep_crouched", true)
        else
            self:SVAnimationPrep("mgs4_sleep")
            self:SetSVAnimation("mgs4_sleep", true)
        end
    elseif knockout_type == 2 then
        if crouched then
            self:SVAnimationPrep("mgs4_stun_crouched")
            self:SetSVAnimation("mgs4_stun_crouched", true)
        else
            self:SVAnimationPrep("mgs4_stun")
            self:SetSVAnimation("mgs4_stun", true)
        end
    end
end

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
    ent:SetNW2Int("cqc_level", 4)

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

-- === Camera ===
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
    local head_pos = ply:GetAttachment(ply:LookupAttachment("eyes")).Pos
    local head_angle = ply:GetAttachment(ply:LookupAttachment("eyes")).Ang

    local pelvis_bone = ply:LookupBone("ValveBiped.Bip01_Pelvis")
    local pelvis_pos = pelvis_bone and ply:GetBonePosition(pelvis_bone) or pos
    pelvis_pos = pelvis_pos + Vector(0, 0, 30) -- Adjust pelvis position slightly up

    local view = {
        origin = (thirdperson and pelvis_pos or head_pos) - ( angles:Forward() * (thirdperson and 60 or 0) ),
        angles = (thirdperson and angles or Angle(head_angle.p, head_angle.y, 0)),
        fov = fov,
        drawviewer = true
    }

    return view
end )

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

        if entity:GetNW2Float("psyche", 100) <= 0 and not entity:GetNW2Bool("is_knocked_out", false) then
            entity:Knockout() -- Knock out the player silently
        end

        if entity:GetNW2Bool("is_knocked_out", true) then
            KnockoutLoop(entity)
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

-- === Animation Handling for players ===

hook.Add("CalcMainActivity", "!MGS4Anims", function(ply, vel)
    if ply:GetNW2Bool("is_knocked_out", false) then
        local knockout_type = ply:GetNW2Int("last_nonlethal_damage_type", 0)

        local knockout_anim

        if knockout_type == 0 then
            knockout_anim = ply:LookupSequence("mgs4_knocked_out_loop_faceup")
        else
            knockout_anim = ply:LookupSequence("mgs4_knocked_out_loop_facedown")
        end

        return -1, knockout_anim
    else
        local str = ply:GetNWString('SVAnim')
        local num = ply:GetNWFloat('SVAnimDelay')
        local st = ply:GetNWFloat('SVAnimStartTime')
        if str ~= "" then
            ply:SetCycle((CurTime()-st)/num)
            local current_anim = ply:LookupSequence(str)
            return -1, current_anim
        end
    end
end)


-- === CQC ===

function Cqc_check(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local is_in_cqc = ply:GetNW2Bool("is_in_cqc", false)
    local cqc_target = ply:GetNW2Entity("cqc_target", Entity(0))

    if is_in_cqc then return end

    if (ply:IsOnGround() and !IsValid(cqc_target)) or (cqc_target:GetNW2Bool("is_in_cqc", false) or cqc_target:GetNW2Bool("is_knocked_out", false)) then
        Cqc_fail(ply)
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
    -- Ensure target is facing the player
    local player_pos = ply:GetPos()
    local player_angle = ply:GetAngles()
    
    target:SetPos(player_pos + (player_angle:Forward() * 30)) -- Move the target slightly forward
    target:SetAngles(player_angle)

    if target:IsPlayer() then
        target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
    end


    ply:SetNW2Bool("is_in_cqc", true)

    ply:SVAnimationPrep("mgs4_cqc_throw", function()
        ply:SetNW2Bool("is_in_cqc", false)
        
        -- Look to the left
        ply:SetEyeAngles(ply:GetAngles() + Angle(0, 90, 0))
    end)

    target:SetNW2Int("last_nonlethal_damage_type", 0)

    target:SVAnimationPrep("mgs4_cqc_throw_victim", function()
        target:SetNW2Bool("is_in_cqc", false)

        -- CQC level stun damage
        local cqc_level = ply:GetNW2Int("cqc_level", 0)

        target:SetNW2Float("psyche", 25 * cqc_level)

    end)
    
    ply:SetSVAnimation("mgs4_cqc_throw", true)
    target:SetSVAnimation("mgs4_cqc_throw_victim", true)

end

-- === Custom commands and keys ===
concommand.Add("mgs4_cqc_throw", Cqc_check)
