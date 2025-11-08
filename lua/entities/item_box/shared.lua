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
		self.UnpickableTime = CurTime() + 0.5  -- Reset unpickable time on initialize

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

		local fn = Ability_names[item[1]]

		if _G.type(fn) == "function" then
			self:SetNWString("pickup_text", fn(item[2]))
			self:SetNWBool("can_pickup", true)
		end

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

		self:SetNWString("pickup_text", item)
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

					local ammoMax = game.GetAmmoMax(ammoType)

					if ammoType == -1 or ammoAmount == -1 then
						-- Weapon does not use ammo (e.g., melee weapons) and the player already has it
						self:EmitSound("sfx/full_ammo_item.wav",  100, 100, 1, CHAN_AUTO)
						self:SetNWString("pickup_text", "SLOT FULL")
						self:SetNWBool("can_pickup", false)
						timer.Simple(1, function()
							self:SetNWString("pickup_text", self.Item)
							self:SetNWBool("can_pickup", true)
						end)
						return
					elseif ent:GetAmmoCount(ammoType) >= ammoMax then
						-- Player cannot have more ammo
						self:EmitSound("sfx/full_ammo_item.wav",  100, 100, 1, CHAN_AUTO)
						self:SetNWString("pickup_text", "AMMO FULL")
						self:SetNWBool("can_pickup", false)
						timer.Simple(1, function()
							self:SetNWString("pickup_text", self.Item)
							self:SetNWBool("can_pickup", true)
						end)
						return
					else
						ent:GiveAmmo(ammoAmount, ammoType)
					end
				else
					ent:Give( self.Item )
				end

			end
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

	local text = self:GetNWString("pickup_text", "")

	local mins, maxs = self:GetModelBounds()
	local pos = self:GetPos() + Vector(0, 0, maxs.z + 5)

	-- Draw 3d text
	if LocalPlayer():GetPos():Distance(pos) > 128 then return end

	local angle = ( pos - EyePos() ):GetNormalized():Angle()

	-- Correct the angle so it points at the camera
	-- This is usually done by trial and error using Up(), Right() and Forward() axes
	angle:RotateAroundAxis( angle:Up(), -90 )
	angle:RotateAroundAxis( angle:Forward(), 90 )

	cam.Start3D2D( pos, angle, 0.25 )  -- Reduced scale from 0.5 to 0.25
		-- Actually draw the text with smaller font
		local colour = Color(255,255,0,255)
		local offset = 0

		if not self:GetNWBool("can_pickup", true) then
			colour = Color(255,0,0,255)
			offset = math.sin(CurTime() * 80) * 1 -- Creates a sine wave oscillation
		end

		draw.SimpleTextOutlined( text, "CloseCaption_Normal", offset, 0, colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 100) )
	cam.End3D2D()
end