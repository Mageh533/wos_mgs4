---@diagnostic disable: undefined-field
local ent = FindMetaTable("Entity")

function ent:PlayMGS4Animation(anim, callback, updatepos, speed)
	if not self then return end

	local npc_proxy -- If playing on an npc

	local current_anim = self:LookupSequence(anim)
	local duration = self:SequenceDuration(current_anim)

	self:SetNWBool("animation_playing", true)
	self:SetNWFloat("cqc_button_hold_time", 0)

	local current_pos = self:GetPos()

	-- Shouldn't be able to start an anim without being in a safe position
	self:SetNWVector("safe_pos", current_pos)

	local pos_to_set

	local sp_modifier = speed and speed or 1

	self:SetVelocity(-self:GetVelocity())

	if self:IsNPC() or self:IsNextBot() then
		if self:GetNWEntity("npc_proxy", NULL) ~= NULL then
			local old_px = self:GetNWEntity("npc_proxy", NULL)
			old_px:Stop()
			old_px:Remove()
		end
		npc_proxy = ents.Create("mgs4_npc_sequence")
		npc_proxy.NPC = self
		npc_proxy.Sequence = anim
		npc_proxy.Speed = sp_modifier
		npc_proxy:SetPos(self:GetPos())
		npc_proxy:SetAngles(self:GetAngles())
		npc_proxy:Spawn()

		current_anim = npc_proxy:LookupSequence(anim)
		duration = npc_proxy:SequenceDuration(current_anim)
	end

	timer.Simple(duration / sp_modifier, function()
		if not IsValid(self) or not self:Alive() then return end

		local pelvis_matrix

		if self:IsPlayer() then
			pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
		else
			pelvis_matrix = npc_proxy:GetBoneMatrix(npc_proxy:LookupBone("ValveBiped.Bip01_Pelvis"))
		end

		pos_to_set = pelvis_matrix:GetTranslation()

		if updatepos then
			self:SetPos(Vector(pos_to_set.x, pos_to_set.y, current_pos.z))
		end

		self:SetNWBool("animation_playing", false)

		if callback and type(callback) == "function" then
		    callback(self)
		end

		if npc_proxy then
            npc_proxy:Stop()
            npc_proxy:Remove()

			if self:GetNWEntity("npc_proxy", NULL) ~= NULL then
				self:SetNWEntity("npc_proxy", NULL)
			end

			-- Thanks Sunw5w for pointing this out about stiff npcs
			if self:IsNPC() and self.SetNPCState then
				self:SetNPCState(NPC_STATE_IDLE)
			elseif self:IsNextBot() then
				self:StartActivity(ACT_IDLE)
			end
		end

	end)

	self:EmitMGS4Sound(anim, sp_modifier)

	if not self:IsPlayer() then return end

	-- Thanks Hari and NizcKM, This idea for server animations is great. 
	self:SetNWString('SVAnim', anim)
	self:SetNWFloat('SVAnimDelay', select(2, self:LookupSequence(anim)))
	self:SetNWFloat('SVAnimStartTime', CurTime())
	self:SetNWFloat('SVAnimSpeed', sp_modifier)
	self:SetCycle(0)

	local delay = select(2, self:LookupSequence(anim))
	timer.Simple(delay, function()
		if !IsValid(self) then return end

		local anim2 = self:GetNWString('SVAnim')

		if anim == anim2 then
			self:SetNWString('SVAnim', "")
		end
	end)
end

-- === Helper to trace a box in front of an entity ===
function ent:TraceForTarget()
	if not self then return end

	local start_pos = self:GetPos()
	local end_pos = start_pos + (self:GetForward() * 32)

	local mins = self:OBBMins()
	local maxs = self:OBBMaxs()

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

-- === Helper to find out the angle of the target ===
function ent:AngleAroundTarget(target)
	if not self or not IsValid(target) then return 0 end

	local vec = ( self:GetPos() - target:GetPos() ):GetNormal():Angle().y
	local targetAngle = target:GetAngles().y

	if target:IsPlayer() then
		targetAngle = target:EyeAngles().y
	end

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

	return angleAround
end

