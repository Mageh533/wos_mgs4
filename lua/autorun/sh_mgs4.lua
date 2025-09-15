---@diagnostic disable: undefined-field
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

    self:SetNW2Bool("animation_playing", true)

    local current_pos = self:GetPos()
    
    local pelvis_pos
    local head_angle

    self:SetVelocity(-self:GetVelocity())

    -- Get the bone positions from before the animation ends
    timer.Simple(duration - 0.01, function()
        local pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
        pelvis_pos = pelvis_matrix:GetTranslation()
        head_angle = self:GetAttachment(self:LookupAttachment("eyes")).Ang
    end)

    timer.Simple(duration, function()
        if self:Alive() == false then return end

        self:SetPos(Vector(pelvis_pos.x, pelvis_pos.y, current_pos.z))
        
        if self:IsPlayer() then
            self:SetEyeAngles(Angle(0, head_angle.y, 0))
        else
            self:SetAngles(Angle(0, head_angle.y, 0))
        end

        self:SetNW2Bool("animation_playing", false)

        if callback and type(callback) == "function" then
            callback(self)
        end

    end)
end

-- === Helper to trace a box in front of an entity ===
function ent:TraceForTarget()
    if not self then return end

    local start_pos = self:GetPos() + Vector(0, 0, 40) -- Start slightly above ground
    local end_pos = start_pos + (self:GetForward() * 32)

    local mins = Vector(-16, -16, 0)
    local maxs = Vector(16, 16, 72)

    local tr = util.TraceHull({
        start = start_pos,
        endpos = end_pos,
        mins = mins,
        maxs = maxs,
        filter = self
    })

    if IsValid(tr.Entity) and tr.Entity:LookupBone("ValveBiped.Bip01_Pelvis") == nil then
        return nil
    end

    return tr.Entity
end

-- === Knockout ===
function ent:Knockout()
    if not self then return end

    local knockout_type = self:GetNW2Int("last_nonlethal_damage_type", 0)
    local crouched

    if self:IsPlayer() then
        crouched = self:Crouching()
    else
        crouched = false
    end

    if knockout_type == 1 then
        if crouched then
            self:SVAnimationPrep("mgs4_sleep_crouched", function()
                self:SetNW2Bool("is_knocked_out", true)
            end)
            self:SetSVAnimation("mgs4_sleep_crouched", true)
        else
            self:SVAnimationPrep("mgs4_sleep", function()
                self:SetNW2Bool("is_knocked_out", true)
            end)
            self:SetSVAnimation("mgs4_sleep", true)
        end
    elseif knockout_type == 2 then
        if crouched then
            self:SVAnimationPrep("mgs4_stun_crouched", function()
                self:SetNW2Bool("is_knocked_out", true)
            end)
            self:SetSVAnimation("mgs4_stun_crouched", true)
        else
            self:SVAnimationPrep("mgs4_stun", function()
                self:SetNW2Bool("is_knocked_out", true)
            end)
            self:SetSVAnimation("mgs4_stun", true)
        end
    else
        self:SetNW2Bool("is_knocked_out", true)
    end
end

-- === Some misc actions ===
function ent:KnockedBack(forward)
    if not self then return end

    if self:IsPlayer() then
        local yaw = forward:Angle().y
        self:SetEyeAngles(Angle(0, yaw + 180, 0))
    else
        local yaw = self:GetAngles().y
        self:SetAngles(Angle(0, yaw + 180, 0))
    end

    self:SVAnimationPrep("mgs4_knocked_back", function()
        if self:GetNW2Float("psyche", 100) > 0 then
            self:GetUp()
        end
    end)
    self:SetSVAnimation("mgs4_knocked_back", true)
end

function ent:GetUp()
    if not self then return end

    if self:GetNW2Int("last_nonlethal_damage_type", 0) == 0 then
        self:SVAnimationPrep("mgs4_stun_recover_faceup")
        self:SetSVAnimation("mgs4_stun_recover_faceup", true)
    elseif self:GetNW2Int("last_nonlethal_damage_type", 0) == 1 then
        self:SVAnimationPrep("mgs4_sleep_recover_facedown")
        self:SetSVAnimation("mgs4_sleep_recover_facedown", true)
    else
        self:SVAnimationPrep("mgs4_stun_recover_facedown")
        self:SetSVAnimation("mgs4_stun_recover_facedown", true)
    end

    if self:IsPlayer() then
        self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    else
        self:SetCollisionGroup(COLLISION_GROUP_NPC)
    end
end

-- === CQC Actions ===
function ent:Cqc_fail()
    if not self then return end

    local crouched = self:Crouching()
    if crouched then
        self:SetSVAnimation("mgs4_cqc_fail_crouched", true)
    else
        self:SetSVAnimation("mgs4_cqc_fail", true)
    end

    self:SetNW2Bool("is_in_cqc", true)

    self:SVAnimationPrep("mgs4_cqc_fail", function()
        self:SetNW2Bool("is_in_cqc", false)
    end)
