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

function ent:SVAnimationPrep(duration, callback)
    if not self then return end

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
            self:ClearCondition( COND.NPC_UNFREEZE )
        end

        self:SetNW2Bool("animation_playing", false)

        if callback and type(callback) == "function" then
            callback(self)
        end

    end)
end

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
    ply:SetSVAnimation("mgs4_cqc_fail", true)

    local cqc_fail_anim = ply:LookupSequence("mgs4_cqc_fail")
    local anim_length = ply:SequenceDuration(cqc_fail_anim)

    ply:SetNW2Bool("is_in_cqc", true)

    ply:SVAnimationPrep(anim_length, function()
        ply:SetNW2Bool("is_in_cqc", false)
        -- Move player slightly forward
        local forward = ply:GetForward()
        ply:SetPos(ply:GetPos() + forward * 20)
    end)

end

-- CQC Throw mechanic
function Cqc_throw(ply, target)
    -- Ensure target is facing the player
    local player_pos = ply:GetPos()
    local player_angle = ply:GetAngles()
    
    target:SetPos(player_pos + (player_angle:Forward() * 20)) -- Move the target slightly forward

    ply:SetSVAnimation("mgs4_cqc_throw", true)
    target:SetSVAnimation("mgs4_cqc_throw_victim", true)

    local cqc_throw_anim = ply:LookupSequence("mgs4_cqc_throw")
    local anim_length = ply:SequenceDuration(cqc_throw_anim)

    local target_cqc_throw_anim = target:LookupSequence("mgs4_cqc_throw_victim")
    local target_anim_length = target:SequenceDuration(target_cqc_throw_anim)

    ply:SetNW2Bool("is_in_cqc", true)

    ply:SVAnimationPrep(anim_length, function()
        ply:SetNW2Bool("is_in_cqc", false)
    end)

    target:SetNW2Bool("have_been_cqced", true)

    target:SVAnimationPrep(target_anim_length, function()
        target:SetNW2Bool("is_in_cqc", false)
    end)

end

-- Custom commands
concommand.Add("mgs4_cqc_throw", Cqc_check)
