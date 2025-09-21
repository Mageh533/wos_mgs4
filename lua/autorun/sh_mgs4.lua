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

    self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

    local current_pos = self:GetPos()
    
    local pos_to_set
    local head_angle

    self:SetVelocity(-self:GetVelocity())

    -- Get the bone positions from before the animation ends
    timer.Simple(duration - 0.1, function()
        local pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
        pos_to_set = pelvis_matrix:GetTranslation()

        head_angle = self:GetAttachment(self:LookupAttachment("eyes")).Ang
    end)

    timer.Simple(duration, function()
        if self:Alive() == false then return end

        self:SetPos(Vector(pos_to_set.x, pos_to_set.y, current_pos.z))
        
        if self:IsPlayer() then
            self:SetEyeAngles(Angle(0, head_angle.y, 0))
        else
            self:SetAngles(Angle(0, head_angle.y, 0))
        end

        self:SetNW2Bool("animation_playing", false)

        if self:IsPlayer() then
            self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
        else
            self:SetCollisionGroup(COLLISION_GROUP_NPC)
        end

        if callback and type(callback) == "function" then
            callback(self)
        end

        self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36)) -- Set crouch hull back to normal

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
end

function ent:Cqc_reset()
    if not self then return end

    self:SetNW2Bool("is_in_cqc", false)
    self:SetNW2Entity("cqc_grabbing", Entity(0))
    self:SetNW2Int("cqc_type", 0)
    self:SetNW2Bool("is_grabbed", false)
    self:SetNW2Bool("is_choking", false)
    self:SetNW2Bool("is_aiming", false)
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
            if  tr_target and IsValid(tr_target) and !tr_target:GetNW2Bool("is_knocked_out", false) and tr_target:GetNW2Float("psyche", 100) > 0 then
                tr_target:SetNW2Int("last_nonlethal_damage_type", 0)
                tr_target:SetNW2Float("psyche", math.max(tr_target:GetNW2Float("psyche", 100) - 50, 0))
                tr_target:KnockedBack(self:GetForward())
            end
        end)
    end
end

function ent:Cqc_throat_cut(target)
    if not self or not IsValid(target) then return end

    local knife_anim = "mgs4_grab_knife"
    local knifed_anim = "mgs4_grabbed_knife"

    if target:GetNW2Bool("is_grabbed_crouched", false) then
        knife_anim = "mgs4_grab_crouched_knife"
        knifed_anim = "mgs4_grabbed_crouched_knife"
    end

    self:SetNW2Bool("is_in_cqc", true)
    self:SetNW2Entity("cqc_grabbing", target)
    self:SVAnimationPrep(knife_anim, function()
        self:SetNW2Bool("is_in_cqc", false)
        self:SetNW2Entity("cqc_grabbing", Entity(0))
        self:SetNW2Int("cqc_type", 0)
    end)
    self:SetSVAnimation(knife_anim, true)

    target:SetNW2Int("last_nonlethal_damage_type", 1)
    target:SetNW2Bool("is_in_cqc", true)
    target:SVAnimationPrep(knifed_anim, function()
        target:SetNW2Bool("is_in_cqc", false)

        -- Just kill them lmao
        target:TakeDamage(1000, self, self)

    end)
    target:SetSVAnimation(knifed_anim, true)
end

function ent:Cqc_sop_scan(target)
    if not self or not IsValid(target) then return end

    local scan_anim = "mgs4_grab_scan"
    local scanned_anim = "mgs4_grabbed_scan"

    if target:GetNW2Bool("is_grabbed_crouched", false) then
        scan_anim = "mgs4_grab_crouched_scan"
        scanned_anim = "mgs4_grabbed_crouched_scan"
    end

    -- Temporarily remove weapon from player until scan is complete
    local current_weapon = self:GetActiveWeapon()
    if IsValid(current_weapon) then
        self:SetActiveWeapon(NULL)
    end

    self:SVAnimationPrep(scan_anim, function()
        -- Give back the weapon
        if IsValid(current_weapon) then
            self:SetActiveWeapon(current_weapon)
        end
    end)
    self:SetSVAnimation(scan_anim, true)

    target:SVAnimationPrep(scanned_anim)
    target:SetSVAnimation(scanned_anim, true)
end

