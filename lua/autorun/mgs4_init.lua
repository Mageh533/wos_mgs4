local ent = FindMetaTable("Entity")

-- === Helpers ===
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

    if self:IsPlayer() then
        prevWeapon = self:GetActiveWeapon()
        prevWeaponClass = prevWeapon:GetClass()
        self:SetActiveWeapon( NULL )
        self:Freeze(true)
    else
        self:SetCondition( COND.NPC_FREEZE )
    end

    self:SetVelocity(-self:GetVelocity())

    timer.Simple(duration, function()
        
        if self:IsPlayer() then
            self:Freeze(false)

            if ( !prevWeapon:IsValid() ) then
                prevWeapon = self:Give( prevWeaponClass )
            end

            self:SelectWeapon( prevWeapon )
        else
            self:SetCondition( COND.NPC_UNFREEZE )
        end

        self:SetNW2Bool("animation_playing", false)

        if callback and type(callback) == "function" then
            callback(self)
        end

    end)
end

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

    if knockout_type == 0 then
        self:SetSVAnimation("mgs4_knocked_out_loop_faceup", true)
        self:SVAnimationPrep("mgs4_knocked_out_loop_faceup")
    elseif knockout_type == 1 then
        if crouched then
            self:SetSVAnimation("mgs4_sleep_crouched", true)
            self:SVAnimationPrep("mgs4_sleep_crouched")
        else
            self:SetSVAnimation("mgs4_sleep", true)
            self:SVAnimationPrep("mgs4_sleep")
        end
    elseif knockout_type == 2 then
        if crouched then
            self:SetSVAnimation("mgs4_stun_crouched", true)
            self:SVAnimationPrep("mgs4_stun_crouched")
        else
            self:SetSVAnimation("mgs4_stun", true)
            self:SVAnimationPrep("mgs4_stun")
        end
    end
end

function KnockoutLoop(ent)

end

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

-- Check for entities that have reached 0 psyche
hook.Add("Think", "MGS4PsycheCheck", function()
    for _, ent in ipairs(ents.GetAll()) do
        if ent:GetNW2Float("psyche", 100) <= 0 and not ent:GetNW2Bool("is_knocked_out", false) then
            ent:Knockout() -- Knock out the player silently
        end

        if ent:GetNW2Bool("is_knocked_out", true) and ent:GetNW2Float("psyche", 100) <= 100 then
            ent:SetNW2Bool("animation_playing", true)

            local knockout_type = ent:GetNW2Int("last_nonlethal_damage_type", 0)

            if knockout_type == 2 then
                ent:SetSVAnimation("mgs4_knocked_out_loop_faceup", true)
            else
                ent:SetSVAnimation("mgs4_knocked_out_loop_facedown", true)
            end

            local psyche = ent:GetNW2Float("psyche", 100)
            if psyche < 100 then
                psyche = psyche + GetConVar("mgs4_psyche_recovery"):GetFloat() * FrameTime()
                ent:SetNW2Float("psyche", math.min(psyche, 100)) -- Cap at 100
            end

            if ent:IsPlayer() and ent:KeyPressed(IN_USE) then
                psyche = psyche + GetConVar("mgs4_psyche_recovery_action"):GetFloat()
                ent:SetNW2Float("psyche", math.min(psyche, 100)) -- Cap at 100
            end
        
        end

        if ent:GetNW2Bool("is_knocked_out", true) and ent:GetNW2Float("psyche", 100) >= 100 then
            ent:SetNW2Bool("is_knocked_out", false)
            ent:SetNW2Float("psyche", 100)
        end
    end
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


-- === CQC ===

function Cqc_check(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local is_in_cqc = ply:GetNW2Bool("is_in_cqc", false)
    local cqc_target = ply:GetNW2Entity("cqc_target", Entity(0))

    if is_in_cqc then return end

    if ply:IsOnGround() and !IsValid(cqc_target) then
        Cqc_fail(ply)
    elseif ply:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() then
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
        -- Move player slightly forward
        if !crouched then
            local forward = ply:GetForward()
            ply:SetPos(ply:GetPos() + forward * 20)
        end
    end)

end

-- CQC Throw mechanic
function Cqc_throw(ply, target)
    -- Ensure target is facing the player
    local player_pos = ply:GetPos()
    local player_angle = ply:GetAngles()
    
    target:SetPos(player_pos + (player_angle:Forward() * 30)) -- Move the target slightly forward

    if target:IsPlayer() then
        target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
    else
        -- For NPCs, we can use a different method to ensure they face the player
        target:SetAngles(player_angle)
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

        target:SetPos(ply:GetPos() + (ply:GetRight() * -30)) -- Move the target slightly forward

        if target:IsPlayer() then
            target:SetEyeAngles(ply:GetAngles()) -- Set the target's eye angles to face away from the player
        else
            -- For NPCs, we can use a different method to ensure they face away from the player
            target:SetAngles(ply:GetAngles())
        end

        -- CQC level stun damage
        local cqc_level = ply:GetNW2Int("cqc_level", 0)

        target:SetNW2Float("psyche", 25 * cqc_level)

    end)
    
    ply:SetSVAnimation("mgs4_cqc_throw", true)
    target:SetSVAnimation("mgs4_cqc_throw_victim", true)

end

-- Custom commands
concommand.Add("mgs4_cqc_throw", Cqc_check)
