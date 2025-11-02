AddCSLuaFile()

SWEP.PrintName              = "MK.2 Pistol"
SWEP.Author                 = "Mageh533"
SWEP.Instructions           = "Fire at enemies to decrease their psyche and put them to sleep. This weapon is not lethal."
SWEP.Spawnable              = true
SWEP.AdminOnly              = false
SWEP.Category               = "MGS4"

SWEP.Primary.ClipSize		= 8
SWEP.Primary.DefaultClip    = 60
SWEP.Primary.Automatic      = false
SWEP.Primary.Ammo		    = "BULLET_MK2_TRANQ"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo		    = "none"

SWEP.Weight			        = 5
SWEP.AutoSwitchTo		    = false
SWEP.AutoSwitchFrom		    = false

SWEP.Slot			        = 1
SWEP.SlotPos			    = 1
SWEP.DrawAmmo			    = true
SWEP.DrawCrosshair		    = true

-- Placeholder. Replace with a really cool MK2 (luger looking) pistol with custom anims
SWEP.ViewModel				= "models/weapons/c_mgs4_rugermk2.mdl"
SWEP.WorldModel				= "models/weapons/c_mgs4_rugermk2.mdl"

SWEP.UseHands				= true

function SWEP:Initialize()
    self:SetHoldType("revolver") -- Two handed
end

function SWEP:Deploy()
	return true
end

function SWEP:SecondaryAttack()
    return false -- Disables alt fire.
end

function SWEP:DoImpactEffect(tr, dmgtype)
	return true
end

function SWEP:Reload()
	if self:GetNextPrimaryFire() >= CurTime() or self:Clip1() == self.Primary.ClipSize then return end

	self:DefaultReload( ACT_VM_RELOAD )

	self:EmitSound("weapons/mk2/rugermk2_reload_start.wav")

	timer.Simple(0.7, function()
		if IsValid(self) and self:GetOwner():GetActiveWeapon() == self then
			self:EmitSound("weapons/mk2/rugermk2_reload_end.wav")
		end
	end)
end

function SWEP:PrimaryAttack()
	-- Make sure we can shoot first
	if ( !self:CanPrimaryAttack() ) then
		self:EmitSound( "weapons/mk2/rugermk2_empty.wav" )
		return
	end

	-- Play shoot sound
	self:EmitSound( "weapons/mk2/rugermk2_shoot.wav" )

    -- Play shooting animation
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:GetOwner():SetAnimation(PLAYER_ATTACK1)

	local bullet = {}
	bullet.Num = 1
	bullet.Src = self:GetOwner():GetShootPos()
	bullet.Dir = self:GetOwner():GetAimVector()
	bullet.Spread = Vector(0, 0, 0)
	bullet.Tracer = 1
	bullet.Damage = 20
	bullet.Force = 1
	bullet.AmmoType = self.Primary.Ammo

	bullet.Callback = function(attacker, tr, dmginfo)
		local psyche = tr.Entity:GetNWFloat("psyche", 100)

		if tr.Entity:GetNWBool("is_knocked_out", false) or psyche <= 0 then dmginfo:SetDamage(0) return true end

		if tr.HitGroup == HITGROUP_HEAD then
			dmginfo:ScaleDamage(10) -- Headshot should instantly knock out
			tr.Entity:EmitSound( "sfx/headshot.wav" )
		elseif tr.HitGroup == HITGROUP_CHEST or tr.HitGroup == HITGROUP_STOMACH then
			dmginfo:ScaleDamage(2)
		end

		local psyche_dmg = dmginfo:GetDamage()

		psyche = psyche - psyche_dmg

		tr.Entity:SetNWFloat("psyche", psyche)

		tr.Entity:SetNWInt("last_nonlethal_damage_type", 1)

		dmginfo:SetDamage(0)

		-- Drain some additional psyche over time
		if SERVER then
			hook.Add("Tick", "MGS4DrainPsycheFrom" .. tr.Entity:EntIndex(), function ()
				local ent_psyche = tr.Entity:GetNWFloat("psyche", 100)

				-- If they are knocked out then stop the drain early
				if tr.Entity:GetNWBool("is_knocked_out", false) or ent_psyche <= 0 then
					hook.Remove("Tick", "MGS4DrainPsycheFrom" .. tr.Entity:EntIndex())
					return
				end

				local psyche_drain = 2 * FrameTime()
			
				ent_psyche = ent_psyche - psyche_drain

				tr.Entity:SetNWInt("last_nonlethal_damage_type", 1)

				tr.Entity:SetNWFloat("psyche", ent_psyche)
			end)

			timer.Simple(10, function ()
				hook.Remove("Tick", "MGS4DrainPsycheFrom" .. tr.Entity:EntIndex())
			end)
		end
	end

	self:GetOwner():FireBullets(bullet)

	self:TakePrimaryAmmo( 1 )

	timer.Simple(0.4, function()
		if IsValid(self) and self:GetOwner():GetActiveWeapon() == self then
			self:EmitSound("weapons/mk2/rugermk2_chamber.wav")
		end
	end)

	self:SetNextPrimaryFire( CurTime() + 1.5 )
end