function ent:Cqc_throw(target, direction)
    if not self or not IsValid(target) then return end

    if direction == 1 then
        -- Throw forward
        self:SetNW2Bool("is_in_cqc", true)
        self:SetNW2Entity("cqc_grabbing", target)
        self:SetNW2Int("cqc_type", 5)
        self:SVAnimationPrep("mgs4_grab_throw_forward", function()
            self:SetNW2Bool("is_in_cqc", false)
            self:SetNW2Entity("cqc_grabbing", Entity(0))
            self:SetNW2Int("cqc_type", 0)
        end)
        self:SetSVAnimation("mgs4_grab_throw_forward", true)

        target:SetNW2Int("last_nonlethal_damage_type", 3)
        target:SetNW2Bool("is_in_cqc", true)
        target:SVAnimationPrep("mgs4_grabbed_throw_forward", function()
            target:SetNW2Bool("is_in_cqc", false)

            -- CQC level stun damage
            local cqc_level = self:GetNW2Int("cqc_level", 4)
            local stun_damage = 10 * cqc_level

            local target_psyche = target:GetNW2Float("psyche", 100)

            target:SetNW2Float("psyche", target_psyche - stun_damage)

            if target:GetNW2Float("psyche", 100) > 0 then
                target:GetUp()
            end

        end)
        target:SetSVAnimation("mgs4_grabbed_throw_forward", true)

    elseif direction == 2 then
        -- Throw backward
        self:SetNW2Bool("is_in_cqc", true)
        self:SetNW2Entity("cqc_grabbing", target)
        self:SetNW2Int("cqc_type", 6)
        self:SVAnimationPrep("mgs4_grab_throw_backward", function()
            self:SetNW2Bool("is_in_cqc", false)
            self:SetNW2Entity("cqc_grabbing", Entity(0))
            self:SetNW2Int("cqc_type", 0)
        end)
        self:SetSVAnimation("mgs4_grab_throw_backward", true)

        target:SetNW2Int("last_nonlethal_damage_type", 0)
        target:SetNW2Bool("is_in_cqc", true)
        target:SVAnimationPrep("mgs4_grabbed_throw_backward", function()
            target:SetNW2Bool("is_in_cqc", false)

            -- CQC level stun damage
            local cqc_level = self:GetNW2Int("cqc_level", 4)
            local stun_damage = 10 * cqc_level

            local target_psyche = target:GetNW2Float("psyche", 100)

            target:SetNW2Float("psyche", target_psyche - stun_damage)
        
            if target:GetNW2Float("psyche", 100) > 0 then
                target:GetUp()
            end

        end)
        target:SetSVAnimation("mgs4_grabbed_throw_backward", true)
    else
        -- Normal throw
        self:SetNW2Bool("is_in_cqc", true)
        self:SetNW2Entity("cqc_grabbing", target)
        self:SetNW2Int("cqc_type", 1)

        self:SVAnimationPrep("mgs4_cqc_throw", function()
            self:SetNW2Bool("is_in_cqc", false)
            self:SetNW2Entity("cqc_grabbing", Entity(0))
            self:SetNW2Int("cqc_type", 0)
        end)

        target:SetNW2Int("last_nonlethal_damage_type", 0)
        target:SetNW2Bool("is_in_cqc", true)
        target:SVAnimationPrep("mgs4_cqc_throw_victim", function()
            target:SetNW2Bool("is_in_cqc", false)

            -- CQC level stun damage
            local cqc_level = self:GetNW2Int("cqc_level", 4)
            local stun_damage = 25 * cqc_level

            local target_psyche = target:GetNW2Float("psyche", 100)

            target:SetNW2Float("psyche", target_psyche - stun_damage)

            if target:GetNW2Float("psyche", 100) > 0 then
                target:GetUp()
            end

        end)

        self:SetSVAnimation("mgs4_cqc_throw", true)
        target:SetSVAnimation("mgs4_cqc_throw_victim", true)
    end
end