if SERVER then
	-- === Helper for forcing a position and angle ===
	function ent:ForcePosition(force, pos, ang)
		if not self then return end

		if force then
			self:SetNWBool("force_position", true)

			self:SetNWVector("forced_position", pos and pos or self:GetPos())

			local angles = self:GetAngles()

			if self:IsPlayer() then
				angles = self:EyeAngles()
			end

			self:SetNWAngle("forced_angle", ang and Angle(0, ang.y, 0) or Angle(0, angles.y, 0))
		else
			self:SetNWBool("force_position", false)
		end
	end

	function ent:MGS4StuckCheck()
		if not self then return end
		
		local pos = self:GetPos()

		-- Base the position on the bone since it will match the animation position
		local pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
		local pelvis_pos = pelvis_matrix:GetTranslation()

		local Maxs = Vector(self:OBBMaxs().X / self:GetModelScale(), self:OBBMaxs().Y / self:GetModelScale(), self:OBBMaxs().Z / self:GetModelScale()) 
		local Mins = Vector(self:OBBMins().X / self:GetModelScale(), self:OBBMins().Y / self:GetModelScale(), self:OBBMins().Z / self:GetModelScale())

		local tr = util.TraceHull({
			start = Vector(pelvis_pos.x, pelvis_pos.y, pos.z),
			endpos = Vector(pelvis_pos.x, pelvis_pos.y, pos.z),
			maxs = Maxs,
			mins = Mins,
			collisiongroup = COLLISION_GROUP_PLAYER,
			mask = MASK_PLAYERSOLID,
			filter = function(ent)
				if ent:IsScripted() and self:BoundingRadius() - ent:BoundingRadius() > 0 then return end

				if ent:GetCollisionGroup() ~= 20 and ent ~= self then return true end
			end
		})

		if tr.Hit then
			-- Additional timer to keep checking post anim until the player stops colliding
			self:SetNWFloat("stuck_check", 1.0)

			-- Get the direction based on the last unstuck pos
			local prev_pos = self:GetNWVector("safe_pos", Vector(0,0,0))
			local new_pos = Vector(pelvis_pos.x, pelvis_pos.y, pos.z)

			local direction = (new_pos - prev_pos):GetNormalized()

			-- Push the player on the opposite direction if they are stuck
			if self:GetNWBool("force_position", false) then
				-- push the forced position
				self:SetNWVector("forced_position", self:GetNWVector("forced_position") - direction)
			else
				-- Push the actual position
				self:SetPos(pos - direction)
			end
		else
			-- Set the currently known safe pos
			self:SetNWVector("safe_pos", Vector(pelvis_pos.x, pelvis_pos.y, pos.z))
		end
	end

	-- === Knockout ===
	function ent:Knockout()
		if not self then return end

		local was_t_choked = self:GetNWBool("is_t_choking")

		self:Cqc_reset()

		local knockout_type = self:GetNWInt("last_nonlethal_damage_type", 0)
		local crouched = self:GetNWBool("is_grabbed_crouched", false)

		if self:IsPlayer() then
			crouched = crouched or self:Crouching()
		end

		local knockout_anim

		if was_t_choked then
			-- Nasty exception
			knockout_anim = "mgs4_grabbed_crouched_tchoke_end"
		else
			if knockout_type == 1 then
				if crouched then
					knockout_anim = "mgs4_sleep_crouched"
				else
					knockout_anim = "mgs4_sleep"
				end
			elseif knockout_type == 2 then
				if crouched then
					knockout_anim = "mgs4_stun_crouched"
				else
					knockout_anim = "mgs4_stun"
				end
			end
		end

		if knockout_anim then
			local angles = self:GetAngles()

			if self:IsPlayer() then
				angles = self:EyeAngles()
			end

			self:ForcePosition(true, self:GetPos(), angles)
			self:PlayMGS4Animation(knockout_anim, function()
				self:SetNWBool("is_knocked_out", true)
				self:ForcePosition(true, self:GetPos(), angles)
				self:SetNWFloat("stuck_check", 0)
			end, true)
		else
			self:SetNWBool("is_knocked_out", true)
		end
	end

    -- === Some misc actions ===
	function ent:KnockedBack(forward)
		if not self then return end

		self:ForcePosition(true, self:GetPos(), forward:Angle() + Angle(0, 180, 0))

		self:PlayMGS4Animation("mgs4_knocked_back", function()
			if self:GetNWFloat("psyche", 100) > 0 then
				self:StandUp()
			end
			self:ForcePosition(false)
		end, true)

		self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
	end

	function ent:StandUp()
		if not self then return end

		local angles = self:GetAngles()

		if self:IsPlayer() then
			angles = self:EyeAngles()
		end

		self:ForcePosition(true, self:GetPos(), angles)
		if self:GetNWInt("last_nonlethal_damage_type", 0) == 0 then
			self:PlayMGS4Animation("mgs4_stun_recover_faceup", function()
				self:ForcePosition(false)
			end, true)
		elseif self:GetNWInt("last_nonlethal_damage_type", 0) == 1 then
			self:PlayMGS4Animation("mgs4_sleep_recover_facedown", function()
				self:ForcePosition(false)
			end, true)
		else
			self:PlayMGS4Animation("mgs4_stun_recover_facedown", function()
				self:ForcePosition(false)
			end, true)
		end

		self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
	end

	-- Drops their weapon using an item box
	function ent:DropWeaponAsItem()
		if not self then return end

		local function StripNPCWeapon(npc)
			if not IsValid(npc) then return end

			-- 1. Standard HL2 NPC / Nextbot weapon entity
			for _, child in ipairs(npc:GetChildren()) do
				if IsValid(child) and (child:IsWeapon() or child:GetClass():find("weapon")) then
					child:Remove()
				end
			end

			-- 2. VJ Base
			if npc.WeaponEnt and IsValid(npc.WeaponEnt) then
				npc.WeaponEnt:Remove()
				npc.WeaponEnt = nil
				npc.HasWeapon = false
			end

			-- 3. Fallback weapon disabling flags
			if npc.SetNPCState then
				npc:SetNPCState(NPC_STATE_IDLE)
			end

			if npc:IsNextBot() then
				npc:StartActivity(ACT_IDLE)
			end

			if npc.ClearEnemyMemory then
				npc:ClearEnemyMemory()
			end
		end

		-- Make them drop their weapon in an item box
		local active_weapon = self:GetActiveWeapon()
		if IsValid(active_weapon) then
			local weapon_class = active_weapon:GetClass()
			if GAMEMODE_NAME == "terrortown" then
				-- TTT Exceptions
				if weapon_class == "weapon_zm_improvised" then return end
				if weapon_class == "weapon_ttt_unarmed" then return end
				if weapon_class == "weapon_zm_carry" then return end
			end
			if self:IsPlayer() then
				self:StripWeapon(weapon_class)
				self:SetActiveWeapon(NULL)
			else
				StripNPCWeapon(self)
			end
			local wep_drop = ents.Create("item_box")
			wep_drop:SetPos(self:GetPos() + Vector(0,0,20))
			wep_drop:Spawn()
			wep_drop:SetPickup(2, weapon_class)
			local rand_vec = VectorRand(-400,400)
			wep_drop:GetPhysicsObject():SetVelocity(Vector(rand_vec.x, rand_vec.y, 400))
		end
	end

	function ent:Cqc_reset()
		if not self then return end

		self:SetNWBool("is_in_cqc", false)
		self:SetNWEntity("cqc_grabbing", NULL)
		self:SetNWBool("is_grabbed", false)
		self:SetNWBool("is_grabbed_crouched", false)
		self:SetNWBool("is_choking", false)
		self:SetNWBool("is_t_choking", false)
		self:SetNWBool("is_aiming", false)
		self:SetNWBool("is_knife", false)
		self:SetNWBool("is_using", false)
	end

	-- === CQC Actions ===
	function ent:Cqc_fail()
		if not self then return end

		self:ForcePosition(true)

		local crouched = self:Crouching()
		if crouched then
			self:PlayMGS4Animation("mgs4_cqc_fail_crouched", function ()
				self:SetNWBool("is_in_cqc", false)
				self:ForcePosition(false)
			end, true)
		else
			self:PlayMGS4Animation("mgs4_cqc_fail", function ()
				self:SetNWBool("is_in_cqc", false)
				self:ForcePosition(false)
			end, true)
		end

		self:SetNWBool("is_in_cqc", true)
	end

	function ent:Cqc_punch()
		if not self then return end

		self:SetNWFloat("cqc_punch_time_left", 0.8) -- Time to extend the punch combo

		-- Players cannot punch with 2 handed weapons
		local current_weapon = self:GetActiveWeapon()

		if IsValid(current_weapon) then
			local weapon_hold_type = current_weapon:GetHoldType()

			local large_weapon = true

			for _, hold_type in pairs(Small_weapons_holdtypes) do
				if weapon_hold_type == hold_type then
					large_weapon = false
					break
				end
			end

			if large_weapon then
				self:ForcePosition(true)
				self:PlayMGS4Animation("mgs4_gun_attack", function ()
					self:Cqc_reset()
					self:ForcePosition(false)
				end, true)
				timer.Simple(0.35, function()
					local tr_target = self:TraceForTarget()
					if  tr_target and IsValid(tr_target) and !tr_target:GetNWBool("is_knocked_out", false) and tr_target:GetNWFloat("psyche", 100) > 0 and tr_target:GetNWFloat("cqc_immunity_remaining", 0) <= 0 then
						tr_target:SetNWInt("last_nonlethal_damage_type", 2)
						tr_target:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
						tr_target:SetNWFloat("psyche", math.max(tr_target:GetNWFloat("psyche", 100) - 30, 0))
					end
				end)
				return
			end
		end

		if self:GetNWBool("is_in_cqc", false) then return end

		self:SetNWBool("is_in_cqc", true)

		local combo_count = self:GetNWInt("cqc_punch_combo", 0)

		if combo_count == 0 then
			self:ForcePosition(true)
			self:PlayMGS4Animation("mgs4_punch", function ()
				self:SetNWInt("cqc_punch_combo", 1)
				self:ForcePosition(false)
				self:Cqc_reset()
				local tr_target = self:TraceForTarget()
				if tr_target and IsValid(tr_target) and !tr_target:GetNWBool("is_knocked_out", false) and tr_target:GetNWFloat("cqc_immunity_remaining", 0) <= 0 then
					tr_target:SetNWInt("last_nonlethal_damage_type", 2)
					tr_target:SetNWFloat("psyche", math.max(tr_target:GetNWFloat("psyche", 100) - 10, 0))
					tr_target:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
					tr_target:SetVelocity(-tr_target:GetVelocity())
				end
			end, true)
		elseif combo_count == 1 then
			self:ForcePosition(true)
			self:PlayMGS4Animation("mgs4_punch_punch", function ()
				self:SetNWInt("cqc_punch_combo", 2)
				self:ForcePosition(false)
				self:Cqc_reset()
				local tr_target = self:TraceForTarget()
				if  tr_target and IsValid(tr_target) and !tr_target:GetNWBool("is_knocked_out", false) and tr_target:GetNWFloat("cqc_immunity_remaining", 0) <= 0 then
					tr_target:SetNWInt("last_nonlethal_damage_type", 2)
					tr_target:SetNWFloat("psyche", math.max(tr_target:GetNWFloat("psyche", 100) - 10, 0))
					tr_target:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
					tr_target:SetVelocity(-tr_target:GetVelocity())
				end
			end, true)
		elseif combo_count == 2 then
			self:ForcePosition(true)
			self:PlayMGS4Animation("mgs4_kick", function ()
				self:SetNWInt("cqc_punch_combo", 0)
				self:ForcePosition(false)
				self:Cqc_reset()
				end, true)
				timer.Simple(0.35, function()
				local tr_target = self:TraceForTarget()
				if  tr_target and IsValid(tr_target) and !tr_target:GetNWBool("is_knocked_out", false) and tr_target:GetNWFloat("psyche", 100) > 0 and tr_target:GetNWFloat("cqc_immunity_remaining", 0) <= 0 then
					tr_target:Cqc_reset()
					tr_target:SetNWInt("last_nonlethal_damage_type", 0)
					tr_target:SetNWFloat("psyche", math.max(tr_target:GetNWFloat("psyche", 100) - 50, 0))
					tr_target:EmitSound("sfx/hit.wav", 75, 100, 1, CHAN_WEAPON)
					tr_target:KnockedBack(self:GetForward())
				end
			end)
		end
	end

	function ent:Cqc_throat_cut(target)
		if not self or not IsValid(target) then return end

		local knife_anim = "mgs4_grab_knife"
		local knifed_anim = "mgs4_grabbed_knife"

		if target:GetNWBool("is_grabbed_crouched", false) then
			knife_anim = "mgs4_grab_crouched_knife"
			knifed_anim = "mgs4_grabbed_crouched_knife"
		end

		self:ForcePosition(true)
		self:SetNWBool("is_in_cqc", true)
		self:PlayMGS4Animation(knife_anim, function()
			self:Cqc_reset()
			if self:IsPlayer() then
				self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36)) -- Set crouch hull back to normal
				self:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Set stand hull back to normal
			end
			self:SetViewOffset(Vector(0, 0, 64)) -- Set stand view offset back to normal
		
			if self:GetNWEntity("knife", NULL) ~= NULL then
				self:GetNWEntity("knife", NULL):Remove()
				self:SetNWEntity("knife", NULL)
			end

			self:ForcePosition(false)
		end, false)

		local angles = self:GetAngles()

		if self:IsPlayer() then
			angles = self:EyeAngles()
		end

		self:ForcePosition(true, target:GetPos(), angles)
		target:SetNWBool("is_in_cqc", true)
		target:PlayMGS4Animation(knifed_anim, function()
			target:SetNWBool("is_in_cqc", false)

			-- Kill them but lots of damage but without the massive knockback
			local dmginfo = DamageInfo()

			dmginfo:SetDamage(target:Health())
			dmginfo:SetDamageType(DMG_SLASH)
			dmginfo:SetAttacker(self)
			dmginfo:SetInflictor(self)

			target:TakeDamageInfo(dmginfo)

			target:SetVelocity(target:GetVelocity())

			target:ForcePosition(false)
		end, false)
	end

	function ent:Cqc_sop_scan(target, ex)
		if not self or not IsValid(target) then return end

		local scan_anim = "mgs4_grab_scan"
		local scanned_anim = "mgs4_grabbed_scan"

		if target:GetNWBool("is_grabbed_crouched", false) then
			scan_anim = "mgs4_grab_crouched_scan"
			scanned_anim = "mgs4_grabbed_crouched_scan"
		end

		local scanner_ent = ents.Create("prop_dynamic")

		scanner_ent:SetModel("models/mgs4/items/syringe.mdl")
		scanner_ent:FollowBone(self, self:LookupBone("ValveBiped.Bip01_R_Hand"))
		scanner_ent:SetLocalPos(Vector(3, -1, -1))
		scanner_ent:SetLocalAngles(Angle(100, 90, 0))
		scanner_ent:Spawn()

		-- Temporarily remove weapon from player until scan is complete
		local current_weapon = self:GetActiveWeapon()
		if IsValid(current_weapon) then
			self:SetActiveWeapon(NULL)
		end

		-- Get the scanned entity connections (their team or same type of npc)
		local connections = {}

		if not self or not IsValid(self) or not IsValid(target) then return end

		if target:IsPlayer() then
			-- Scan all teamates. Exceptions for TTT because it would be unfair otherwise.
			local target_role

			if GAMEMODE_NAME == "terrortown" then
				target_role = target:GetRole()
			end

			for _, ply in ipairs(player.GetAll()) do
				if GAMEMODE_NAME == "terrortown" then
					-- Scanning a detective, marks all of them.
					local role = ply:GetRole()

					if role == ROLE_DETECTIVE and target_role == ROLE_DETECTIVE and self:GetRole() then
						table.insert(connections, ply)
					end

					if ply == target then
						table.insert(connections, ply)
					end
				else
					if ply:Team() == target:Team() and ply ~= self then
						table.insert(connections, ply)
					end
				end
			end
		elseif target:IsNPC() then
			-- Scan all npcs of the same time within 1000 units
        	local class = target:GetClass()
			for _, npc in ipairs(ents.FindByClass(class)) do
				if npc ~= ent and npc:GetPos():DistToSqr(target:GetPos()) < (1000 * 1000) then
					table.insert(connections, npc)
				end
			end
		end

		local scanning_time = self:GetNWInt("scanner") * 10

		if ex then
			-- If using Scanner ex on a knocked out target then just skip all the animations and scan instantly
			
			-- TODO: Cleanup this mess
			net.Start("Scanner")
				net.WriteUInt(#connections, 8)
				for _, entity in ipairs(connections) do
					net.WriteEntity(entity)
				end
				net.WriteFloat(CurTime())
				net.WriteFloat(scanning_time)
			net.Send(self)

			self:SetNWEntity("scanner_ent", scanner_ent)

			return
		end
		
		-- Skip the animations

		self:ForcePosition(true)
		self:PlayMGS4Animation(scan_anim, function()
			-- Give back the weapon
			if IsValid(current_weapon) then
				self:SetActiveWeapon(current_weapon)
			end
			scanner_ent:Remove()
			self:SetNWFloat("stuck_check", 0)
			self:ForcePosition(false)

			-- First recorded usage of me actually using the net library o_o
			net.Start("Scanner")
				net.WriteUInt(#connections, 8)
				for _, entity in ipairs(connections) do
					net.WriteEntity(entity)
				end
				net.WriteFloat(CurTime())
				net.WriteFloat(scanning_time)
			net.Send(self)
		end, false)

		local angles = self:GetAngles()

		if self:IsPlayer() then
			angles = self:EyeAngles()
		end

		target:ForcePosition(true, target:GetPos(), angles)
		target:PlayMGS4Animation(scanned_anim, function()
			target:SetNWFloat("stuck_check", 0)
			target:ForcePosition(false)
		end, false)
	end

	function ent:Cqc_throw(target, direction)
		if not self or not IsValid(target) then return end

		local self_angles = self:GetAngles()

		if self:IsPlayer() then
			self_angles = self:EyeAngles()
		end

		local target_angles = target:GetAngles()

		if target:IsPlayer() then
			target_angles = target:EyeAngles()
		end

		local cqc_level = self:GetNWInt("cqc_level", 0)

		local speed_multipliers = {
			[0] = 1,
			[1] = 1,
			[2] = 1.2,
			[3] = 1.4,
			[4] = 1.6
		}

		local speed_modifier = speed_multipliers[cqc_level]

		if direction == 1 then
			-- Throw forward
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self_angles)
			self:PlayMGS4Animation("mgs4_grab_throw_forward", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true, speed_modifier)

			target:SetNWInt("last_nonlethal_damage_type", 3)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self_angles)
			target:PlayMGS4Animation("mgs4_grabbed_throw_forward", function()
				target:Cqc_reset()

				-- CQC level stun damage
				local stun_damage = 10 * cqc_level

				local target_psyche = target:GetNWFloat("psyche", 100)

				target:SetNWFloat("psyche", target_psyche - stun_damage)

				if target:GetNWFloat("psyche", 100) > 0 then
					target:StandUp()
				end

				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())

				target:ForcePosition(false)

			end, true, speed_modifier)
		elseif direction == 2 then
			-- Throw backward
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self_angles)
			self:PlayMGS4Animation("mgs4_grab_throw_backward", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true, speed_modifier)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self_angles)
			target:PlayMGS4Animation("mgs4_grabbed_throw_backward", function()
				target:Cqc_reset()

				-- CQC level stun damage
				local stun_damage = 10 * cqc_level

				local target_psyche = target:GetNWFloat("psyche", 100)

				target:SetNWFloat("psyche", target_psyche - stun_damage)

				if target:GetNWFloat("psyche", 100) > 0 then
					target:StandUp()
				end

				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())

				target:ForcePosition(false)

			end, true, speed_modifier)
		elseif direction == 3 then
			-- Front with weapon
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self_angles)
			self:PlayMGS4Animation("mgs4_cqc_throw_gun_front", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true, speed_modifier)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self_angles + Angle(0, 180, 0))
			target:PlayMGS4Animation("mgs4_cqc_throw_gun_front_victim", function()
				target:Cqc_reset()
				target:SetNWFloat("psyche", 0)
				target:ForcePosition(false)
				if target:IsPlayer() then
					target:SetEyeAngles(target_angles + Angle(0, 270, 0))
				else
					target:SetAngles(target_angles + Angle(0, 270, 0))
				end
				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
			end, true, speed_modifier)
		elseif direction == 4 then
			-- Back with weapon
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self_angles)
			self:PlayMGS4Animation("mgs4_cqc_throw_gun_back", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true, speed_modifier)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self_angles)
			target:PlayMGS4Animation("mgs4_cqc_throw_gun_back_victim", function()
				target:Cqc_reset()
				target:SetNWFloat("psyche", 0)
				target:ForcePosition(false)
				if target:IsPlayer() then
					target:SetEyeAngles(target_angles + Angle(0, 270, 0))
				else
					target:SetAngles(target_angles + Angle(0, 270, 0))
				end
				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
			end, true, speed_modifier)
		else
			-- Normal throw
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self_angles)
			self:PlayMGS4Animation("mgs4_cqc_throw", function()
				self:Cqc_reset()
				if self:IsPlayer() then
					self:SetEyeAngles(self_angles + Angle(0, 90, 0))
				else
					self:SetAngles(self_angles + Angle(0, 90, 0))
				end
				self:ForcePosition(false)
			end, true, speed_modifier)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos() + (self:GetAngles():Forward() * 30), self_angles + Angle(0, 180, 0))
			target:PlayMGS4Animation("mgs4_cqc_throw_victim", function()
				target:Cqc_reset()

				-- CQC level stun damage
				local stun_damage = 25 * cqc_level if cqc_level < 1 then stun_damage = 25 end

				local target_psyche = target:GetNWFloat("psyche", 100)

				target:SetNWFloat("psyche", target_psyche - stun_damage)

				if target:IsPlayer() then
					target:SetEyeAngles(target_angles + Angle(0, 180, 0))
				else
					target:SetAngles(target:GetAngles() + Angle(0, 180, 0))
				end

				if target:GetNWFloat("psyche", 100) > 0 then
					target:StandUp()
				end

				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
				target:ForcePosition(false)
			end, true, speed_modifier)
		end

		if self:GetNWEntity("knife", NULL) ~= NULL then
			self:GetNWEntity("knife", NULL):Remove()
			self:SetNWEntity("knife", NULL)
		end
	end

	function ent:Cqc_counter(target)
		if not self or not IsValid(target) then return end

		self:SetNWBool("is_in_cqc", true)

		target:SetNWBool("is_in_cqc", true)

		local angleAround = self:AngleAroundTarget(target)

		local countered_anim = "mgs4_cqc_countered"
		local counter_anim

		local target_angles = target:GetAngles()

		if target:IsPlayer() then
			target_angles = target:EyeAngles()
		end

		if angleAround > 135 and angleAround <= 225 then
			-- Countering from the back
			counter_anim = "mgs4_cqc_counter_back"
			self:ForcePosition(true, target:GetPos(), target_angles)
		else
			-- Countering from the front
			counter_anim = "mgs4_cqc_counter_front"
			self:ForcePosition(true, target:GetPos(), target_angles + Angle(0, 180, 0))
		end

		target:ForcePosition(true, target:GetPos(), target_angles)
		target:PlayMGS4Animation(counter_anim, function()
			target:Cqc_reset()
			target:ForcePosition(false)
		end, true)

		self:PlayMGS4Animation(countered_anim, function()
			self:Cqc_reset()

			-- CQC level stun damage
			local stun_damage = 50

			local psyche = self:GetNWFloat("psyche", 100)

			self:SetNWFloat("psyche", psyche - stun_damage)

			if self:GetNWFloat("psyche", 100) > 0 then
				self:StandUp()
			end

			self:ForcePosition(false)
		end, true)

	end


	-- == CQC Grabbing actions ==
	function ent:Cqc_grab(target)
		if not self or not IsValid(target) then return end

		self:SetNWBool("is_in_cqc", true)

		target:SetNWBool("is_in_cqc", true)

		target:SetNWFloat("grab_escape_progress", 100)

		-- Find out if grabbing from front or back
		local angleAround = self:AngleAroundTarget(target)

		-- Animation different on higher levels
		local cqc_level = self:GetNWInt("cqc_level", 0)

		local speed_multipliers = {
			[1] = 1,
			[2] = 1.25,
			[3] = 2.25,
			[4] = 2.50
		}

		local speed_modifier = speed_multipliers[cqc_level]

		local grab_anim
		local grabbed_anim
		local angle_offset = Angle(0,0,0)

		if angleAround > 135 and angleAround <= 225 then
			-- Grabbing from back
			local grab_standing_anim = "mgs4_grab_behind"
			local grabbed_standing_anim = "mgs4_grabbed_behind"

			local grab_standing_alt_anim = "mgs4_grab_behind_alt"
			local grabbed_standing_alt_anim = "mgs4_grabbed_behind_alt"

			local grab_crouched_anim = "mgs4_grab_crouched_behind"
			local grabbed_crouched_anim = "mgs4_grabbed_crouched_behind"

			if self:Crouching() then
				grab_anim = grab_crouched_anim
				grabbed_anim = grabbed_crouched_anim
			else
				if cqc_level >= 3 then
					grab_anim = grab_standing_anim
					grabbed_anim = grabbed_standing_anim
				else
					grab_anim = grab_standing_alt_anim
					grabbed_anim = grabbed_standing_alt_anim
				end
			end
		else
			-- Grabbing from front
			local grab_standing_anim = "mgs4_grab_front"
			local grabbed_standing_anim = "mgs4_grabbed_front"

			local grab_standing_alt_anim = "mgs4_grab_front_alt"
			local grabbed_standing_alt_anim = "mgs4_grabbed_front_alt"

			local grab_crouched_anim = "mgs4_grab_crouched_front"
			local grabbed_crouched_anim = "mgs4_grabbed_crouched_front"

			if self:Crouching() then
				grab_anim = grab_crouched_anim
				grabbed_anim = grabbed_crouched_anim
			else
				if cqc_level >= 3 then
					grab_anim = grab_standing_anim
					grabbed_anim = grabbed_standing_anim
				else
					grab_anim = grab_standing_alt_anim
					grabbed_anim = grabbed_standing_alt_anim
				end
			end

			angle_offset = Angle(0,180,0)
		end

		local self_angles = self:GetAngles()

		if self:IsPlayer() then
			self_angles = self:EyeAngles()
		end

		self:ForcePosition(true, self:GetPos(), self_angles)
		self:PlayMGS4Animation(grab_anim, function ()
			self:SetNWEntity("cqc_grabbing", target)
			self:ForcePosition(false)
			self:SetNWFloat("stuck_check", 0)
		end, true, speed_modifier)
		target:ForcePosition(true, self:GetPos(), self_angles + angle_offset)
		target:PlayMGS4Animation(grabbed_anim, function ()
			target:SetNWBool("is_grabbed", true)
			target:ForcePosition(false)
			target:SetNWFloat("stuck_check", 0)
		end, true, speed_modifier)
		
		-- Make them drop their weapon in an item box
		if self:GetNWInt("cqc_level", 0) >= 3 then
			timer.Simple(1.7 / speed_modifier, function ()
				target:DropWeaponAsItem()
			end)
		end

		if self:Crouching() then
			target:SetNWBool("is_grabbed_crouched", true)
			self:SetNWBool("is_grabbed_crouched", true)
		else
			target:SetNWBool("is_grabbed_crouched", false)
			self:SetNWBool("is_grabbed_crouched", false)
		end

		-- If they have the blades ability, show a knife in their left hand.
		if self:GetNWInt("blades", 0) > 0 then
			local knife_ent = ents.Create("prop_dynamic")

			knife_ent:SetModel("models/weapons/w_knife_t.mdl")
			knife_ent:FollowBone(self, self:LookupBone("ValveBiped.Bip01_L_Hand"))
			knife_ent:SetLocalPos(Vector(3, -1, 4))
			knife_ent:SetLocalAngles(Angle(0, 180, 180))
			knife_ent:Spawn()

			self:SetNWEntity("knife", knife_ent)
		end
	end

	function ent:Cqc_grab_crouch(target)
		if not self or not IsValid(target) then return end

		if not target:GetNWBool("is_grabbed_crouched", false) then
			self:PlayMGS4Animation("mgs4_grab_crouch", function ()
				self:SetNWBool("is_grabbed_crouched", true)
			end, true)

			target:PlayMGS4Animation("mgs4_grabbed_crouch", function ()
				target:SetNWBool("is_grabbed_crouched", true)
			end, true)
		else
			self:PlayMGS4Animation("mgs4_grab_crouched_stand", function ()
				self:SetNWBool("is_grabbed_crouched", false)
			end, true)

			target:PlayMGS4Animation("mgs4_grabbed_crouched_stand", function ()
				target:SetNWBool("is_grabbed_crouched", false)
			end, true)
		end
	end

	function ent:Cqc_grab_tchoke_start(target)
		if not self or not IsValid(target) then return end

		local self_angles = self:GetAngles()

		if self:IsPlayer() then
			self_angles = self:EyeAngles()
		end

		self:ForcePosition(true, self:GetPos(), self_angles)
		self:PlayMGS4Animation("mgs4_grab_crouched_tchoke_start", function ()
			self:ForcePosition(true, self:GetPos(), self_angles + Angle(0, 180, 0))
			self:SetNWBool("is_t_choking", true)
		end, false)

		target:ForcePosition(true, self:GetPos(), self_angles)
		target:PlayMGS4Animation("mgs4_grabbed_crouched_tchoke_start", function ()
			target:ForcePosition(true, self:GetPos(), self_angles + Angle(0, 180, 0))
			target:SetNWBool("is_t_choking", true)
			-- To make prone choking less of a gimmick, it makes it harder to escape after its started.
			target:SetNWFloat("grab_escape_progress", target:GetNWFloat("grab_escape_progress") + 70)
		end, false)
	end

	function ent:Cqc_grab_move(target)
		if not self or not IsValid(target) then return end

		self:PlayMGS4Animation("mgs4_grab_move", nil, true)

		target:PlayMGS4Animation("mgs4_grabbed_move", nil, true)
	end

	function ent:Cqc_grab_letgo(type, crouched)
		if not self then return end

		local letgo_anim

		if type == 0 then
			local standed_letgo_anim = "mgs4_grab_letgo"
			local standed_escaped_anim = "mgs4_grab_escaped"
			local crouched_letgo_anim = "mgs4_grab_crouched_letgo"
			local crouched_escaped_anim = "mgs4_grab_crouched_escaped"
			local target = self:GetNWEntity("cqc_grabbing", NULL)

			if crouched then
				if target:GetNWFloat("grab_escape_progress", 0) <= 0 then
					letgo_anim = crouched_escaped_anim
				else
					letgo_anim = crouched_letgo_anim
				end
			else
				if target:GetNWFloat("grab_escape_progress", 0) <= 0 then
					letgo_anim = standed_escaped_anim
				else
					letgo_anim = standed_letgo_anim
				end
			end
		elseif type == 1 then
			local standed_letgo_anim = "mgs4_grabbed_letgo"
			local standed_escaped_anim = "mgs4_grabbed_escaped"
			local crouched_letgo_anim = "mgs4_grabbed_crouched_letgo"
			local crouched_escaped_anim = "mgs4_grabbed_crouched_escaped"

			if crouched then
				if self:GetNWFloat("grab_escape_progress", 0) <= 0 then
					letgo_anim = crouched_escaped_anim
				else
					letgo_anim = crouched_letgo_anim
				end
			else
				if self:GetNWFloat("grab_escape_progress", 0) <= 0 then
					letgo_anim = standed_escaped_anim
				else
					letgo_anim = standed_letgo_anim
				end
			end
		elseif type == 2 then
			letgo_anim = "mgs4_grab_crouched_tchoke_end"
		elseif type == 3 then
			letgo_anim = "mgs4_grabbed_crouched_tchoke_end"
		end

		local self_angles = self:GetAngles()

		if self:IsPlayer() then
			self_angles = self:EyeAngles()
		end

		self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
		self:Cqc_reset()
		self:ForcePosition(true, self:GetPos(), self_angles)
		self:PlayMGS4Animation(letgo_anim, function ()
			self:ForcePosition(false)
			if self:IsPlayer() then
				self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36)) -- Set crouch hull back to normal
				self:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Set stand hull back to normal
				self:SetViewOffset(Vector(0, 0, 64)) -- Set stand view offset back to normal
			end
			self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())

			if type == 3 then
				self:StandUp()
			end

			if self:GetNWEntity("knife", NULL) ~= NULL then
				self:GetNWEntity("knife", NULL):Remove()
				self:SetNWEntity("knife", NULL)
			end
		end, true)
	end

	-- == Loop sequence to ensure correct positions at all times and handle grabbing actions ==
	function ent:Cqc_loop()
		if not self then return end

		local target = self:GetNWEntity("cqc_grabbing", NULL)
		if not IsValid(target) then return end

		-- If target or player dies, gets knocked out or player lets go. Stop the loop
		if not target:Alive() or not self:Alive() or self:GetNWBool("is_knocked_out", false) or target:GetNWBool("is_knocked_out", false) or target:GetNWFloat("psyche", 100) <= 0 or self:GetNWFloat("psyche", 100) <= 0 or self:KeyPressed(IN_JUMP) or target:GetNWFloat("grab_escape_progress", 0) <= 0 and not self:GetNWBool("animation_playing", false) and not target:GetNWBool("animation_playing", false) then
			-- Letgo animation on the player
			if self:Alive() and self:GetNWFloat("psyche", 100) > 0 then
				if self:GetNWBool("is_t_choking", false) then
					self:Cqc_grab_letgo(2, self:GetNWBool("is_grabbed_crouched", false))
				else
					self:Cqc_grab_letgo(0, self:GetNWBool("is_grabbed_crouched", false))
				end
			end

			-- Letgo animation on the target
			if target:Alive() and target:GetNWFloat("psyche", 100) > 0 then
				if target:GetNWBool("is_t_choking", false) then
					target:Cqc_grab_letgo(3, target:GetNWBool("is_grabbed_crouched", false))
				else
					target:Cqc_grab_letgo(1, target:GetNWBool("is_grabbed_crouched", false))
				end
			end

			return
		end

		local player_pos = self:GetPos()
		local player_angle = self:EyeAngles()

		target:SetPos(player_pos + (player_angle:Forward() * 5)) -- Move the target slightly forward
		if target:IsPlayer() then
			target:SetEyeAngles(player_angle)
		else
			target:SetAngles(Angle(0, player_angle.y, 0))
		end

		-- Target slowly is able to escape depending on cqc level
		target:SetNWFloat("grab_escape_progress", math.max(target:GetNWFloat("grab_escape_progress", 100) - ((1 / self:GetNWInt("cqc_level", 1)) * FrameTime() * 25), 0))

		if self:IsPlayer() then
			self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Crouch hull to standing height to teleporting up when ducking in animations
		end

		if self:GetNWBool("is_grabbed_crouched", false) then
			self:SetViewOffset(Vector(0, 0, 42)) -- Set crouch view offset
		else
			self:SetViewOffset(Vector(0, 0, 64)) -- Set stand view offset
		end

		if not self:GetNWBool("is_aiming", false) then
			if self:GetNWBool("cqc_button_held", false) and not self:KeyDown(IN_USE) and not self:KeyDown(IN_FORWARD) and not self:KeyDown(IN_BACK) and not self:GetNWBool("animation_playing") then
				-- Holding the CQC button starts choking
				target:SetNWFloat("psyche", math.max(target:GetNWFloat("psyche", 100) - ((20 * FrameTime()) * self:GetNWInt("cqc_level", 1)), 0))
				if target:GetNWBool("is_t_choking", false) then
					target:SetNWInt("last_nonlethal_damage_type", 3)
				else
					target:SetNWInt("last_nonlethal_damage_type", 2)
					target:SetNWBool("is_choking", true)
					self:SetNWBool("is_choking", true)
				end
			elseif self:GetNWBool("cqc_button_held", false) and self:GetNWFloat("cqc_button_hold_time", 0) < 0.2 and not self:KeyDown(IN_USE) and self:KeyDown(IN_FORWARD) and not self:KeyDown(IN_BACK) and not self:GetNWBool("animation_playing") then
				if self:GetNWBool("is_grabbed_crouched", false) then
					-- Start prone choke
					self:Cqc_grab_tchoke_start(target)
				else
					-- Holding and moving forward throws the target in front
					self:Cqc_throw(target, 1)
				end
			elseif self:GetNWBool("cqc_button_held", false) and self:GetNWFloat("cqc_button_hold_time", 0) < 0.2 and not self:KeyDown(IN_USE) and not self:KeyDown(IN_FORWARD) and self:KeyDown(IN_BACK) and not self:GetNWBool("animation_playing") then
				if self:GetNWBool("is_grabbed_crouched", false) then
					-- Start prone choke
					self:Cqc_grab_tchoke_start(target)
				else
					-- Holding and moving backward throws the target behind
					self:Cqc_throw(target, 2)
				end
			elseif self:GetNWBool("cqc_button_held", false) and self:GetNWFloat("cqc_button_hold_time", 0) < 0.2 and self:KeyDown(IN_USE) and self:GetNWInt("blades", 0) == 3 and not self:KeyDown(IN_FORWARD) and not self:KeyDown(IN_BACK) and not self:GetNWBool("animation_playing") then
				-- press e while holding cqc button does the throat cut
				self:Cqc_throat_cut(target)
			elseif not self:GetNWBool("cqc_button_held", false) and self:GetNWFloat("cqc_button_hold_time", 0) < 0.2 and self:KeyDown(IN_USE) and self:GetNWInt("scanner", 0) > 0 and not self:KeyDown(IN_FORWARD) and not self:KeyDown(IN_BACK) and not self:GetNWBool("animation_playing") then
				-- press e while not holding does the scan
				self:Cqc_sop_scan(target)
			elseif self:KeyDown(IN_BACK) and not target:GetNWBool("is_grabbed_crouched", false) and not self:GetNWBool("is_grabbed_crouched", false) and not self:GetNWBool("animation_playing") then
				-- Pressing back button moves backwards
				self:Cqc_grab_move(target)
			elseif self:KeyPressed(IN_DUCK) then
				-- Pressing crouch makes both the player and target crouch while grabbing
				self:Cqc_grab_crouch(target)
			else
				if target:GetNWBool("is_t_choking", false) then
					self:Cqc_grab_letgo(2)
					target:Cqc_grab_letgo(3)
				else
					target:SetNWBool("is_choking", false)
					self:SetNWBool("is_choking", false)
				end
			end
		end

		-- NPC Specific animations
		if target:IsNPC() and target:GetNWEntity("npc_proxy", NULL) == NULL and not target:GetNWBool("animation_playing", false) then
			local npc_proxy = ents.Create("mgs4_npc_sequence")

			target:SetNWEntity("npc_proxy", npc_proxy)

			npc_proxy.NPC = target

			local grabbed_anim = "mgs4_grabbed_loop"
				
			npc_proxy.Sequence = grabbed_anim
			npc_proxy:SetPos(target:GetPos())
			npc_proxy:SetAngles(target:GetAngles())
			npc_proxy:Spawn()
		elseif target:IsNPC() and target:GetNWEntity("npc_proxy", NULL) ~= NULL and not target:GetNWBool("animation_playing", false) then
			local npc_proxy = target:GetNWEntity("npc_proxy", NULL)

			local active_sequence = npc_proxy:GetSequence()

			local grabbed_loop = npc_proxy:LookupSequence("mgs4_grabbed_loop")
			local grabbed_chocking = npc_proxy:LookupSequence("mgs4_grabbed_chocking")

			local grabbed_t_chocking = npc_proxy:LookupSequence("mgs4_grabbed_crouched_tchoke_loop")

			local grabbed_crouched_loop = npc_proxy:LookupSequence("mgs4_grabbed_crouched_loop")
			local grabbed_crouched_chocking = npc_proxy:LookupSequence("mgs4_grabbed_crouched_chocking")

			if target:GetNWBool("is_t_choking", false) and active_sequence ~= grabbed_t_chocking then
				npc_proxy:ResetSequence(grabbed_t_chocking)
			elseif target:GetNWBool("is_choking", false) then
				if target:GetNWBool("is_grabbed_crouched", false) and active_sequence ~= grabbed_crouched_chocking then
					npc_proxy:ResetSequence(grabbed_crouched_chocking)
				elseif !target:GetNWBool("is_grabbed_crouched", false) and active_sequence ~= grabbed_chocking then
					npc_proxy:ResetSequence(grabbed_chocking)
				end
			else
				if target:GetNWBool("is_grabbed_crouched", false) and not target:GetNWBool("is_t_choking", false) and active_sequence ~= grabbed_crouched_loop then
					npc_proxy:ResetSequence(grabbed_crouched_loop)
				elseif !target:GetNWBool("is_grabbed_crouched", false) and not target:GetNWBool("is_t_choking", false)  and active_sequence ~= grabbed_loop then
					npc_proxy:ResetSequence(grabbed_loop)
				end
			end
		end
	end

	function ent:Cqc_check()
		if not self then return end

		local is_in_cqc = self:GetNWBool("is_in_cqc", false)
		local cqc_target = self:TraceForTarget()
		local cqc_level = self:GetNWInt("cqc_level", 1)
		local large_weapon = true -- Large weapons have a different CQC action and can only throw with EX level CQC

		local current_weapon = self:GetActiveWeapon()
		if IsValid(current_weapon) then
			local weapon_hold_type = current_weapon:GetHoldType()
			-- Check if the weapon is a small hold type then assume its a small weapon
			-- I know its trash but it generally covers most use cases since getting the weapon slot is not reliable
			for _, hold_type in pairs(Small_weapons_holdtypes) do
				if weapon_hold_type == hold_type then
					large_weapon = false
					break
				end
			end
		else
			large_weapon = false
		end

		if is_in_cqc or cqc_level < 0 or not cqc_target then return end

		if ((self:IsOnGround() and !IsValid(cqc_target)) or (cqc_target:GetNWBool("is_in_cqc", false) or cqc_target:GetNWBool("is_knocked_out", false) or cqc_target:GetNWFloat("cqc_immunity_remaining", 0) > 0)) and not large_weapon then
			self:Cqc_fail()
		elseif(IsValid(cqc_target) and cqc_target:Alive() and cqc_target:GetNWFloat("psyche", 100) > 0) then
			local will_grab = self:GetNWBool("will_grab", false)
			local cqc_target_level = cqc_target:GetNWInt("cqc_level", 1)

			if self:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() and !cqc_target:GetNWBool("is_in_cqc", false) and !cqc_target:GetNWBool("is_knocked_out", false) and cqc_target_level == 4 and cqc_level < 4 then
				self:Cqc_counter(cqc_target)
			elseif self:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() and will_grab and cqc_level >= 1 and !cqc_target:GetNWBool("is_in_cqc", false) and !cqc_target:GetNWBool("is_knocked_out", false) and not large_weapon then
				self:Cqc_grab(cqc_target)
			elseif self:IsOnGround() and IsValid(cqc_target) and cqc_target:IsOnGround() and !cqc_target:GetNWBool("is_in_cqc", false) and !cqc_target:GetNWBool("is_knocked_out", false) and (not large_weapon or cqc_level >= 4) then
				local direction
				if large_weapon and cqc_level >= 4 then
					local angle_around = self:AngleAroundTarget(cqc_target)
					if angle_around > 135 and angle_around <= 225 then
						direction = 4 -- Backward with weapon
					else
						direction = 3 -- Forward with weapon
					end
				end
				self:Cqc_throw(cqc_target, direction)
			end
		end
	end

	-- Not literally helping yourself (you are helping another get up, its an mgo2 reference)
	function ent:GetYourselfUp()
		if not self then return end

		local target = self:TraceForTarget()

		if not target or not IsValid(target) then
			self:SetNWBool("helping_up", false)
			return
		end

		if self:GetNWBool("helping_up", false) and target:GetNWBool("is_knocked_out", false) and not self:GetNWBool("cqc_button_held") then
			target:SetNWFloat("psyche", target:GetNWFloat("psyche", 100) + (GetConVar("mgs4_psyche_recovery_action"):GetFloat() * FrameTime() * 10))

			-- Yup, this happens to return the right timings for sfx
			local cool_as_cycle_with_tan_for_some_reason = math.Truncate(math.tanh(self:GetCycle()), 2)

			if cool_as_cycle_with_tan_for_some_reason == 0.4 or cool_as_cycle_with_tan_for_some_reason == 0.6 then
				self:EmitSound("sfx/hit.wav", 75, 70, 0.2)
			end

		elseif not self:GetNWBool("helping_up", false) and target:GetNWBool("is_knocked_out", false) and self:Crouching() then
			local current_weapon = self:GetActiveWeapon()
			if IsValid(current_weapon) then
				self:SetActiveWeapon(NULL)
				self:SetNWEntity("holster_weapon", current_weapon)
			end

			self:PlayMGS4Animation("mgs4_wakeup_start", function()
				self:SetNWBool("helping_up", true)
				-- Scanner EX
				if self:GetNWBool("cqc_button_held") and not self:GetNWBool("scanning_ex", false) then
					self:SetNWBool("scanning_ex", true)
					self:EmitSound("sfx/scan_start.wav", 75, 100, 1, CHAN_WEAPON)
					self:Cqc_sop_scan(target, true)
				end
				self:SetCycle(0)
			end, false)
		elseif self:GetNWBool("helping_up", false) and not target:GetNWBool("is_knocked_out", false) then
			self:SetNWBool("is_using", false)
		end

	end

	-- === Handling the CQC buttons ===
	-- Not gonna lie, I have no idea if this is even a good way to do this. It seems to convoluted, but it works so screw it.

	hook.Add("PlayerButtonDown", "MGS4PlayerButtonDown", function(ply, button)
		-- Players need to have a client convar set for the CQC button. By default its 110 (Mouse 4)
		local cqc_button = ply:GetInfoNum("mgs4_cqc_button", 110)

		if button == cqc_button then
			ply:SetNWBool("cqc_button_held", true)
		end
	end)

	hook.Add("PlayerButtonUp", "MGS4PlayerButtonUp", function(ply, button)
		local cqc_button = ply:GetInfoNum("mgs4_cqc_button", 110)

		if button == cqc_button then
			ply:SetNWBool("cqc_button_held", false)
		end
	end)

	hook.Add("KeyPress", "MGS4PlayerKeyPress", function(ply, key)
		if key == IN_FORWARD or key == IN_BACK or key == IN_MOVELEFT or key == IN_MOVERIGHT then
			ply:SetNWBool("will_grab", false)
		end

		if key == IN_ATTACK2 and ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("is_t_choking", false) then
			ply:SetNWBool("is_aiming", not ply:GetNWBool("is_aiming", false))
		end

		if key == IN_ATTACK and ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("is_aiming", false)  and not ply:GetNWBool("is_t_choking", false) then
			ply:SetNWBool("is_knife", true)
		end

		if key == IN_USE  and not ply:GetNWBool("is_t_choking", false) then
			ply:SetNWBool("is_using", true)
		end
	end)

	hook.Add("KeyRelease", "MGS4PlayerKeyRelease", function(ply, key)
		if key == IN_FORWARD or key == IN_BACK or key == IN_MOVELEFT or key == IN_MOVERIGHT then
			ply:SetNWBool("will_grab", true)
		end

		if key == IN_USE and not ply:GetNWBool("animation_playing", false) then
			ply:SetNWBool("is_using", false)
		end
	end)

	-- === Knockout Loop ===
	function KnockoutLoop(entity)
		if entity:GetNWFloat("psyche", 100) >= 100 then
			entity:SetNWBool("is_knocked_out", false)
			entity:SetNWFloat("psyche", 100)
			if entity:GetNWInt("last_nonlethal_damage_type", 0) ~= 1 then
				entity:EmitSound("sfx/stars.wav", 75, 100, 1, CHAN_VOICE)
			end

			if entity:IsNPC() and entity:GetNWEntity("npc_proxy", NULL) ~= NULL then
				local npc_proxy = entity:GetNWEntity("npc_proxy", NULL)
				npc_proxy:Stop()
				npc_proxy:Remove()
				entity:SetNWEntity("npc_proxy", NULL)
			end

			entity:StandUp()
		else
			entity:SetNWBool("animation_playing", true)
			entity:SetVelocity(-entity:GetVelocity())

			if entity:IsNPC() and entity:GetNWEntity("npc_proxy", NULL) == NULL and entity:Alive() then
				local npc_proxy = ents.Create("mgs4_npc_sequence")

				entity:SetNWEntity("npc_proxy", npc_proxy)

				npc_proxy.NPC = entity

				local knockout_type = entity:GetNWInt("last_nonlethal_damage_type", 0)

				local knockout_anim

				if knockout_type == 0 then
					knockout_anim = "mgs4_knocked_out_loop_faceup"
				else
					knockout_anim = "mgs4_knocked_out_loop_facedown"
				end
					
				npc_proxy.Sequence = knockout_anim
				npc_proxy:SetPos(entity:GetPos())
				npc_proxy:SetAngles(entity:GetAngles())
				npc_proxy:Spawn()
			end

			local psyche = entity:GetNWFloat("psyche", 100)
			if psyche < 100 then
				psyche = psyche + GetConVar("mgs4_psyche_recovery"):GetFloat() * FrameTime()
				entity:SetNWFloat("psyche", math.min(psyche, 100)) -- Cap at 100
			end

			-- Play stars sound effects when reaching certain psyche thresholds (but not for tranquilizer knockouts)
			if entity:GetNWInt("last_nonlethal_damage_type", 0) ~= 1 then
				local prev_psyche = entity:GetNWFloat("prev_psyche", psyche)
				local thresholds = {20, 40, 60, 80}
				for _, threshold in ipairs(thresholds) do
					if math.floor(prev_psyche) < threshold and math.floor(psyche) >= threshold then
						entity:EmitSound("sfx/stars.wav", 75, 100, 1, CHAN_VOICE)
					end
				end
			end
			entity:SetNWFloat("prev_psyche", psyche)
		end
	end

	function SetUpEnt(entity)
		--- Only affects players
		entity:SetNWBool("animation_playing", false)

		entity:SetNWBool("will_grab", false)
		entity:SetNWEntity("cqc_grabbing", NULL)

		entity:SetNWBool("is_in_cqc", false)
		entity:SetNWBool("is_grabbed", false)
		entity:SetNWBool("is_grabbed_crouched", false)
		entity:SetNWBool("is_t_choking", false)
		entity:SetNWBool("is_choking", false)
		entity:SetNWBool("is_aiming", false)
		entity:SetNWBool("is_knife", false)
		entity:SetNWBool("is_using", false)

		--- Progress remaining to escape a grab.
		entity:SetNWFloat("grab_escape_progress", 100)

		--- Variables to force a position on the player at certain times
		entity:SetNWBool("force_position", false)
		entity:SetNWVector("forced_position", Vector(0, 0, 0))
		entity:SetNWAngle("forced_angle", Angle(0, 0, 0))

		--- == Skills ==

		-- Each CQC Level grants you:
		-- -2 = Nothing
		-- -1 = Punch punch kick combo
		--  0 = CQC throw
		--  1 = (CQC+1) Grabs
		--  2 = (CQC+2) Higher stun damage
		--  3 = (CQC+3) Higher stun damage and take weapons from enemies
		--  4 = (CQCEX) Counter CQC and maximum stun damage
		entity:SetNWInt("cqc_level", GetConVar("mgs4_base_cqc_level"):GetInt())

		-- Other skills
		entity:SetNWInt("blades", 0)
		entity:SetNWInt("scanner", 0)

		-- In some animations we hide the gun, so we need to store it here
		entity:SetNWEntity("holster_weapon", NULL)

		entity:SetNWEntity("knife", NULL)

		-- How long the player is holding the CQC button for (for knowing if they want to grab or punch)
		entity:SetNWBool("cqc_button_held", false)
		entity:SetNWFloat("cqc_button_hold_time", 0)

		-- Time of the punch punch kick combo. Keep pressing to complete the combo, press it once to just punch once.
		entity:SetNWFloat("cqc_punch_time_left", 0)

		entity:SetNWInt("cqc_punch_combo", 0) -- 1 = First punch, 2 = Second punch, 3 = Kick
		entity:SetNWBool("helping_up", false)

		--- Immunity to CQC for a few seconds to make it fairer
		entity:SetNWFloat("cqc_immunity_remaining", 0)

		--- Psyche
		--- If it reaches 0, the entity will be knocked out
		--- Only regenerates when knocked out or if reading a magazine
		entity:SetNWFloat("psyche", 100)

		entity:SetNWBool("is_knocked_out", false)

		---- Last Non-Lethal Damage Type
		--- 0 = Stun (Face up)
		--- 1 = Tranquilizers
		--- 2 = Generic Stun
		--- 3 = Stun (Face down)
		entity:SetNWInt("last_nonlethal_damage_type", 0)

		if entity:GetNWEntity("knife", NULL) ~= NULL then
			entity:GetNWEntity("knife", NULL):Remove()
		end
	end

	-- === Initialization ===
	hook.Add("PlayerSpawn", "MGS4PlayerSpawn", function(ent)
		SetUpEnt(ent)
	end)

	hook.Add("OnEntityCreated", "MGS4EntityCreated", function (ent)
		if not ent:IsPlayer() then
			SetUpEnt(ent)
		end
	end)

	-- Cleanup on player death
	hook.Add("DoPlayerDeath", "MGS4PlayerPreDeathCleanup", function(ply, attacker, dmg)
		if ply:GetNWBool("cqc_grabbing", NULL) ~= NULL then
			ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36)) -- Set crouch hull back to normal
			ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Set stand hull back to normal
			ply:SetViewOffset(Vector(0, 0, 64)) -- Set stand view offset back to normal
			local target = ply:GetNWBool("cqc_grabbing", NULL)
			target:Cqc_grab_letgo(1, target:GetNWBool("is_grabbed_crouched", false))
		end
		SetUpEnt(ply)
	end)

	-- === Non lethal Damage Handling ===
	hook.Add("EntityTakeDamage", "MGS4EntityTakeDamage", function(ent, dmginfo)
		if not IsValid(ent) then return end

		if dmginfo:GetAttacker():GetNWEntity("cqc_grabbing", NULL) == ent then
			-- Prevent damage from the grabber while being grabbed
			return true
		end

		-- Check if the entity is a player or NPC
		if GetConVar("mgs4_psyche_physics_damage"):GetBool() and (ent:IsPlayer() or ent:IsNPC()) then
			if ent:GetNWBool("is_knocked_out", false) then return end

			if dmginfo:GetDamageType() == DMG_CRUSH then
				-- Halve the physical damage in exchange for double psyche damage
				local psyche = ent:GetNWFloat("psyche", 100)
				local multiplier = GetConVar("mgs4_psyche_physics_mutliplier"):GetFloat()
				local disable_physics_dmg = multiplier < 0

				-- Negative multiplier just means only damage the psyche. So we turn it back to positive.
				if disable_physics_dmg then
					multiplier = math.abs(multiplier)
				end

				local psyche_dmg = dmginfo:GetDamage() * multiplier

				psyche = psyche - psyche_dmg
				ent:SetNWFloat("psyche", math.max(psyche, 0)) -- Cap at 0

				-- Knockback animations depending on psyche damage
				local damageDir = (ent:GetPos() - dmginfo:GetDamagePosition()):GetNormalized()
				local angleAround = math.deg(math.atan2(damageDir.y, damageDir.x))
				
				-- Convert to player-relative angle
				local entAngle = ent:GetAngles().y

				local crouching = false

				if ent:IsPlayer() then
					entAngle = ent:EyeAngles().y
					crouching = ent:Crouching()
				end

				local relativeAngle = math.NormalizeAngle(angleAround - entAngle)

				if psyche_dmg >= 10 and psyche_dmg < 50 then
					if crouching then
						-- Only front/back knockback when crouched
						if math.abs(relativeAngle) <= 90 then
							ent:PlayMGS4Animation("mgs4_knockback_small_back_crouched", nil, true)
						else
							ent:PlayMGS4Animation("mgs4_knockback_small_front_crouched", nil, true)
						end
					else
						-- Only front/back knockback when standing
						if math.abs(relativeAngle) <= 90 then
							ent:PlayMGS4Animation("mgs4_knockback_small_back", nil, true)
						else
							ent:PlayMGS4Animation("mgs4_knockback_small_front", nil, true)
						end
					end
					ent:SetNWInt("last_nonlethal_damage_type", 2)
				elseif psyche_dmg >= 50 then
					if math.abs(relativeAngle) <= 90 then
						ent:PlayMGS4Animation("mgs4_knockback_big_back", function ()
							if psyche > 0 then
								ent:StandUp()
							end
						end, true)
						ent:SetNWInt("last_nonlethal_damage_type", 3)
					else
						ent:PlayMGS4Animation("mgs4_knockback_big_front", function ()
							if psyche > 0 then
								ent:StandUp()
							end
						end, true)
						ent:SetNWInt("last_nonlethal_damage_type", 0)
					end
				end

				if disable_physics_dmg then return true end
				dmginfo:SetDamage( dmginfo:GetDamage() / 2 )
			end
		end
	end)

	local disable_psyche_damage = false

	-- === Handles systems every tick like grabbing and psyche ===
	hook.Add("Tick", "MGS4Tick", function()
        local npc_and_players = ents.FindByClass("player") -- Find all players
        npc_and_players = table.Add(npc_and_players, ents.FindByClass("npc_*")) -- Add all NPCs

		for _, entity in ipairs(npc_and_players) do
			if entity:LookupBone("ValveBiped.Bip01_Pelvis") == nil then return end

			if entity:GetNWFloat("psyche", 100) <= 0 and not entity:GetNWBool("is_knocked_out", false) and not entity:GetNWBool("animation_playing", false) then
				entity:SetNWFloat("psyche", 0)
				entity:Knockout()
			end

			if entity:GetNWBool("is_knocked_out", true) then
				KnockoutLoop(entity)
			end

			if entity:GetNWBool("cqc_button_held") and not entity:GetNWBool("animation_playing", false) and entity:OnGround() then
				entity:SetNWFloat("cqc_button_hold_time", entity:GetNWFloat("cqc_button_hold_time", 0) + FrameTime())
			end

			if entity:GetNWFloat("cqc_immunity_remaining", 0) > 0 then
				entity:SetNWFloat("cqc_immunity_remaining", entity:GetNWFloat("cqc_immunity_remaining", 0) - FrameTime())
				if entity:GetNWFloat("cqc_immunity_remaining", 0) < 0 then
					entity:SetNWFloat("cqc_immunity_remaining", 0)
				end
			end

			-- Hold the use button while crouched next to a knocked out entity to help them wake up
			if entity:GetNWBool("is_using", false) or (entity:GetNWBool("cqc_button_held") and entity:GetNWInt("scanner", 0) > 3) then
				entity:GetYourselfUp()
			elseif not entity:GetNWBool("is_using", false) and entity:GetNWBool("helping_up", false) and not entity:GetNWBool("animation_playing", false) then
				entity:PlayMGS4Animation("mgs4_wakeup_end", function()
					entity:SetNWBool("helping_up", false)
					if entity:GetNWEntity("holster_weapon", NULL) ~= NULL then
						entity:DrawViewModel(true)
						entity:SetActiveWeapon(entity:GetNWEntity("holster_weapon", NULL))
						entity:SetNWEntity("holster_weapon", NULL)
					end
				end, false)
				-- Scanner EX
				if entity:GetNWBool("scanning_ex", false) then
					entity:EmitSound("sfx/scan_end.wav", 75, 100, 1, CHAN_WEAPON)
					entity:SetNWBool("scanning_ex", false)
					entity:GetNWEntity("scanner_ent", NULL):Remove()
				end
			end

			-- Press it once for Punch
			if entity:GetNWBool("cqc_button_held", false) == false and entity:GetNWFloat("cqc_button_hold_time", 0) > 0 and entity:GetNWFloat("cqc_button_hold_time", 0) <= 0.5 and not entity:GetNWBool("animation_playing", false) and not entity:GetNWBool("helping_up", false) then
				entity:SetNWFloat("cqc_button_hold_time", 0)
				entity:Cqc_punch()
			end

			-- Hold the button for CQC Throw and Grab
			if entity:GetNWFloat("cqc_button_hold_time", 0) > 0.2 and entity:GetNWEntity("cqc_grabbing") == NULL and not entity:GetNWBool("animation_playing", false) and not entity:GetNWBool("helping_up", false) then
				entity:SetNWBool("cqc_button_held", false)
				entity:SetNWFloat("cqc_button_hold_time", 0)
				entity:Cqc_check()
			end

			if entity:GetNWFloat("cqc_punch_time_left", 0) > 0 then
				entity:SetNWFloat("cqc_punch_time_left", math.max(entity:GetNWFloat("cqc_punch_time_left", 0) - FrameTime(), 0))
			else
				entity:SetNWInt("cqc_punch_combo", 0) -- Reset combo
			end

			if entity:GetNWBool("force_position", false) then
				local pos = entity:GetNWVector("forced_position", Vector(0, 0, 0))
				local ang = entity:GetNWAngle("forced_angle", Angle(0, 0, 0))

				entity:SetPos(pos)

				if entity:IsPlayer() then
					entity:SetEyeAngles(ang)
				else
					entity:SetAngles(ang)
				end
			end

			if entity:GetNWEntity("cqc_grabbing", NULL) ~= NULL then
				entity:Cqc_loop()
			end

			-- Freeze when animation is playing but can still take damage
			if entity:GetNWBool("animation_playing", true) then
				if entity:IsPlayer() then
					entity:Freeze(true)
					if entity:GetAngles().y ~= entity:EyeAngles().y then
						-- If they are a player we need to ensure the body is rotated to the eyeangles (only viable way i found is adding some dummy velocity)
						local dir = entity:EyeAngles():Forward()
						entity:SetVelocity(dir * 10)
					end
				elseif entity:IsNPC() then
					entity:SetNPCState(NPC_STATE_SCRIPT)
				elseif entity:IsNextBot() then
					entity:StartActivity(ACT_IDLE)
				end
				entity:SetNWFloat("stuck_check", 1.0)
			else
				if entity:IsPlayer() then
					entity:Freeze(false)
				end
			end

			if entity:GetNWFloat("stuck_check") > 0 then
				entity:MGS4StuckCheck()
				entity:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

				entity:SetNWFloat("stuck_check", entity:GetNWFloat("stuck_check", 0) - FrameTime())
			elseif not entity:GetNWBool("is_knocked_out", true) then
				if entity:IsPlayer() then	
					entity:SetCollisionGroup(COLLISION_GROUP_PLAYER)
				else
					entity:SetCollisionGroup(COLLISION_GROUP_NPC)
				end
			end

			-- TTT Specific
			if disable_psyche_damage then
				entity:SetNWFloat("psyche", 100)
			end
		end
	end)

	-- Trouble in terrorist town specific hooks
	hook.Add("TTTOrderedEquipment", "MGS4TTTOrderedEquipment", function(ply, equipment, is_item)
		if equipment == EQUIP_MGS4_SCANNER_3 then
			ply:SetNWInt("scanner", 3)
		elseif equipment == "weapon_ttt_knife" then
			ply:SetNWInt("blades", 3)
		end
	end)

	hook.Add("TTTPrepareRound", "MGS4DisablePsycheDamage", function ()
		disable_psyche_damage = true
	end)

	hook.Add("TTTBeginRound", "MGS4DisableEnableDamage", function ()
		disable_psyche_damage = false

		-- Grant CQC levels based on cvars
		local detective_cqc_level = GetConVar("ttt_mgs4_base_cqc_level_detective"):GetInt()
		local traitor_cqc_level = GetConVar("ttt_mgs4_base_cqc_level_traitor"):GetInt()

		local players = player.GetAll()

		for _, ply in ipairs(players) do
			local role = ply:GetRole()

			if role == ROLE_DETECTIVE then
				ply:SetNWInt("cqc_level", detective_cqc_level)
			elseif role == ROLE_TRAITOR then
				ply:SetNWInt("cqc_level", traitor_cqc_level)
			end
		end
	end)
