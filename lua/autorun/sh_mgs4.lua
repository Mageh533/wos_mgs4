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
    
    local pelvis_pos
    local head_angle

    if self:IsPlayer() then
        prevWeapon = self:GetActiveWeapon()
        if prevWeapon:IsValid() then
            prevWeaponClass = prevWeapon:GetClass()
            self:SetActiveWeapon( NULL )
        end
    end

    self:SetVelocity(-self:GetVelocity())

    -- Get the bone positions from before the animation ends
    timer.Simple(duration - 0.1, function()
        local pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
        pelvis_pos = pelvis_matrix:GetTranslation()
        head_angle = self:GetAttachment(self:LookupAttachment("eyes")).Ang
    end)

    timer.Simple(duration, function()
        if self:Alive() == false then return end

        self:SetPos(Vector(pelvis_pos.x, pelvis_pos.y, current_pos.z))
        
        if self:IsPlayer() then
            if ( !prevWeapon:IsValid() ) then
                prevWeapon = self:Give( prevWeaponClass )
            end

            self:SelectWeapon( prevWeapon )
            self:SetEyeAngles(Angle(head_angle.p, head_angle.y, 0))
        else
            self:SetAngles(Angle(0, head_angle.y, 0))
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