-- == CQC Grabbing actions ==
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
        local grab_anim
        local grabbed_anim

        local grab_standing_anim = "mgs4_grab_behind"
        local grabbed_standing_anim = "mgs4_grabbed_behind"
        local grab_crouched_anim = "mgs4_grab_crouched_behind"
        local grabbed_crouched_anim = "mgs4_grabbed_crouched_behind"

        if self:Crouching() then
            grab_anim = grab_crouched_anim
            grabbed_anim = grabbed_crouched_anim
        else
            grab_anim = grab_standing_anim
            grabbed_anim = grabbed_standing_anim
        end

        self:SetNW2Int("cqc_type", 4)
        self:SVAnimationPrep(grab_anim, function ()
            self:SetNW2Int("cqc_type", 2)
        end)
        target:SVAnimationPrep(grabbed_anim, function ()
            target:SetNW2Bool("is_grabbed", true)
        end)

        self:SetSVAnimation(grab_anim, true)
        target:SetSVAnimation(grabbed_anim, true)
    else
        -- Grabbing from front
        local grab_anim
        local grabbed_anim

        local grab_standing_anim = "mgs4_grab_front"
        local grabbed_standing_anim = "mgs4_grabbed_front"

        local grab_crouched_anim = "mgs4_grab_crouched_front"
        local grabbed_crouched_anim = "mgs4_grabbed_crouched_front"

        if self:Crouching() then
            grab_anim = grab_crouched_anim
            grabbed_anim = grabbed_crouched_anim
        else
            grab_anim = grab_standing_anim
            grabbed_anim = grabbed_standing_anim
        end


        self:SetNW2Int("cqc_type", 3)
        self:SVAnimationPrep(grab_anim, function ()
            self:SetNW2Int("cqc_type", 2)
        end)
        target:SVAnimationPrep(grabbed_anim, function()
            target:SetNW2Bool("is_grabbed", true)
        end)

        self:SetSVAnimation(grab_anim, true)
        target:SetSVAnimation(grabbed_anim, true)
    end

    if self:Crouching() then
        target:SetNW2Bool("is_grabbed_crouched", true)
    else
        target:SetNW2Bool("is_grabbed_crouched", false)
    end
end

function ent:Cqc_grab_crouch(target)
    if not self or not IsValid(target) then return end

    if not target:GetNW2Bool("is_grabbed_crouched", false) then
        self:SVAnimationPrep("mgs4_grab_crouch")
        self:SetSVAnimation("mgs4_grab_crouch", true)

        target:SVAnimationPrep("mgs4_grabbed_crouch", function ()
            target:SetNW2Bool("is_grabbed_crouched", true)
        end)
        target:SetSVAnimation("mgs4_grabbed_crouch", true)
    else
        self:SVAnimationPrep("mgs4_grab_crouched_stand")
        self:SetSVAnimation("mgs4_grab_crouched_stand", true)

        target:SVAnimationPrep("mgs4_grabbed_crouched_stand", function ()
            target:SetNW2Bool("is_grabbed_crouched", false)
        end)
        target:SetSVAnimation("mgs4_grabbed_crouched_stand", true)
    end
end

function ent:Cqc_grab_move(target)
    if not self or not IsValid(target) then return end

    self:SVAnimationPrep("mgs4_grab_move")
    self:SetSVAnimation("mgs4_grab_move", true)

    target:SVAnimationPrep("mgs4_grabbed_move")
    target:SetSVAnimation("mgs4_grabbed_move", true)
end