end

function ent:Cqc_punch()
    if not self then return end

    self:SetNW2Float("cqc_punch_time_left", 0.5) -- Time to extend the punch combo

    if self:GetNW2Bool("is_in_cqc", false) then return end

    self:SetNW2Bool("is_in_cqc", true)

    local combo_count = self:GetNW2Int("cqc_punch_combo", 0)

    if combo_count == 0 then
        self:SetSVAnimation("mgs4_punch", true)
        self:SVAnimationPrep("mgs4_punch", function()
            self:SetNW2Int("cqc_punch_combo", 1)
            self:SetNW2Bool("is_in_cqc", false)
            local tr_target = self:TraceForTarget()
            if tr_target and IsValid(tr_target) and !tr_target:GetNW2Bool("is_knocked_out", false) then
                tr_target:SetNW2Int("last_nonlethal_damage_type", 2)
                tr_target:SetNW2Float("psyche", math.max(tr_target:GetNW2Float("psyche", 100) - 10, 0))
                tr_target:SetVelocity(-tr_target:GetVelocity())
            end
        end)
    elseif combo_count == 1 then
        self:SetSVAnimation("mgs4_punch_punch", true)
        self:SVAnimationPrep("mgs4_punch_punch", function()
            self:SetNW2Int("cqc_punch_combo", 2)
            self:SetNW2Bool("is_in_cqc", false)
            local tr_target = self:TraceForTarget()
            if  tr_target and IsValid(tr_target) and !tr_target:GetNW2Bool("is_knocked_out", false) then
                tr_target:SetNW2Int("last_nonlethal_damage_type", 2)
                tr_target:SetNW2Float("psyche", math.max(tr_target:GetNW2Float("psyche", 100) - 10, 0))
                tr_target:SetVelocity(-tr_target:GetVelocity())
            end
        end)
    elseif combo_count == 2 then
        self:SetSVAnimation("mgs4_kick", true)
        self:SVAnimationPrep("mgs4_kick", function()
            self:SetNW2Int("cqc_punch_combo", 0)
            self:SetNW2Bool("is_in_cqc", false)
        end)
        timer.Simple(0.35, function()
            local tr_target = self:TraceForTarget()
            if  tr_target and IsValid(tr_target) and !tr_target:GetNW2Bool("is_knocked_out", false) then
                tr_target:SetNW2Int("last_nonlethal_damage_type", 0)
                tr_target:SetNW2Float("psyche", math.max(tr_target:GetNW2Float("psyche", 100) - 50, 0))
                tr_target:KnockedBack(self:GetForward())
            end
        end)
    end
end

function ent:Cqc_throw(target)
    if not self or not IsValid(target) then return end

    self:SetNW2Bool("is_in_cqc", true)
    self:SetNW2Entity("cqc_grabbing", target)
    self:SetNW2Int("cqc_type", 1)

    self:SVAnimationPrep("mgs4_cqc_throw", function()
        self:SetNW2Bool("is_in_cqc", false)
        self:SetNW2Entity("cqc_grabbing", Entity(0))
        self:SetNW2Int("cqc_type", 0)
    end)

    target:SetNW2Int("last_nonlethal_damage_type", 0)

    target:SVAnimationPrep("mgs4_cqc_throw_victim", function()
        target:SetNW2Bool("is_in_cqc", false)

        -- CQC level stun damage
        local cqc_level = self:GetNW2Int("cqc_level", 4)
        local stun_damage = 25 * cqc_level

        local target_psyche = target:GetNW2Float("psyche", 100)

        target:SetNW2Float("psyche", target_psyche - stun_damage)

    end)

    self:SetSVAnimation("mgs4_cqc_throw", true)
    target:SetSVAnimation("mgs4_cqc_throw_victim", true)
end

function ent:Cqc_grab(target)
    if not self or not IsValid(target) then return end

    self:SetNW2Bool("is_in_cqc", true)
    self:SetNW2Entity("cqc_grabbing", target)

    target:SetNW2Bool("is_in_cqc", true)
    
    -- Find out if grabbing from front or back
    local vec = ( self:GetPos() - target:GetPos() ):GetNormal():Angle().y
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
        self:SetNW2Int("cqc_type", 4)
        self:SVAnimationPrep("mgs4_grab_behind", function ()
            self:SetNW2Int("cqc_type", 2)
        end)
        target:SVAnimationPrep("mgs4_grabbed_behind", function (ent)
            ent:SetNW2Bool("is_grabbed", true)
        end)

        self:SetSVAnimation("mgs4_grab_behind", true)
        target:SetSVAnimation("mgs4_grabbed_behind", true)
    else
        -- Grabbing from front
        self:SetNW2Int("cqc_type", 3)
        self:SVAnimationPrep("mgs4_grab_front", function ()
            self:SetNW2Int("cqc_type", 2)
        end)
        target:SVAnimationPrep("mgs4_grabbed_front", function (ent)
            ent:SetNW2Bool("is_grabbed", true)
        end)

        self:SetSVAnimation("mgs4_grab_front", true)
        target:SetSVAnimation("mgs4_grabbed_front", true)
    end
