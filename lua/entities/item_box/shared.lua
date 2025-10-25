AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Item box"
ENT.Author = "Mageh533"
ENT.Category = "MGS4"
ENT.Contact = "STEAM_0:0:53473978" -- El menda
ENT.Purpose = "Contains an items which could be either any weapon or skills"
ENT.AutomaticFrameAdvance = true -- Must be set on client
ENT.Spawnable = false

function ENT:SecondInitialize()
	-- To be overridden in derived entities
end

-- This will be called on both the Client and Server realms
function ENT:Initialize()
	-- Ensure code for the Server realm does not accidentally run on the Client
	if SERVER then
		self:SetModel( "models/mgs4/items/ibox_large.mdl" )
	    self:PhysicsInit( SOLID_VPHYSICS )
	    self:SetMoveType( MOVETYPE_VPHYSICS )
	    self:SetSolid( SOLID_VPHYSICS )
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
        self:EmitSound("sfx/item_popup.wav", 100, 100, 1, CHAN_AUTO)

		self.PickupType = 0
		self.Item = nil
		self.UnpickableTime = CurTime() + 2.0  -- Reset unpickable time on initialize

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()

			-- Lock rotation cleanly:
			-- Get the current orientation
			local ang = phys:GetAngles()
			-- Apply an angle constraint between the entity and the world
			constraint.Keepupright(self, ang, 0, 999999)

			self:SetTrigger( true ) -- Enable trigger touch detection
		end

		self:SecondInitialize()
	end
	-- Set animation once
	local seq = self:LookupSequence("spin")
	if seq and seq >= 0 then
		self:ResetSequence(seq)
		self:SetCycle(0)
		self:SetPlaybackRate(1)
	end

end

function ENT:SetPickup( type, item )
	-- type 1 = skills
	-- type 2 = weapons

	-- Set model based on type
	if type == 1 then
		self:SetModel( "models/mgs4/items/ibox_small.mdl" )
	elseif type == 2 then
		local weapon = ents.Create(item)

		local wepHoldType = weapon:GetHoldType()

		local small_weapon = false

		for _, holdty in pairs(Small_weapons_holdtypes) do
			if wepHoldType == holdty then
				small_weapon = true
				break
			end
		end

		if small_weapon then
			self:SetModel( "models/mgs4/items/ibox_mid.mdl" )
		else
			self:SetModel( "models/mgs4/items/ibox_large.mdl" )
		end
	end

	-- Reset animations
	local seq = self:LookupSequence("spin")
	if seq and seq >= 0 then
		self:ResetSequence(seq)
		self:SetCycle(0)
		self:SetPlaybackRate(1)
	end

	self.PickupType = type
	self.Item = item
end

function ENT:StartTouch( ent )
	-- Only run on server
	if not SERVER then return end

	-- Pickup
	if IsValid(ent) and ent:IsPlayer() and CurTime() > self.UnpickableTime then
		if self.PickupType == 1 then
			local skill = self.Item[1]
			local level = self.Item[2]

			ent:SetNWInt(skill, level)

			self:EmitSound("sfx/obtained_item.wav", 100, 100, 1, CHAN_AUTO)
		else
			if self.Item then
				if ent:GetWeapon(self.Item) ~= NULL then
					-- Player already has the weapon, give them ammo instead
					local wep = ent:GetWeapon( self.Item )

					local ammoType = wep:GetPrimaryAmmoType()
					local ammoAmount = wep:GetMaxClip1()  -- Give 1 clip size worth of ammo

					ent:GiveAmmo(ammoAmount, ammoType)
				else
					ent:Give( self.Item )
				end

			end
		end

		self:Remove()
	else
		self:EmitSound("sfx/full_ammo_item.wav",  100, 100, 1, CHAN_AUTO)
	end
end

function ENT:Think()
	self:NextThink( CurTime() ) -- Set the next think to run as soon as possible, i.e. the next frame.

	return true -- Apply NextThink call
end

if not CLIENT then return end

-- Client-side draw function for the Entity
function ENT:Draw()
    self:DrawModel() -- Draws the model of the Entity. This function is called every frame.
end