-- == Loop sequence to ensure correct positions at all times and handle grabbing actions ==
function ent:Cqc_loop()
    if not self then return end

    local target = self:GetNW2Entity("cqc_grabbing", Entity(0))
    if not IsValid(target) then return end

    local type = self:GetNW2Int("cqc_type", 0)

    if type == "" then return end

    -- If target or player dies, gets knocked out or player lets go. Stop the loop
    if not target:Alive() or not self:Alive() or target:GetNW2Float("psyche", 100) <= 0 or self:GetNW2Float("psyche", 100) <= 0 or self:KeyPressed(IN_JUMP) then
        self:Cqc_reset()
        target:Cqc_reset()

        -- Letgo animation on the player
        if self:Alive() and self:GetNW2Float("psyche", 100) > 0 then
            local letgo_anim

            local standed_letgo_anim = "mgs4_grab_letgo"
            local crouched_letgo_anim = "mgs4_grab_crouched_letgo"

            if target:GetNW2Bool("is_grabbed_crouched", false) then
                letgo_anim = crouched_letgo_anim
            else
                letgo_anim = standed_letgo_anim
            end

            self:SVAnimationPrep(letgo_anim)
            self:SetSVAnimation(letgo_anim, true)
        end

        -- Letgo animation on the target
        if target:Alive() and target:GetNW2Float("psyche", 100) > 0 then
            local letgo_anim

            local standed_letgo_anim = "mgs4_grabbed_letgo"
            local crouched_letgo_anim = "mgs4_grabbed_crouched_letgo"

            if target:GetNW2Bool("is_grabbed_crouched", false) then
                letgo_anim = crouched_letgo_anim
            else
                letgo_anim = standed_letgo_anim
            end

            target:SVAnimationPrep(letgo_anim)
            target:SetSVAnimation(letgo_anim, true)
        end

        return
    end

    if type == 1 then
        -- === THROW ===
        -- Ensure target is facing the player
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos + (player_angle:Forward() * 30)) -- Move the target slightly forward
        target:SetAngles(player_angle)

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
        end
    elseif type == 2 then
        -- === GRAB LOOP ===
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos + (player_angle:Forward() * 5)) -- Move the target slightly forward
        target:SetAngles(player_angle)

        self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Crouch hull to standing height to teleporting up when ducking in animations

        if not self:GetNW2Bool("is_aiming", false) then
            -- Normal mode, hold cqc button to choke, hold+forward or backward to throw, click to throat cut, e to scan.
            if self:GetNW2Bool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) then
                -- Holding the CQC button starts choking
                target:SetNW2Float("psyche", math.max(target:GetNW2Float("psyche", 100) - 0.5, 0))
                target:SetNW2Int("last_nonlethal_damage_type", 2)
                target:SetNW2Bool("is_choking", true)
            elseif self:GetNW2Bool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) and not target:GetNW2Bool("is_grabbed_crouched", false) then
                -- Holding and moving forward throws the target in front
                self:Cqc_reset()
                target:Cqc_reset()
                self:Cqc_throw(target, 1)
            elseif self:GetNW2Bool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and not self:KeyPressed(IN_FORWARD) and self:KeyPressed(IN_BACK) and not target:GetNW2Bool("is_grabbed_crouched", false) then
                -- Holding and moving backward throws the target behind
                self:Cqc_reset()
                target:Cqc_reset()
                self:Cqc_throw(target, 2)
            elseif self:GetNW2Bool("cqc_button_held", false) and self:KeyPressed(IN_USE) and self:GetNW2Bool("blades3", false) and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) then
                -- press e while holding does the throat cut
                self:Cqc_reset()
                target:Cqc_reset()
                self:Cqc_throat_cut(target)
            elseif not self:GetNW2Bool("cqc_button_held", false) and self:KeyPressed(IN_USE) and self:GetNW2Bool("scanner3", false) and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) then
                -- press e while not holding does the scan
                self:Cqc_sop_scan(target)
            elseif self:KeyPressed(IN_BACK) and not target:GetNW2Bool("is_grabbed_crouched", false) then
                -- Pressing back button moves backwards
                self:Cqc_grab_move(target)
            elseif self:KeyPressed(IN_DUCK) then
                -- Pressing crouch makes both the player and target crouch while grabbing
                self:Cqc_grab_crouch(target)
            else
                target:SetNW2Bool("is_choking", false)
            end
        end

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle) -- Set the target's eye angles to face the player
        end
    elseif type == 3 then
        -- === GRAB FRONT ===
        -- Ensure target is facing the player
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos)
        target:SetAngles(player_angle + Angle(0, 180, 0))

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle + Angle(0, 180, 0)) -- Set the target's eye angles to face the player
        end
    else
        -- === Generic, assume both position and angles are correct according to the player ===
        local player_pos = self:GetPos()
        local player_angle = self:GetAngles()

        target:SetPos(player_pos)
        target:SetAngles(player_angle)

        if target:IsPlayer() then
            target:SetEyeAngles(player_angle) -- Set the target's eye angles to face the player
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

-- Not literally helping yourself (you are helping another get up, its an mgo2 reference)
function ent:GetYourselfUp()
    if not self then return end

    local target = self:TraceForTarget()

    if not target or not IsValid(target) then
        self:SetNW2Bool("helping_up", false)
        return
    end

    if self:GetNW2Bool("helping_up", false) and target:GetNW2Bool("is_knocked_out", false) then
        target:SetNW2Float("psyche", target:GetNW2Float("psyche", 100) + (GetConVar("mgs4_psyche_recovery_action"):GetFloat() * FrameTime() * 10))
    elseif not self:GetNW2Bool("helping_up", false) and target:GetNW2Bool("is_knocked_out", false) and self:Crouching() then
        self:SVAnimationPrep("mgs4_wakeup_start", function()
            self:SetNW2Bool("helping_up", true)
            self:SetCycle(0)
        end)
        self:SetSVAnimation("mgs4_wakeup_start", true)
    elseif self:GetNW2Bool("helping_up", false) and not target:GetNW2Bool("is_knocked_out", false) then
        self:SetNW2Bool("is_using", false)
    end

end

-- === Handling buttons while grabbing ===
hook.Add("StartCommand", "MGS4StartCommand", function(ply, cmd)
    if ply:GetNW2Int("cqc_type", 0) == 2 and not ply:GetNW2Bool("is_aiming", false) and not ply:GetNW2Bool("is_knife", false) then
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_RELOAD)
    elseif ply:GetNW2Int("cqc_type", 0) == 2 and ply:GetNW2Bool("is_aiming", false) then
        cmd:RemoveKey(IN_JUMP)
        cmd:RemoveKey(IN_FORWARD)
        cmd:RemoveKey(IN_BACK)
        cmd:RemoveKey(IN_MOVELEFT)
        cmd:RemoveKey(IN_MOVERIGHT)
        cmd:RemoveKey(IN_DUCK)
    elseif ply:GetNW2Bool("helping_up", false) then
        cmd:ClearMovement()
        cmd:RemoveKey(IN_JUMP)
        cmd:RemoveKey(IN_DUCK)
    end