end

function ent:Cqc_loop()
    if not self then return end

    local target = self:GetNW2Entity("cqc_grabbing", Entity(0))
    if not IsValid(target) then return end

    local type = self:GetNW2Int("cqc_type", 0)

    if type == "" then return end

    -- If target or player dies, stop the loop
    if not target:Alive() or not self:Alive() or target:GetNW2Float("psyche", 100) <= 0 or self:GetNW2Float("psyche", 100) <= 0 then
        self:SetNW2Bool("is_in_cqc", false)
        self:SetNW2Entity("cqc_grabbing", Entity(0))
        self:SetNW2Int("cqc_type", 0)

        self:SVAnimationPrep("mgs4_grab_letgo")
        self:SetSVAnimation("mgs4_grab_letgo", true)

        target:SetNW2Bool("is_in_cqc", false)
        target:SetNW2Bool("is_grabbed", false)
        target:SetNW2Bool("is_choking", false)

        return
    end

    if type == 1 then
        -- Ensure target is facing the player
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos + (player_angle:Forward() * 30)) -- Move the target slightly forward
        target:SetAngles(player_angle)

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
        end
    elseif type == 2 then
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos + (player_angle:Forward() * 5)) -- Move the target slightly forward
        target:SetAngles(player_angle)

        -- Holding the CQC button starts chocking
        if self:GetNW2Bool("cqc_button_held", false) then
            target:SetNW2Float("psyche", math.max(target:GetNW2Float("psyche", 100) - 0.5, 0))
            target:SetNW2Int("last_nonlethal_damage_type", 2)
            target:SetNW2Bool("is_choking", true)
        else
            target:SetNW2Bool("is_choking", false)
        end

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle) -- Set the target's eye angles to face the player
        end
    elseif type == 4 then
        -- Ensure target is facing the player
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos) -- Move the target slightly forward
        target:SetAngles(player_angle)

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle) -- Set the target's eye angles to face the player
        end
    elseif type == 3 then
        -- Ensure target is facing the player
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos) -- Move the target slightly forward
        target:SetAngles(player_angle + Angle(0, 180, 0))

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
        end
    end
end

function ent:Cqc_check()
    if not self then return end

    local is_in_cqc = self:GetNW2Bool("is_in_cqc", false)
    local cqc_target = self:TraceForTarget()
    local cqc_level = self:GetNW2Int("cqc_level", 1)
    local will_grab = self:GetNW2Bool("will_grab", false)

    if is_in_cqc or cqc_level < 0 or not cqc_target then return end

    if (self:IsOnGround() and !IsValid(cqc_target)) or (cqc_target:GetNW2Bool("is_in_cqc", false) or cqc_target:GetNW2Bool("is_knocked_out", false)) then
        self:Cqc_fail()
    elseif self:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() and will_grab and cqc_level >= 1 and !cqc_target:GetNW2Bool("is_in_cqc", false) and !cqc_target:GetNW2Bool("is_knocked_out", false) then
        self:Cqc_grab(cqc_target)
    elseif self:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() and !cqc_target:GetNW2Bool("is_in_cqc", false) and !cqc_target:GetNW2Bool("is_knocked_out", false) then
        self:Cqc_throw(cqc_target)
    end
end

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
    -- == CQC grab anims ==
    elseif ply:GetNW2Entity("cqc_grabbing", Entity(0)) ~= Entity(0) and ply:GetNW2Int("cqc_type", 0) == 2 then
        local grabbing_anim
        local grabbing_loop = ply:LookupSequence("mgs4_grab_loop")
        local target = ply:GetNW2Entity("cqc_grabbing", Entity(0))

        if target:GetNW2Bool("is_choking", false) then
            grabbing_anim = ply:LookupSequence("mgs4_grab_chocking")
        else
            grabbing_anim = grabbing_loop
        end

        return -1, grabbing_anim
    elseif ply:GetNW2Bool("is_grabbed", false) then
        local grabbed_anim
        local grabbed_loop = ply:LookupSequence("mgs4_grabbed_loop")

        if ply:GetNW2Bool("is_choking", false) then
            grabbed_anim = ply:LookupSequence("mgs4_grabbed_chocking")
        else
            grabbed_anim = grabbed_loop
        end

        return -1, grabbed_anim
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

-- === Camera ===
hook.Add( "CalcView", "MGS4Camera", function( ply, pos, angles, fov )
    local is_in_anim = ply:GetNW2Bool("animation_playing", false) or ply:GetNW2Int("cqc_type", 0) == 2 or ply:GetNW2Float("cqc_punch_time_left", 0) > 0

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
