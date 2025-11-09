local ent = FindMetaTable("Entity")

function ent:EmitMGS4Sound(anim, speed)
    if not self or not IsValid(self) then return end

    if anim == "mgs4_cqc_throw" then
        timer.Simple(0.15 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_cqc_throw_victim" then
        timer.Simple(0.8 / speed, function()
            self:EmitSound("sfx/thrown.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_cqc_countered" then
        timer.Simple(0.1 / speed, function ()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(2 / speed, function()
            self:EmitSound("sfx/thrown.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_cqc_fail" then
        timer.Simple(0.2 / speed, function()
            self:EmitSound("sfx/air.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_knocked_back" then
        timer.Simple(0.5 / speed, function()
            self:EmitSound("sfx/thrown.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_stun" or anim == "mgs4_stun_crouched" then
        timer.Simple(0.3 / speed, function()
            self:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(1.5 / speed, function()
            self:EmitSound("sfx/thrown.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_behind" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(0.6 / speed, function()
            self:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(1.6 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_behind_alt" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(0.6 / speed, function()
            self:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(1 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_crouch" or anim == "mgs4_grab_crouched_stand" then
        timer.Simple(0.3 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_crouched_behind" or anim == "mgs4_grab_crouched_front" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(0.4 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_crouched_knife" or anim == "mgs4_grab_knife" then
        timer.Simple(0.6 / speed, function()
            self:EmitSound("sfx/knife.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_crouched_scan" or anim == "mgs4_grab_scan" then
        timer.Simple(0.6 / speed, function()
            self:EmitSound("sfx/scan_start.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(0.9 / speed, function()
            self:EmitSound("sfx/scan_end.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_front" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(1.5 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_front_alt" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(1 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_move" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/squeeze.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grab_throw_forward" or anim == "mgs4_grab_throw_backward" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(0.6 / speed, function()
            self:EmitSound("sfx/throw.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_grabbed_throw_backward" or anim == "mgs4_grabbed_throw_forward" then
        timer.Simple(1 / speed, function()
            self:EmitSound("sfx/thrown.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_gun_attack" then
        timer.Simple(0.35 / speed, function()
            self:EmitSound("sfx/air.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_cqc_throw_gun_front" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(0.8 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_cqc_throw_gun_front_victim" then
        timer.Simple(1.3 / speed, function()
            self:EmitSound("sfx/thrown.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_cqc_throw_gun_back" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/grab.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(1.4 / speed, function()
            self:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
        end)
        timer.Simple(1.9 / speed, function()
            self:EmitSound("sfx/cqc.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_cqc_throw_gun_back_victim" then
        timer.Simple(2.4 / speed, function()
            self:EmitSound("sfx/thrown.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_punch" or anim == "mgs4_punch_punch" then
        timer.Simple(0.1 / speed, function()
            self:EmitSound("sfx/air.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    elseif anim == "mgs4_kick" then
        timer.Simple(0.3 / speed, function()
            self:EmitSound("sfx/air.wav", 75, 100, 1, CHAN_WEAPON)
        end)
    end
end