end)

-- === Animation Handling for players ===
hook.Add("CalcMainActivity", "!MGS4Anims", function(ply, vel)
    if ply:GetNW2Bool("is_knocked_out", false) then
        -- == Knockout loop ==
        local knockout_type = ply:GetNW2Int("last_nonlethal_damage_type", 0)

        local knockout_anim

        if knockout_type == 0 then
            knockout_anim = ply:LookupSequence("mgs4_knocked_out_loop_faceup")
        else
            knockout_anim = ply:LookupSequence("mgs4_knocked_out_loop_facedown")
        end

        ply:SetCycle(CurTime() % 1)

        return -1, knockout_anim
    elseif ply:GetNW2Entity("cqc_grabbing", Entity(0)) ~= Entity(0) and ply:GetNW2Int("cqc_type", 0) == 2 and not ply:GetNW2Bool("animation_playing", false) then
        -- == CQC grab loop ==
        local grabbing_anim

        local grabbing_loop = ply:LookupSequence("mgs4_grab_loop")
        local grabbing_aim = ply:LookupSequence("mgs4_grab_aim")
        local grabbing_chocking = ply:LookupSequence("mgs4_grab_chocking")

        local grabbing_crouched_loop = ply:LookupSequence("mgs4_grab_crouched_loop")
        local grabbing_crouched_aim = ply:LookupSequence("mgs4_grab_crouched_aim")
        local grabbing_crouched_chocking = ply:LookupSequence("mgs4_grab_crouched_chocking")

        local target = ply:GetNW2Entity("cqc_grabbing", Entity(0))

        if target:GetNW2Bool("is_choking", false) then
            if target:GetNW2Bool("is_grabbed_crouched", false) then
                grabbing_anim = grabbing_crouched_chocking
            else
                grabbing_anim = grabbing_chocking
            end
        elseif ply:GetNW2Bool("is_aiming", false) then
            if target:GetNW2Bool("is_grabbed_crouched", false) then
                grabbing_anim = grabbing_crouched_aim
            else
                grabbing_anim = grabbing_aim
            end
        else
            if target:GetNW2Bool("is_grabbed_crouched", false) then
                grabbing_anim = grabbing_crouched_loop
            else
                grabbing_anim = grabbing_loop
            end
        end

        ply:SetCycle(CurTime() % 1)

        return -1, grabbing_anim
    elseif ply:GetNW2Bool("is_grabbed", false) and not ply:GetNW2Bool("animation_playing", false) then
        -- == CQC grabbed loop ==
        local grabbed_anim

        local grabbed_loop = ply:LookupSequence("mgs4_grabbed_loop")
        local grabbed_chocking = ply:LookupSequence("mgs4_grabbed_chocking")

        local grabbed_crouched_loop = ply:LookupSequence("mgs4_grabbed_crouched_loop")
        local grabbed_crouched_chocking = ply:LookupSequence("mgs4_grabbed_crouched_chocking")

        if ply:GetNW2Bool("is_choking", false) then
            if ply:GetNW2Bool("is_grabbed_crouched", false) then
                grabbed_anim = grabbed_crouched_chocking
            else
                grabbed_anim = grabbed_chocking
            end
        else
            if ply:GetNW2Bool("is_grabbed_crouched", false) then
                grabbed_anim = grabbed_crouched_loop
            else
                grabbed_anim = grabbed_loop
            end
        end

        ply:SetCycle(CurTime() % 1)

        return -1, grabbed_anim
    elseif ply:GetNW2Bool("helping_up", false) and not ply:GetNW2Bool("animation_playing", false) then
        -- == Playing an animation ==
        local helping_loop = ply:LookupSequence("mgs4_wakeup_loop")

        ply:SetCycle(CurTime() % 1)

        return -1, helping_loop
    else
        -- == All other animations ==
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
    local is_in_anim = ply:GetNW2Bool("animation_playing", false) or (ply:GetNW2Int("cqc_type", 0) == 2 and not ply:GetNW2Bool("is_aiming", false)) or ply:GetNW2Float("cqc_punch_time_left", 0) > 0 or ply:GetNW2Bool("helping_up", false)

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