else
	-- === Camera ===
	hook.Add( "CalcView", "MGS4Camera", function( ply, pos, angles, fov )
		local is_in_anim = ply:GetNWBool("animation_playing", false) or (ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("is_aiming", false)) or ply:GetNWFloat("cqc_punch_time_left", 0) > 0 or ply:GetNWBool("helping_up", false) or ply:GetNWBool("is_grabbed", false)

		if ply:Team() == TEAM_SPECTATOR or GetViewEntity() ~= LocalPlayer() or is_in_anim == false or GetConVar("mgs4_disable_camera_manipulation"):GetBool() then return end

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

		local pelvis_bone = ply:LookupBone("ValveBiped.Bip01_Pelvis")
		local pelvis_pos = pelvis_bone and ply:GetBonePosition(pelvis_bone) or pos
		local origin = pelvis_pos + Vector(0, 0, 30) -- Origin point for camera rotation

		local mouse_angles = ply:GetNWAngle("mouse_angle", Angle(0,0,0))
		local camera_distance = thirdperson and 60 or 0
		
		-- Calculate camera position by rotating around the origin
		local camera_pos

		if thirdperson then
			-- Trace from origin to desired camera position to check for collisions
			local trace = util.TraceLine({
				start = origin,
				endpos = origin - (mouse_angles:Forward() * camera_distance),
				mask = MASK_SOLID_BRUSHONLY,
				filter = ply
			})
			
			-- If we hit something, position camera at the hit point
			if trace.Hit then
				camera_distance = trace.Fraction * camera_distance
			end

			local forward = mouse_angles:Forward()
			camera_pos = origin - (forward * camera_distance)
		else
			camera_pos = head_pos
		end

		local view = {
			origin = camera_pos,
			angles = (thirdperson and mouse_angles or mouse_angles),
			fov = fov,
			drawviewer = true
		}

		return view
	end )

	-- == First person adjustments while grabbing ==
	hook.Add("PostDrawViewModel", "MGS4FirstPersonAdjustments", function (vm, ply, wpn)
		if not IsValid(vm) then return end

		for _, boneName in ipairs(Bones_to_hide) do
			local bone = vm:LookupBone(boneName)
			if bone then
				local nan = 0/0
				if ply:GetNWBool("is_aiming") then
					-- Hide the bone
					vm:ManipulateBoneScale(bone, Vector(nan,nan,nan))
				else
					-- Reset the bone to normal
					vm:ManipulateBoneScale(bone, Vector(1,1,1))
				end
			end
		end
	end)

	surface.CreateFont("MGS4HudNumbers", {
		font = "Tahoma",
		size = math.max(1, 72 * (ScrH() / 1080)),
		blursize = 0,
		scanlines = 0,
		antialias = true,
		underline = false,
		italic = false,
		strikeout = false,
		symbol = false,
		rotary = false,
		shadow = false,
		additive = false,
		outline = false,
	})

	hook.Add("HUDPaint", "MGS4HUDPaint", function()
		local ply = LocalPlayer()

		if ply:Alive() == false then return end

		local refW, refH = 1920, 1080

		if GetConVar("mgs4_show_skill_hud"):GetBool() then
			-- Player skills hud

			local cqc_level = ply:GetNWInt("cqc_level", 0)
			local blades = ply:GetNWInt("blades", 0)
			local scanner = ply:GetNWInt("scanner", 0)

			local cqc_label = Ability_names["cqc_level"]
			local blades_label = Ability_names["blades"]
			local scanner_label = Ability_names["scanner"]

			local hud_items = {}

			if cqc_level > 0 then
				table.insert(hud_items, { label = cqc_label(cqc_level, true), value = cqc_level < 4 and cqc_level or nil })
			end

			if blades > 0 then
				table.insert(hud_items, { label = blades_label(blades, true), value = blades < 4 and blades or nil })
			end

			if scanner > 0 then
				table.insert(hud_items, { label = scanner_label(scanner, true), value = scanner < 4 and scanner or nil })
			end

			local baseY = 715
			local offsetY = 20

			for i, item in ipairs(hud_items) do
				local y = ScrH() * (baseY / refH) + (i - 1) * (ScrH() * (offsetY / refH))
				draw.SimpleText(item.label, "HudDefault", ScrW() * (135 / refW), y, Color(255,255,0,255), TEXT_ALIGN_LEFT)
				if item.value then
					draw.SimpleText(item.value, "HudDefault", ScrW() * (255 / refW), y, Color(255,255,0,255), TEXT_ALIGN_LEFT)
				end
			end
		end

		-- Psyche in Hud

		if GetConVar("mgs4_show_psyche_hud"):GetBool() then
			if GAMEMODE_NAME == "terrortown" then
				-- TODO: Draw psyche in the same style as TTT's HUD
			else
				local psyche = ply:GetNWFloat("psyche", 0)

				local xOffset = 0
				if ply:Armor() > 0 then
					xOffset = 295
				end

				local baseX, baseY = 315 + xOffset, 973
				local boxW, boxH = 245, 80

				-- Use the same screen scaling as above
				draw.RoundedBox(10,
					ScrW() * (baseX / refW),
					ScrH() * (baseY / refH),
					ScrW() * (boxW / refW),
					ScrH() * (boxH / refH),
					Color(0, 0, 0, 80)
				)

				draw.SimpleText("PSYCHE", "HudDefault",
					ScrW() * ((335 + xOffset) / refW),
					ScrH() * (1015 / refH),
					Color(255, 205, 0, 255),
					TEXT_ALIGN_LEFT
				)

				draw.SimpleText(tostring(math.Round(psyche, 0)),
					"MGS4HudNumbers",
					ScrW() * ((440 + xOffset) / refW),
					ScrH() * (975 / refH),
					Color(255, 205, 0, 255),
					TEXT_ALIGN_LEFT
				)
			end
		end

		if GetConVar("mgs4_show_tips_hud"):GetBool() then
			-- Tips to show
			local tip_actions = {}

			local function DrawKeyCombo(x, y, combo)
				local offset = 0
				local iconSize_w = 44
				local iconSize_h = 24

				for i, item in ipairs(combo) do
					if type(item) == "IMaterial" then
						surface.SetMaterial(item)
						surface.SetDrawColor(255,255,255,255)
						surface.DrawTexturedRect(x + offset, y, iconSize_w, iconSize_h)
						offset = offset + iconSize_w + 6
					else
						surface.SetTextColor(255,255,255,255)
						surface.SetTextPos(x + offset, y + 4)
						surface.DrawText(item)
						local w,_ = surface.GetTextSize(item)
						offset = offset + w + 6
					end

					if i < #combo then
						surface.SetTextColor(255,255,255,200)
						surface.SetTextPos(x + offset, y + 4)
						surface.DrawText("+")
						local w,_ = surface.GetTextSize("+")
						offset = offset + w + 6
					end
				end
			end

			-- Grabbing tips
			if ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("animation_playing", false) and not ply:GetNWBool("is_aiming", false) then
				local grab_actions = {
					{
						icon = Grab_choke,
						key = { Cqc_button }
					},
					{
						icon = Grab_aim,
						key = {	input.LookupBinding("+attack2") or "M2" }
					}
				}

				tip_actions = table.Add(tip_actions, grab_actions)

				if ply:GetNWInt("blades", 0) >= 3 then
					local grab_knife_action = {
						{
							icon = Grab_knife,
							key = {
								Cqc_button,
								input.LookupBinding("+use") or "E"
							}
						}
					}

					tip_actions = table.Add(tip_actions, grab_knife_action)
				end

				if ply:GetNWInt("scanner", 0) > 0 then
					local grab_scan_action = {
						{
							icon = Grab_scan,
							key = {	input.LookupBinding("+use") or "E" }
						}
					}

					tip_actions = table.Add(tip_actions, grab_scan_action)
				end

				if ply:GetNWBool("is_grabbed_crouched") then
					local grab_crouched_actions = {
						{
							icon = Grab_choke_prone,
							key = {
								Cqc_button,
								input.LookupBinding("+back") or "S"
							}
						}
					}

					tip_actions = table.Add(tip_actions, grab_crouched_actions)
				else
					local grab_stand_actions = {
						{
							icon = Grab_throw_forward,
							key = {
								Cqc_button,
								input.LookupBinding("+forward") or "W"
							}
						},
						{
							icon = Grab_throw_backward,
							key = {
								Cqc_button,
								input.LookupBinding("+back") or "S"
							}
						}
					}

					tip_actions = table.Add(tip_actions, grab_stand_actions)
				end
			end

			local target = ply:TraceForTarget()

			if target and IsValid(target) then
				if target:GetNWBool("is_knocked_out", false) and ply:Crouching() then
					local crouched_actions = {
							{
								icon = Helpup,
								key = {	input.LookupBinding("+use") or "E" }
							}
					}
	
					if ply:GetNWInt("scanner", 0) > 3 then
						local scan_ex = {
							{
								icon = Scan_ex,
								key = { Cqc_button }
							}
						}
	
						tip_actions = table.Add(tip_actions, scan_ex)
					end
	
					tip_actions = table.Add(tip_actions, crouched_actions)
				end
			end

			surface.SetFont("Trebuchet24")

			local startY = ScrH() * 0.70
			local spacing = 160
			local icon_size = 128

			-- Calculate total width of all icons
			local totalWidth = (#tip_actions * spacing)

			-- Starting X so whole group is centered
			local startX = (ScrW() / 2) - (totalWidth / 2)

			for i, action in ipairs(tip_actions) do
				local x = startX + (i - 1) * spacing

				-- Draw icon
				surface.SetMaterial(action.icon)

				surface.SetDrawColor(235, 153, 59, 255)

				if action.icon == Grab_knife then
					surface.SetDrawColor(205, 25, 25, 255)
				end

				surface.DrawTexturedRect(x, startY + 10, icon_size, icon_size)

				-- Draw key combo ABOVE, centered relative to the icon
				if action.key then
					local combo = istable(action.key) and action.key or { action.key }

					-- measure combo width
					local comboW = 0
					for _, item in ipairs(combo) do
						if type(item) == "IMaterial" then
							comboW = comboW + 44 + 6
						else
							local w = surface.GetTextSize(item)
							comboW = comboW + w + 6
						end

						-- plus sign width if not last
						if _ < #combo then
							comboW = comboW + surface.GetTextSize("+") + 6
						end
					end

					local comboX = x + (icon_size / 2) - (comboW / 2)
					DrawKeyCombo(comboX, startY - 20, combo)
				end
			end

		end
	end)

	hook.Add("HUDDrawTargetID", "MGS4PsycheTarget", function ()
		local target = LocalPlayer():GetEyeTrace().Entity
		if IsValid(target) and target:IsPlayer() then
			local psyche = target:GetNWFloat("psyche", 0)
			if GAMEMODE_NAME == "terrortown" then
				local status_text = ""
				local status_color = Color(255, 205, 0, 255)

				if target:GetNWBool("is_knocked_out", false) then
					status_text = "Unconscious"
					status_color = Color(255, 0, 230, 255)
				else
					if psyche > 80 then
						status_text = "Alert"
						status_color = Color(4, 255, 0, 255)
					elseif psyche > 60 then
						status_text = "Strained"
						status_color = Color(0, 255, 180, 255)
					elseif psyche > 40 then
						status_text = "Tired"
						status_color = Color(0, 123, 255, 255)
					elseif psyche > 20 then
						status_text = "Fatigued"
						status_color = Color(0, 0, 255, 255)
					else
						status_text = "Exhausted"
						status_color = Color(170, 0, 255, 255)
					end
				end

				local x, y = ScrW() / 2, ScrH() / 2 + 91 -- default position

				local localRole = LocalPlayer():GetRole()
				local targetRole = target:GetRole()

				if (targetRole == ROLE_DETECTIVE or targetRole == ROLE_TRAITOR) then
					if targetRole == ROLE_DETECTIVE or (localRole == ROLE_TRAITOR and targetRole == ROLE_TRAITOR) then
						y = ScrH() / 2 + 111 -- adjusted position, after health and karma
					end
				end

				draw.SimpleText(
					status_text,
					"TargetIDSmall",
					x,
					y,
					status_color,
					TEXT_ALIGN_CENTER
				)
			else
				draw.SimpleText(tostring(math.Round(psyche, 0)) .. "%", "TargetIDSmall", ScrW() / 2, ScrH() / 2 + 70, Color(255,205,0,255), TEXT_ALIGN_CENTER)
			end
		end
	end)

	-- === Freeze mouse when helping up ===
	hook.Add( "InputMouseApply", "FreezeTurning", function( cmd, x, y, ang )
		local ply = LocalPlayer()

		-- Store mouse movement for camera movement when frozen
		if ply:GetNWBool("animation_playing", false) or ply:GetNWBool("is_grabbed", false) or ply:GetNWBool("helping_up", false) or ply:GetNWBool("is_t_choking", false) or ply:GetNWBool("is_choking", false) then
			local prev = ply:GetNWAngle("mouse_angle", ply:EyeAngles())
			local ang = prev + Angle(y * 0.022, -x * 0.022, 0)
			local thirdperson = GetConVar("mgs4_actions_in_thirdperson"):GetBool()
			local eyeAngles = ply:EyeAngles()

			-- Use head attachment angle if available so clamps are relative to head direction
			local eyeAttachIdx = ply:LookupAttachment("eyes")
			local eyeAttach = eyeAttachIdx and ply:GetAttachment(eyeAttachIdx)
			local baseAng = (eyeAttach and not thirdperson) and Angle(0, eyeAttach.Ang.y, 0) or Angle(0, eyeAngles.y, 0)

			-- Clamp pitch relative to head pitch to avoid looking too far up/down
			local minPitchDiff, maxPitchDiff = -90, 90
			local pitchDiff = math.NormalizeAngle(ang.p - baseAng.p)
			if pitchDiff < minPitchDiff then pitchDiff = minPitchDiff end
			if pitchDiff > maxPitchDiff then pitchDiff = maxPitchDiff end
			ang.p = baseAng.p + pitchDiff

			if not thirdperson then
				-- Clamp yaw relative to head yaw so player can't look behind (limit to +/- 90° from head forward)
				local diff = math.NormalizeAngle(ang.y - baseAng.y)
				local maxYawDiff = 90
				if diff > maxYawDiff then diff = maxYawDiff end
				if diff < -maxYawDiff then diff = -maxYawDiff end
				ang.y = baseAng.y + diff
			end

			ply:SetNWAngle("mouse_angle", ang)
			cmd:SetMouseX( 0 )
			cmd:SetMouseY( 0 )

			return true
		else
			ply:SetNWAngle("mouse_angle", ply:EyeAngles())
		end

	end )

	hook.Add( "PostDrawTranslucentRenderables", "MGS4DrawKnockedoutStars", function()
		for _, entity in ipairs( ents.GetAll() ) do
			local is_knocked_out = entity:GetNWBool("is_knocked_out", false)
			local last_dmg_type = entity:GetNWInt("last_nonlethal_damage_type", 0)

			local attach = entity:GetAttachment( entity:LookupAttachment( "eyes" ) )

			if (entity:IsNPC() or entity:IsNextBot()) and entity:GetNWEntity("npc_proxy", NULL) ~= NULL then
				local npc_proxy = entity:GetNWEntity("npc_proxy", NULL)

				attach = npc_proxy:GetAttachment( npc_proxy:LookupAttachment( "eyes" ) )
			end

			local psyche = entity:GetNWFloat("psyche", 0)

			if ( is_knocked_out and last_dmg_type ~= 1 and entity:Alive() ) then
				if ( attach ) then
					local stars = math.Clamp( math.ceil( ( 100 - psyche ) / 20 ), 1, 5 )

					for i = 1, stars do
						local time = CurTime() * 3 + ( math.pi * 2 / stars * i )
						local offset = Vector( math.sin( time ) * 5, math.cos( time ) * 5, 10 )

						render.SetMaterial( Star )
						render.DrawSprite( attach.Pos + offset, 5, 5, Color( 255, 215, 94 ) )
					end
				end
			elseif ( is_knocked_out and last_dmg_type == 1 and entity:Alive() ) then
				if ( attach ) then
					local zzz = math.Clamp( math.ceil( ( 100 - psyche ) / 33 ), 1, 3 )

					for i = 1, zzz do
						local time = CurTime() * 2 + ( math.pi * 4 / zzz * i * 4 )
						local vertical_offset = (time % 6 * 4) + 10
						local horizontal_offset = math.sin(time + i) * 4 
						local offset = Vector(horizontal_offset, 0, vertical_offset)

						local t = (vertical_offset - 10) / (6 * 4)
						local size = (1 - math.abs(t - 0.5) * 2) * 6

						render.SetMaterial(Sleep)
						render.DrawSprite(attach.Pos + offset, size, size, Color(255, 215, 94, 220))
					end
				end
			end
		end
	end )

	-- == SOP Scan effects on the client ==
	local scanned_entities = {}
	local duration

	net.Receive("Scanner", function()
		local count = net.ReadUInt(8)
		local entsToAdd = {}
		for i = 1, count do
			table.insert(entsToAdd, net.ReadEntity())
		end
		local start_time = net.ReadFloat()
		duration = net.ReadFloat()

		for _, entity in ipairs(entsToAdd) do
			if IsValid(entity) then
				scanned_entities[entity] = start_time + duration
			end
		end
	end)

	hook.Add("PreDrawHalos", "ScanHalos", function()
		local ct = CurTime()
		local halos = {}

		for entity, expireTime in pairs(scanned_entities) do
			if not IsValid(entity) or ct > expireTime or not entity:Alive() then
				scanned_entities[entity] = nil
			else
				local npc_proxy = entity:GetNWEntity("npc_proxy", NULL)
				if npc_proxy ~= NULL then
					table.insert(halos, npc_proxy)
				else
					table.insert(halos, entity)
				end
			end
		end

		if #halos > 0 then
        local t = math.fmod(ct * 0.5, 1)
        local pulse = (1 - t)^2

        halo.Add(halos, Color(255 * pulse, 0, 0), 2, 2, 1, true, true)
		end
	end)
end


-- Initialization. Set the ammo types and stuff.
hook.Add("Initialize", "MGS4Init", function ()
	game.AddAmmoType( {
		name = Ammo_types["mk2"],
		dmgtype = DMG_POISON, 
		tracer = TRACER_NONE,
		plydmg = 0,
		npcdmg = 0,
		force = 0,
		maxcarry = 60,
		minsplash = 10,
		maxsplash = 5
	} )
end)

-- === Handling buttons while grabbing ===
hook.Add("StartCommand", "MGS4StartCommand", function(ply, cmd)
	if ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("is_aiming", false) and not ply:GetNWBool("is_knife", false) then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_RELOAD)
	elseif ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and ply:GetNWBool("is_aiming", false) then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_FORWARD)
		cmd:RemoveKey(IN_BACK)
		cmd:RemoveKey(IN_MOVELEFT)
		cmd:RemoveKey(IN_MOVERIGHT)
		cmd:RemoveKey(IN_DUCK)
	elseif ply:GetNWBool("is_grabbed", false) or ply:GetNWBool("helping_up", false) then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		cmd:RemoveKey(IN_RELOAD)
	end
