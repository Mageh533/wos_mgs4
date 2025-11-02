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
    self:SetWeaponHoldType("revolver") -- Two handed
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW)

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
	bullet.Damage = 30
	bullet.Force = 1
	bullet.AmmoType = self.Primary.Ammo

	bullet.Callback = function(attacker, tr, dmginfo)
		if tr.HitGroup == HITGROUP_HEAD then
			dmginfo:ScaleDamage(4) -- x4 headshots
		end

		if tr.Entity:GetNWBool("is_knocked_out", false) then dmginfo:SetDamage(0) return true end

		local psyche = tr.Entity:GetNWFloat("psyche", 100)
		local psyche_dmg = dmginfo:GetDamage()

		psyche = psyche - psyche_dmg

		tr.Entity:SetNWFloat("psyche", psyche)
		tr.Entity:SetNWFloat("psyche", math.max(psyche, 0)) -- Cap at 0

		tr.Entity:SetNWInt("last_nonlethal_damage_type", 1)

		dmginfo:SetDamage(0)
	end

	self:GetOwner():FireBullets(bullet)

	self:TakePrimaryAmmo( 1 )

	timer.Simple(0.2, function()
		if IsValid(self) and self:GetOwner():GetActiveWeapon() == self then
			self:EmitSound("weapons/mk2/rugermk2_chamber.wav")
		end
	end)

	self:SetNextPrimaryFire( CurTime() + 1 )
end
