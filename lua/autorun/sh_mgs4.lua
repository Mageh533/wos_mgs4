---@diagnostic disable: undefined-field
local ent = FindMetaTable("Entity")

function ent:PlayMGS4Animation(anim, callback, updatepos)
	if not self then return end

	local current_anim = self:LookupSequence(anim)
	local duration = self:SequenceDuration(current_anim)

	self:SetNWBool("animation_playing", true)
	self:SetNWFloat("cqc_button_hold_time", 0)

	local current_pos = self:GetPos()

	-- Shouldn't be able to start an anim without being in a safe position
	self:SetNWVector("safe_pos", current_pos)

	local pos_to_set

	self:SetVelocity(-self:GetVelocity())

	timer.Simple(duration, function()
		if self:Alive() == false then return end

		local pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
		pos_to_set = pelvis_matrix:GetTranslation()

		if updatepos then
			self:SetPos(Vector(pos_to_set.x, pos_to_set.y, current_pos.z))
		end

		self:SetNWBool("animation_playing", false)

		if callback and type(callback) == "function" then
		    callback(self)
		end

	end)

	self:SetNWString('SVAnim', anim)
	self:SetNWFloat('SVAnimDelay', select(2, self:LookupSequence(anim)))
	self:SetNWFloat('SVAnimStartTime', CurTime())
	self:EmitMGS4Sound(anim)
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

-- === Helper to find out the angle of the target ===
function ent:AngleAroundTarget(target)
	if not self or not IsValid(target) then return 0 end

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

	return angleAround
end

