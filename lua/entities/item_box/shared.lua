AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Item box"
ENT.Author = "Mageh533"
ENT.Category = "MGS4"
ENT.Contact = "STEAM_0:0:53473978" -- El menda
ENT.Purpose = "Contains an items which could be either any entity or functions (such as when granting a skill)"
ENT.AutomaticFrameAdvance = true -- Must be set on client
ENT.Spawnable = true

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

		self.UnpickableTime = CurTime() + 2.0 -- Prevent immediate pickup
		self.PickupType = 0
		self.Item = nil

		local phys = self:GetPhysicsObject()
		if phys and phys:IsValid() then
			phys:Wake()

			-- Lock rotation cleanly:
			-- Get the current orientation
			local ang = phys:GetAngles()
			-- Apply an angle constraint between the entity and the world
			constraint.Keepupright(self, ang, 0, 999999)

			self:SetTrigger( true ) -- Enable trigger touch detection
		end
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
	if not SERVER then return end
	-- type 1 = skills
	-- type 2 = weapons

	-- Set model based on type
	if type == 1 then
		self:SetModel( "models/mgs4/items/ibox_small.mdl" )
	elseif type == 2 then
		local weapon = item

		if IsValid(weapon) and weapon:IsWeapon() then
			local wepSlot = weapon:GetSlot()
			if wepSlot == 2 then
				self:SetModel( "models/mgs4/items/ibox_mid.mdl" )
			else
				self:SetModel( "models/mgs4/items/ibox_large.mdl" )
			end
		end
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
		else
			ent:Give( self.Item:GetClass() )
		end

		self:Remove()
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