end)

-- === Overriding anims like reload ===
hook.Add("DoAnimationEvent", "MGS4AnimsOverride", function (ply, event, data)
	if IsValid(ply) == false or not ply:IsPlayer() then return end

	if ply:Team() == TEAM_SPECTATOR then return end

	if event == PLAYERANIMEVENT_RELOAD and ply:GetNWBool("is_aiming") and not ply:GetNWBool("animation_playing") then
		local reload_anim

		if ply:GetNWBool("is_grabbed_crouched", false) then
			reload_anim = "mgs4_grab_crouched_reload"
		else
			reload_anim = "mgs4_grab_reload"
		end

		local seq = ply:LookupSequence(reload_anim)

		ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true)

		return ACT_INVALID
	end
end)

hook.Add("PlayerPostThink", "MGS4StopGesturesOnAnims", function (ply)
	if ply:GetNWBool("animation_playing") then
		ply:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)
	end
end)

-- === Animation Handling for players ===
hook.Add("CalcMainActivity", "MGS4Anims", function(ply, vel)
	if IsValid(ply) == false or not ply:IsPlayer() then return end

	if ply:Team() == TEAM_SPECTATOR then return end

	if ply:GetNWBool("is_knocked_out", false) then
		-- == Knockout loop ==
		local knockout_type = ply:GetNWInt("last_nonlethal_damage_type", 0)

		local knockout_anim

		if knockout_type == 0 then
			knockout_anim = ply:LookupSequence("mgs4_knocked_out_loop_faceup")
		else
			knockout_anim = ply:LookupSequence("mgs4_knocked_out_loop_facedown")
		end

		ply:SetCycle(CurTime() % 1)

		return -1, knockout_anim
	elseif ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("animation_playing", false) then
		-- == CQC grab loop ==
		local target = ply:GetNWEntity("cqc_grabbing", NULL)
		
		if not IsValid(target) then return end
		
		local grabbing_anim

		local grabbing_loop = ply:LookupSequence("mgs4_grab_loop")
		local grabbing_aim = ply:LookupSequence("mgs4_grab_aim")
		local grabbing_chocking = ply:LookupSequence("mgs4_grab_chocking")

		local grabbing_t_chocking = ply:LookupSequence("mgs4_grab_crouched_tchoke_loop")

		local grabbing_crouched_loop = ply:LookupSequence("mgs4_grab_crouched_loop")
		local grabbing_crouched_aim = ply:LookupSequence("mgs4_grab_crouched_aim")
		local grabbing_crouched_chocking = ply:LookupSequence("mgs4_grab_crouched_chocking")

		if target:GetNWBool("is_t_choking", false) then
			grabbing_anim = grabbing_t_chocking
		elseif ply:GetNWBool("is_choking", false) then
			if ply:GetNWBool("is_grabbed_crouched", false) then
				grabbing_anim = grabbing_crouched_chocking
			else
				grabbing_anim = grabbing_chocking
			end
		elseif ply:GetNWBool("is_aiming", false) then
			if ply:GetNWBool("is_grabbed_crouched", false) then
				grabbing_anim = grabbing_crouched_aim
			else
				grabbing_anim = grabbing_aim
			end
		else
			if ply:GetNWBool("is_grabbed_crouched", false) then
				grabbing_anim = grabbing_crouched_loop
			else
				grabbing_anim = grabbing_loop
			end
		end

		ply:SetCycle(CurTime() % 1)

		return -1, grabbing_anim
	elseif ply:GetNWBool("is_grabbed", false) and not ply:GetNWBool("animation_playing", false) then
		-- == CQC grabbed loop ==
		local grabbed_anim

		local grabbed_loop = ply:LookupSequence("mgs4_grabbed_loop")
		local grabbed_chocking = ply:LookupSequence("mgs4_grabbed_chocking")

		local grabbed_t_chocking = ply:LookupSequence("mgs4_grabbed_crouched_tchoke_loop")

		local grabbed_crouched_loop = ply:LookupSequence("mgs4_grabbed_crouched_loop")
		local grabbed_crouched_chocking = ply:LookupSequence("mgs4_grabbed_crouched_chocking")

		if ply:GetNWBool("is_t_choking", false) then
			grabbed_anim = grabbed_t_chocking
		elseif ply:GetNWBool("is_choking", false) then
			if ply:GetNWBool("is_grabbed_crouched", false) then
				grabbed_anim = grabbed_crouched_chocking
			else
				grabbed_anim = grabbed_chocking
			end
		else
			if ply:GetNWBool("is_grabbed_crouched", false) then
				grabbed_anim = grabbed_crouched_loop
			else
				grabbed_anim = grabbed_loop
			end
		end

		ply:SetCycle(CurTime() % 1)

		return -1, grabbed_anim
	elseif ply:GetNWBool("helping_up", false) and not ply:GetNWBool("animation_playing", false) then
		-- == Playing an animation ==
		local helping_loop = ply:LookupSequence("mgs4_wakeup_loop")

		if ply:GetNWBool("cqc_button_held", false) then
			helping_loop = ply:LookupSequence("mgs4_wakeup_scanex_loop")
		end

		ply:SetCycle(CurTime() % 1)

		return -1, helping_loop
	else
		-- == All other animations ==
		local str = ply:GetNWString('SVAnim')
		local num = ply:GetNWFloat('SVAnimDelay')
		local speed = ply:GetNWFloat('SVAnimSpeed')
		local st = ply:GetNWFloat('SVAnimStartTime')
		if str ~= "" then
			ply:SetCycle(((CurTime()-st)/num) * speed)
			local current_anim = ply:LookupSequence(str)
			return -1, current_anim
		end
	end
end)