if SERVER then
	-- === Helper for forcing a position and angle ===
	function ent:ForcePosition(force, pos, ang)
		if not self then return end

		if force then
			self:SetNWBool("force_position", true)

			self:SetNWVector("forced_position", pos and pos or self:GetPos())

			self:SetNWAngle("forced_angle", ang and ang or Angle(0, self:EyeAngles().y, 0))
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

		self:Cqc_reset()

		local knockout_type = self:GetNWInt("last_nonlethal_damage_type", 0)
		local crouched = self:Crouching()

		local knockout_anim

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

		if knockout_anim then
			self:ForcePosition(true, self:GetPos(), self:EyeAngles())
			self:PlayMGS4Animation(knockout_anim, function()
				self:SetNWBool("is_knocked_out", true)
				self:ForcePosition(true, self:GetPos(), self:EyeAngles())
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

		self:ForcePosition(true, self:GetPos(), self:EyeAngles())
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

		-- Make them drop their weapon in an item box
		local active_weapon = self:GetActiveWeapon()
		if IsValid(active_weapon) then
			local weapon_class = active_weapon:GetClass()
			self:StripWeapon(weapon_class)
			self:SetActiveWeapon(NULL)
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
			self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36)) -- Set crouch hull back to normal
			self:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Set stand hull back to normal
			self:SetViewOffset(Vector(0, 0, 64)) -- Set stand view offset back to normal
		
			if self:GetNWEntity("knife", NULL) ~= NULL then
				self:GetNWEntity("knife", NULL):Remove()
				self:SetNWEntity("knife", NULL)
			end

			self:ForcePosition(false)
		end, false)

		self:ForcePosition(true, target:GetPos(), self:EyeAngles())
		target:SetNWBool("is_in_cqc", true)
		target:PlayMGS4Animation(knifed_anim, function()
			target:SetNWBool("is_in_cqc", false)

			-- Just kill them lmao
			target:TakeDamage(1000, self, self)

			target:ForcePosition(false)
		end, false)
	end

	function ent:Cqc_sop_scan(target)
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

		self:ForcePosition(true)
		self:PlayMGS4Animation(scan_anim, function()
			-- Give back the weapon
			if IsValid(current_weapon) then
				self:SetActiveWeapon(current_weapon)
			end
			scanner_ent:Remove()
			self:SetNWFloat("stuck_check", 0)
			self:ForcePosition(false)
		end, false)

		target:ForcePosition(true, target:GetPos(), self:EyeAngles())
		target:PlayMGS4Animation(scanned_anim, function()
			target:SetNWFloat("stuck_check", 0)
			target:ForcePosition(false)
		end, false)
	end

	function ent:Cqc_throw(target, direction)
		if not self or not IsValid(target) then return end

		if direction == 1 then
			-- Throw forward
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self:EyeAngles())
			self:PlayMGS4Animation("mgs4_grab_throw_forward", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true)

			target:SetNWInt("last_nonlethal_damage_type", 3)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self:EyeAngles())
			target:PlayMGS4Animation("mgs4_grabbed_throw_forward", function()
				target:Cqc_reset()

				-- CQC level stun damage
				local cqc_level = self:GetNWInt("cqc_level", 4)
				local stun_damage = 10 * cqc_level

				local target_psyche = target:GetNWFloat("psyche", 100)

				target:SetNWFloat("psyche", target_psyche - stun_damage)

				if target:GetNWFloat("psyche", 100) > 0 then
					target:StandUp()
				end

				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())

				target:ForcePosition(false)

			end, true)
		elseif direction == 2 then
			-- Throw backward
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self:EyeAngles())
			self:PlayMGS4Animation("mgs4_grab_throw_backward", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self:EyeAngles())
			target:PlayMGS4Animation("mgs4_grabbed_throw_backward", function()
				target:Cqc_reset()

				-- CQC level stun damage
				local cqc_level = self:GetNWInt("cqc_level", 4)
				local stun_damage = 10 * cqc_level

				local target_psyche = target:GetNWFloat("psyche", 100)

				target:SetNWFloat("psyche", target_psyche - stun_damage)

				if target:GetNWFloat("psyche", 100) > 0 then
					target:StandUp()
				end

				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())

				target:ForcePosition(false)

			end, true)
		elseif direction == 3 then
			-- Front with weapon
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self:EyeAngles())
			self:PlayMGS4Animation("mgs4_cqc_throw_gun_front", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self:EyeAngles() + Angle(0, 180, 0))
			target:PlayMGS4Animation("mgs4_cqc_throw_gun_front_victim", function()
				target:Cqc_reset()
				target:SetNWFloat("psyche", 0)
				target:ForcePosition(false)
				target:SetEyeAngles(target:EyeAngles() + Angle(0, 270, 0))
				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
			end, true)
		elseif direction == 4 then
			-- Back with weapon
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self:EyeAngles())
			self:PlayMGS4Animation("mgs4_cqc_throw_gun_back", function()
				self:Cqc_reset()
				self:ForcePosition(false)
			end, true)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos(), self:EyeAngles())
			target:PlayMGS4Animation("mgs4_cqc_throw_gun_back_victim", function()
				target:Cqc_reset()
				target:SetNWFloat("psyche", 0)
				target:ForcePosition(false)
				target:SetEyeAngles(target:EyeAngles() + Angle(0, 270, 0))
				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
			end, true)
		else
			-- Normal throw
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self:EyeAngles())
			self:PlayMGS4Animation("mgs4_cqc_throw", function()
				self:Cqc_reset()
				self:SetEyeAngles(self:EyeAngles() + Angle(0, 90, 0))
				self:ForcePosition(false)
			end, true)

			target:SetNWInt("last_nonlethal_damage_type", 0)
			target:SetNWBool("is_in_cqc", true)
			target:ForcePosition(true, self:GetPos() + (self:GetAngles():Forward() * 30), self:EyeAngles() + Angle(0, 180, 0))
			target:PlayMGS4Animation("mgs4_cqc_throw_victim", function()
				target:Cqc_reset()

				-- CQC level stun damage
				local cqc_level = self:GetNWInt("cqc_level", 4)
				local stun_damage = 25 * cqc_level if cqc_level < 1 then stun_damage = 25 end

				local target_psyche = target:GetNWFloat("psyche", 100)

				target:SetNWFloat("psyche", target_psyche - stun_damage)

				target:SetEyeAngles(target:EyeAngles() + Angle(0, 180, 0))

				if target:GetNWFloat("psyche", 100) > 0 then
					target:StandUp()
				end

				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
				target:ForcePosition(false)
			end, true)
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

		if angleAround > 135 and angleAround <= 225 then
			-- Countering from the back
			counter_anim = "mgs4_cqc_counter_back"
			self:ForcePosition(true, target:GetPos(), target:EyeAngles())
		else
			-- Countering from the front
			counter_anim = "mgs4_cqc_counter_front"
			self:ForcePosition(true, target:GetPos(), target:EyeAngles() + Angle(0, 180, 0))
		end

		target:ForcePosition(true, target:GetPos(), target:EyeAngles())
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

		self:ForcePosition(true, self:GetPos(), self:EyeAngles())
		self:PlayMGS4Animation(grab_anim, function ()
			self:SetNWEntity("cqc_grabbing", target)
			self:ForcePosition(false)
			self:SetNWFloat("stuck_check", 0)
		end, true)
		target:ForcePosition(true, self:GetPos(), self:EyeAngles() + angle_offset)
		target:PlayMGS4Animation(grabbed_anim, function ()
			target:SetNWBool("is_grabbed", true)
			target:ForcePosition(false)
			target:SetNWFloat("stuck_check", 0)
		end, true)
		
		-- Make them drop their weapon in an item box
		if self:GetNWInt("cqc_level", 0) >= 3 then
			timer.Simple(1.7, function ()
				target:DropWeaponAsItem()
			end)
		end

		if self:Crouching() then
			target:SetNWBool("is_grabbed_crouched", true)
		else
			target:SetNWBool("is_grabbed_crouched", false)
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
			self:PlayMGS4Animation("mgs4_grab_crouch", nil, true)

			target:PlayMGS4Animation("mgs4_grabbed_crouch", function ()
				target:SetNWBool("is_grabbed_crouched", true)
			end, true)
		else
			self:PlayMGS4Animation("mgs4_grab_crouched_stand", nil, true)

			target:PlayMGS4Animation("mgs4_grabbed_crouched_stand", function ()
				target:SetNWBool("is_grabbed_crouched", false)
			end, true)
		end
	end

	function ent:Cqc_grab_move(target)
		if not self or not IsValid(target) then return end

		self:PlayMGS4Animation("mgs4_grab_move", nil, true)

		target:PlayMGS4Animation("mgs4_grabbed_move", nil, true)
	end

	function ent:Cqc_grab_letgo(type, crouched)
		if not self then return end

		local letgo_anim
		-- 0 is when letting go and 1 is when being let go
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
		end

		self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
		self:Cqc_reset()
		self:ForcePosition(true, self:GetPos(), self:EyeAngles())
		self:PlayMGS4Animation(letgo_anim, function ()
			self:ForcePosition(false)
			self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36)) -- Set crouch hull back to normal
			self:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Set stand hull back to normal
			self:SetViewOffset(Vector(0, 0, 64)) -- Set stand view offset back to normal
			self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())

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
		if not target:Alive() or not self:Alive() or target:GetNWFloat("psyche", 100) <= 0 or self:GetNWFloat("psyche", 100) <= 0 or self:KeyPressed(IN_JUMP) or target:GetNWFloat("grab_escape_progress", 0) <= 0 and not self:GetNWBool("animation_playing", false) and not target:GetNWBool("animation_playing", false) then
			-- Letgo animation on the player
			if self:Alive() and self:GetNWFloat("psyche", 100) > 0 then
				self:Cqc_grab_letgo(0, target:GetNWBool("is_grabbed_crouched", false))
			end

			-- Letgo animation on the target
			if target:Alive() and target:GetNWFloat("psyche", 100) > 0 then
				target:Cqc_grab_letgo(1, target:GetNWBool("is_grabbed_crouched", false))
			end

			return
		end

		local player_pos = self:GetPos()
		local player_angle = self:GetAngles()

		target:SetPos(player_pos + (player_angle:Forward() * 5)) -- Move the target slightly forward
		target:SetEyeAngles(player_angle)

		-- Target slowly is able to escape depending on cqc level
		target:SetNWFloat("grab_escape_progress", math.max(target:GetNWFloat("grab_escape_progress", 100) - ((1 / self:GetNWInt("cqc_level", 1)) * FrameTime() * 25), 0))

		self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 72)) -- Crouch hull to standing height to teleporting up when ducking in animations

		if target:GetNWBool("is_grabbed_crouched", false) then
			self:SetViewOffset(Vector(0, 0, 36)) -- Set crouch view offset
		else
			self:SetViewOffset(Vector(0, 0, 64)) -- Set stand view offset
		end

		if not self:GetNWBool("is_aiming", false) then
			-- Normal mode, hold cqc button to choke, hold+forward or backward to throw, click to throat cut, e to scan.
			if self:GetNWBool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) and not self:GetNWBool("animation_playing") then
				-- Holding the CQC button starts choking
				target:SetNWFloat("psyche", math.max(target:GetNWFloat("psyche", 100) - ((20 * FrameTime()) * self:GetNWInt("cqc_level", 1)), 0))
				target:SetNWInt("last_nonlethal_damage_type", 2)
				target:SetNWBool("is_choking", true)
			elseif self:GetNWBool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) and not target:GetNWBool("is_grabbed_crouched", false) and not self:GetNWBool("animation_playing") then
				-- Holding and moving forward throws the target in front
				self:Cqc_throw(target, 1)
			elseif self:GetNWBool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and not self:KeyPressed(IN_FORWARD) and self:KeyPressed(IN_BACK) and not target:GetNWBool("is_grabbed_crouched", false) and not self:GetNWBool("animation_playing") then
				-- Holding and moving backward throws the target behind
				self:Cqc_throw(target, 2)
			elseif self:GetNWBool("cqc_button_held", false) and self:KeyPressed(IN_USE) and self:GetNWInt("blades", 0) == 3 and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) and not self:GetNWBool("animation_playing") then
				-- press e while holding does the throat cut
				self:Cqc_throat_cut(target)
			elseif not self:GetNWBool("cqc_button_held", false) and self:KeyPressed(IN_USE) and self:GetNWInt("scanner", 0) > 0 and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) and not self:GetNWBool("animation_playing") then
				-- press e while not holding does the scan
				self:Cqc_sop_scan(target)
			elseif self:KeyPressed(IN_BACK) and not target:GetNWBool("is_grabbed_crouched", false) and not self:GetNWBool("animation_playing") then
				-- Pressing back button moves backwards
				self:Cqc_grab_move(target)
			elseif self:KeyPressed(IN_DUCK) then
				-- Pressing crouch makes both the player and target crouch while grabbing
				self:Cqc_grab_crouch(target)
			else
				target:SetNWBool("is_choking", false)
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

		if self:GetNWBool("helping_up", false) and target:GetNWBool("is_knocked_out", false) then
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

		if key == IN_ATTACK2 and ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL then
			ply:SetNWBool("is_aiming", not ply:GetNWBool("is_aiming", false))
		end

		if key == IN_ATTACK and ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("is_aiming", false) then
			ply:SetNWBool("is_knife", true)
		end

		if key == IN_USE then
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
			entity:StandUp()
		else
			entity:SetNWBool("animation_playing", true)
			entity:SetVelocity(-entity:GetVelocity())

			local psyche = entity:GetNWFloat("psyche", 100)
			if psyche < 100 then
				psyche = psyche + GetConVar("mgs4_psyche_recovery"):GetFloat() * FrameTime()
				entity:SetNWFloat("psyche", math.min(psyche, 100)) -- Cap at 100
			end

			if entity:KeyPressed(IN_USE) then
				psyche = psyche + GetConVar("mgs4_psyche_recovery_action"):GetFloat()
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

	-- === Initialization ===
	hook.Add("PlayerSpawn", "MGS4EntitySpawn", function(ent)
		--- Only affects players
		ent:SetNWBool("animation_playing", false)

		ent:SetNWBool("will_grab", false)
		ent:SetNWEntity("cqc_grabbing", NULL)

		ent:SetNWBool("is_in_cqc", false)
		ent:SetNWBool("is_grabbed", false)
		ent:SetNWBool("is_grabbed_crouched", false)
		ent:SetNWBool("is_choking", false)
		ent:SetNWBool("is_aiming", false)
		ent:SetNWBool("is_knife", false)
		ent:SetNWBool("is_using", false)

		--- Progress remaining to escape a grab.
		ent:SetNWFloat("grab_escape_progress", 100)

		--- Variables to force a position on the player at certain times
		ent:SetNWBool("force_position", false)
		ent:SetNWVector("forced_position", Vector(0, 0, 0))
		ent:SetNWAngle("forced_angle", Angle(0, 0, 0))

		--- == Skills ==

		-- Each CQC Level grants you:
		-- -2 = Nothing
		-- -1 = Punch punch kick combo
		--  0 = CQC throw
		--  1 = (CQC+1) Grabs
		--  2 = (CQC+2) Higher stun damage
		--  3 = (CQC+3) Higher stun damage and take weapons from enemies
		--  4 = (CQCEX) Counter CQC and maximum stun damage
		ent:SetNWInt("cqc_level", GetConVar("mgs4_base_cqc_level"):GetInt())

		-- Other skills
		ent:SetNWInt("blades", 0)
		ent:SetNWInt("scanner", 0)

		-- In some animations we hide the gun, so we need to store it here
		ent:SetNWEntity("holster_weapon", NULL)

		ent:SetNWEntity("knife", NULL)

		-- How long the player is holding the CQC button for (for knowing if they want to grab or punch)
		ent:SetNWBool("cqc_button_held", false)
		ent:SetNWFloat("cqc_button_hold_time", 0)

		-- Time of the punch punch kick combo. Keep pressing to complete the combo, press it once to just punch once.
		ent:SetNWFloat("cqc_punch_time_left", 0)

		ent:SetNWInt("cqc_punch_combo", 0) -- 1 = First punch, 2 = Second punch, 3 = Kick
		ent:SetNWBool("helping_up", false)

		--- Immunity to CQC for a few seconds to make it fairer
		ent:SetNWFloat("cqc_immunity_remaining", 0)

		--- Psyche
		--- If it reaches 0, the entity will be knocked out
		--- Only regenerates when knocked out or if reading a magazine
		ent:SetNWFloat("psyche", 100)

		ent:SetNWBool("is_knocked_out", false)

		---- Last Non-Lethal Damage Type
		--- 0 = Stun (Face up)
		--- 1 = Tranquilizers
		--- 2 = Generic Stun
		--- 3 = Stun (Face down)
		ent:SetNWInt("last_nonlethal_damage_type", 0)
	end)

	-- Cleanup on player death
	hook.Add("PostPlayerDeath", "MGS4PlayerDeathCleanup", function(ply)
		ply:SetNWBool("animation_playing", false)
		ply:SetNWBool("will_grab", false)
		ply:SetNWEntity("cqc_grabbing", NULL)
		ply:SetNWBool("is_in_cqc", false)
		ply:SetNWBool("is_grabbed", false)
		ply:SetNWBool("is_grabbed_crouched", false)
		ply:SetNWBool("is_choking", false)
		ply:SetNWBool("is_aiming", false)
		ply:SetNWBool("is_knife", false)
		ply:SetNWBool("is_using", false)
		ply:SetNWFloat("grab_escape_progress", 100)
		ply:SetNWBool("force_position", false)
		ply:SetNWVector("forced_position", Vector(0, 0, 0))
		ply:SetNWAngle("forced_angle", Angle(0, 0, 0))
		ply:SetNWInt("cqc_level", GetConVar("mgs4_base_cqc_level"):GetInt())
		ply:SetNWInt("blades", 0)
		ply:SetNWInt("scanner", 0)
		ply:SetNWEntity("holster_weapon", NULL)

		if ply:GetNWEntity("knife", NULL) ~= NULL then
			ply:GetNWEntity("knife", NULL):Remove()
		end

		ply:SetNWEntity("knife", NULL)
		ply:SetNWBool("cqc_button_held", false)
		ply:SetNWFloat("cqc_button_hold_time", 0)
		ply:SetNWFloat("cqc_punch_time_left", 0)
		ply:SetNWInt("cqc_punch_combo", 0)
		ply:SetNWBool("helping_up", false)
		ply:SetNWFloat("cqc_immunity_remaining", 0)
		ply:SetNWFloat("psyche", 100)
		ply:SetNWBool("is_knocked_out", false)
		ply:SetNWInt("last_nonlethal_damage_type", 0)
	end)

	hook.Add("DoPlayerDeath", "MGS4PlayerPreDeathCleanup", function(ply, attacker, dmg)
		if ply:GetNWBool("cqc_grabbing", NULL) ~= NULL then
			local target = ply:GetNWBool("cqc_grabbing", NULL)
			target:Cqc_grab_letgo(1, target:GetNWBool("is_grabbed_crouched", false))
		end
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
				local playerAngle = ent:EyeAngles().y
				local relativeAngle = math.NormalizeAngle(angleAround - playerAngle)

				if psyche_dmg >= 10 and psyche_dmg < 50 then
					if ent:Crouching() then
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

	-- === Handles systems every tick like grabbing and psyche ===
	hook.Add("Tick", "MGS4Tick", function()
		local players = ents.FindByClass("player") -- Find all players

		for _, entity in ipairs(players) do
			if entity:LookupBone("ValveBiped.Bip01_Pelvis") == nil then return end

			if entity:GetNWFloat("psyche", 100) <= 0 and not entity:GetNWBool("is_knocked_out", false) and not entity:GetNWBool("animation_playing", false) then
				entity:SetNWFloat("psyche", 0)
				entity:Knockout() -- Knock out the player silently
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

			-- Press it once for Punch
			if entity:GetNWBool("cqc_button_held", false) == false and entity:GetNWFloat("cqc_button_hold_time", 0) > 0 and entity:GetNWFloat("cqc_button_hold_time", 0) <= 0.5 and not entity:GetNWBool("animation_playing", false) then
				entity:SetNWFloat("cqc_button_hold_time", 0)
				entity:Cqc_punch()
			end

			-- Hold the button for CQC Throw and Grab
			if entity:GetNWFloat("cqc_button_hold_time", 0) > 0.2 and entity:GetNWEntity("cqc_grabbing") == NULL and not entity:GetNWBool("animation_playing", false) then
				entity:SetNWBool("cqc_button_held", false)
				entity:SetNWFloat("cqc_button_hold_time", 0)
				entity:Cqc_check()
			end

			-- Hold the use button while crouched next to a knocked out entity to help them wake up
			if entity:GetNWBool("is_using", false) then
				entity:GetYourselfUp()
			elseif not entity:GetNWBool("is_using", false) and entity:GetNWBool("helping_up", false) and not entity:GetNWBool("animation_playing", false) then
				entity:PlayMGS4Animation("mgs4_wakeup_end", function()
					entity:SetNWBool("helping_up", false)
					if entity:GetNWEntity("holster_weapon", NULL) ~= NULL then
						entity:SetActiveWeapon(entity:GetNWEntity("holster_weapon", NULL))
						entity:SetNWEntity("holster_weapon", NULL)
					end
				end, false)
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

			if entity:GetNWBool("animation_playing", true) then
				entity:Freeze(true)
				entity:SetNWFloat("stuck_check", 1.0)
				if entity:GetAngles().y ~= entity:EyeAngles().y then
					-- If they are a player we need to ensure the body is rotated to the eyeangles (only viable way i found is adding some dummy velocity)
					local dir = entity:EyeAngles():Forward()
					entity:SetVelocity(dir * 10)
				end 
			else
				entity:Freeze(false)
			end

			if entity:GetNWFloat("stuck_check") > 0 then
				entity:MGS4StuckCheck()
				entity:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

				entity:SetNWFloat("stuck_check", entity:GetNWFloat("stuck_check", 0) - FrameTime())
			elseif not entity:GetNWBool("is_knocked_out", true) then
				entity:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			end
		end
	end)

	-- Trouble in terrorist town specific hooks
	hook.Add("TTTOrderedEquipment", "MGS4TTTOrderedEquipment", function(ply, equipment, is_item)
		if equipment == EQUIP_MGS4_BLADES_3 then
			ply:SetNWInt("blades", 3)
		elseif equipment == EQUIP_MGS4_CQC_EX then
			ply:SetNWInt("cqc_level", 4)
		elseif equipment == EQUIP_MGS4_CQC_PLUS_3 then
			ply:SetNWInt("cqc_level", 3)
		elseif equipment == EQUIP_MGS4_SCANNER_3 then
			ply:SetNWInt("scanner", 3)
		end
	end)
else
	-- === Camera ===
	hook.Add( "CalcView", "MGS4Camera", function( ply, pos, angles, fov )
		local is_in_anim = ply:GetNWBool("animation_playing", false) or (ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and not ply:GetNWBool("is_aiming", false)) or ply:GetNWFloat("cqc_punch_time_left", 0) > 0 or ply:GetNWBool("helping_up", false) or ply:GetNWBool("is_grabbed", false)

		if ply:Team() == TEAM_SPECTATOR then return end
		if GetViewEntity() ~= LocalPlayer() then return end
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
			if GAMEMODE.Name == "Trouble in Terrorist Town" then
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
	end)

	hook.Add("HUDDrawTargetID", "MGS4PsycheTarget", function ()
		local target = LocalPlayer():GetEyeTrace().Entity
		if IsValid(target) and target:IsPlayer() then
			if GAMEMODE_NAME == "Trouble in Terrorist Town" then
				-- TODO: Draw psyche status text like health statuses are done in TTT (e.g., Awake, Tired, Half-sleep, Unconscious)
			else
				local psyche = target:GetNWFloat("psyche", 0)
				draw.SimpleText(tostring(math.Round(psyche, 0)) .. "%", "TargetIDSmall", ScrW() / 2, ScrH() / 2 + 70, Color(255,205,0,255), TEXT_ALIGN_CENTER)
			end
		end
	end)

	-- === Freeze mouse when helping up ===
	hook.Add( "InputMouseApply", "FreezeTurning", function( cmd, x, y, ang )
		local ply = LocalPlayer()

		-- Store mouse movement for camera movement when frozen
		if ply:GetNWBool("animation_playing", false) or ply:GetNWBool("is_grabbed", false) or ply:GetNWBool("helping_up", false) then
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

	local star = Material( "sprites/mgs4_star.png" )
	local sleep = Material( "sprites/mgs4_z.png" )
	hook.Add( "PostDrawTranslucentRenderables", "MGS4DrawKnockedoutStars", function()
		for _, ent in ipairs( ents.GetAll() ) do
			local is_knocked_out = ent:GetNWBool("is_knocked_out", false)
			local last_dmg_type = ent:GetNWInt("last_nonlethal_damage_type", 0)

			if ( is_knocked_out and last_dmg_type ~= 1 ) then
				local attach = ent:GetAttachment( ent:LookupAttachment( "eyes" ) )
				local psyche = ent:GetNWFloat("psyche", 0)

				if ( attach ) then
					local stars = math.Clamp( math.ceil( ( 100 - psyche ) / 20 ), 1, 5 )

					for i = 1, stars do
						local time = CurTime() * 3 + ( math.pi * 2 / stars * i )
						local offset = Vector( math.sin( time ) * 5, math.cos( time ) * 5, 10 )

						render.SetMaterial( star )
						render.DrawSprite( attach.Pos + offset, 5, 5, Color( 255, 215, 94 ) )
					end
				end
			elseif ( is_knocked_out and last_dmg_type == 1 ) then
				local attach = ent:GetAttachment( ent:LookupAttachment( "eyes" ) )
				local psyche = ent:GetNWFloat("psyche", 0)

				if ( attach ) then
					local zzz = math.Clamp( math.ceil( ( 100 - psyche ) / 33 ), 1, 3 )

					for i = 1, zzz do
						local time = CurTime() * 2 + ( math.pi * 4 / zzz * i * 4 )
						local vertical_offset = (time % 6 * 4) + 10
						local horizontal_offset = math.sin(time + i) * 4 
						local offset = Vector(horizontal_offset, 0, vertical_offset)

						local t = (vertical_offset - 10) / (6 * 4)
						local size = (1 - math.abs(t - 0.5) * 2) * 6

						render.SetMaterial(sleep)
						render.DrawSprite(attach.Pos + offset, size, size, Color(255, 215, 94, 220))
					end
				end
			end
		end
	end )
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
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_RELOAD)
	elseif ply:GetNWEntity("cqc_grabbing", NULL) ~= NULL and ply:GetNWBool("is_aiming", false) then
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
		
		if not IsValid(target) or not target:IsPlayer() then return end
		
		local grabbing_anim

		local grabbing_loop = ply:LookupSequence("mgs4_grab_loop")
		local grabbing_aim = ply:LookupSequence("mgs4_grab_aim")
		local grabbing_chocking = ply:LookupSequence("mgs4_grab_chocking")

		local grabbing_crouched_loop = ply:LookupSequence("mgs4_grab_crouched_loop")
		local grabbing_crouched_aim = ply:LookupSequence("mgs4_grab_crouched_aim")
		local grabbing_crouched_chocking = ply:LookupSequence("mgs4_grab_crouched_chocking")

		if target:GetNWBool("is_choking", false) then
			if target:GetNWBool("is_grabbed_crouched", false) then
				grabbing_anim = grabbing_crouched_chocking
			else
				grabbing_anim = grabbing_chocking
			end
		elseif ply:GetNWBool("is_aiming", false) then
			if target:GetNWBool("is_grabbed_crouched", false) then
				grabbing_anim = grabbing_crouched_aim
			else
				grabbing_anim = grabbing_aim
			end
		else
			if target:GetNWBool("is_grabbed_crouched", false) then
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

		local grabbed_crouched_loop = ply:LookupSequence("mgs4_grabbed_crouched_loop")
		local grabbed_crouched_chocking = ply:LookupSequence("mgs4_grabbed_crouched_chocking")

		if ply:GetNWBool("is_choking", false) then
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

