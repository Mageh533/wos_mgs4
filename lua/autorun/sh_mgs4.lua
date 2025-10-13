---@diagnostic disable: undefined-field
local ent = FindMetaTable("Entity")

function ent:PlayMGS4Animation(anim, callback, autostop)
	if not self then return end

	local current_anim = self:LookupSequence(anim)
	local duration = self:SequenceDuration(current_anim)

	self:SetNWBool("animation_playing", true)
	self:SetNWFloat("cqc_button_hold_time", 0)

	local current_pos = self:GetPos()

	-- Shouldn't be able to start an anim without being in a safe position
	self:SetNWVector("safe_pos", current_pos)

	local pos_to_set
	local head_angle

	self:SetVelocity(-self:GetVelocity())

	timer.Simple(duration, function()
		if self:Alive() == false then return end

		local pelvis_matrix = self:GetBoneMatrix(self:LookupBone("ValveBiped.Bip01_Pelvis"))
		pos_to_set = pelvis_matrix:GetTranslation()

		head_angle = self:GetAttachment(self:LookupAttachment("eyes")).Ang

		self:SetPos(Vector(pos_to_set.x, pos_to_set.y, current_pos.z))

		self:SetEyeAngles(Angle(0, head_angle.y, 0))

		self:SetNWBool("animation_playing", false)

		if callback and type(callback) == "function" then
		    callback(self)
		end

		self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36)) -- Set crouch hull back to normal

	end)

	self:SetNWString('SVAnim', anim)
	self:SetNWFloat('SVAnimDelay', select(2, self:LookupSequence(anim)))
	self:SetNWFloat('SVAnimStartTime', CurTime())
	self:EmitMGS4Sound(anim)
	self:SetCycle(0)
	if autostop then
		local delay = select(2, self:LookupSequence(anim))
		timer.Simple(delay, function()
			if !IsValid(self) then return end

			local anim2 = self:GetNWString('SVAnim')

			if anim == anim2 then
				self:SetNWString('SVAnim', "")
			end
		end)
	end
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
			if pos then
				self:SetNWVector("forced_position", pos)
			else
				self:SetNWVector("forced_position", self:GetPos())
			end

			if ang then
				self:SetNWAngle("forced_angle", ang)
			else
				self:SetNWAngle("forced_angle", Angle(0, self:EyeAngles().y, 0))
			end
		else
			self:SetNWBool("force_position", false)
		end
	end

	function ent:MGS4StuckCheck()
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
				self:GetUp()
			end
			self:ForcePosition(false)
		end, true)

		self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
	end

	function ent:GetUp()
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

	function ent:Cqc_reset()
		if not self then return end

		self:SetNWBool("is_in_cqc", false)
		self:SetNWEntity("cqc_grabbing", Entity(0))
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

		local crouched = self:Crouching()
		if crouched then
			self:PlayMGS4Animation("mgs4_cqc_fail_crouched", function ()
				self:SetNWBool("is_in_cqc", false)
			end, true)
		else
			self:PlayMGS4Animation("mgs4_cqc_fail", function ()
				self:SetNWBool("is_in_cqc", false)
			end, true)
		end

		self:SetNWBool("is_in_cqc", true)
	end

	function ent:Cqc_punch()
		if not self then return end

		self:SetNWFloat("cqc_punch_time_left", 0.5) -- Time to extend the punch combo

		-- Players cannot punch with 2 handed weapons
		local current_weapon = self:GetActiveWeapon()

		if IsValid(current_weapon) then
			local weapon_slot = current_weapon:GetSlot()
			if weapon_slot ~= 1 then
				self:PlayMGS4Animation("mgs4_gun_attack", function ()
					self:Cqc_reset()
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
			self:PlayMGS4Animation("mgs4_punch", function ()
				self:SetNWInt("cqc_punch_combo", 1)
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
			self:PlayMGS4Animation("mgs4_punch_punch", function ()
				self:SetNWInt("cqc_punch_combo", 2)
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
			self:PlayMGS4Animation("mgs4_kick", function ()
				self:SetNWInt("cqc_punch_combo", 0)
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

		self:SetNWBool("is_in_cqc", true)
		self:PlayMGS4Animation(knife_anim, function()
			self:Cqc_reset()
		end, true)

		target:SetNWBool("is_in_cqc", true)
		target:PlayMGS4Animation(knifed_anim, function()
			target:SetNWBool("is_in_cqc", false)

			-- Just kill them lmao
			target:TakeDamage(1000, self, self)

		end, true)
	end

	function ent:Cqc_sop_scan(target)
		if not self or not IsValid(target) then return end

		local scan_anim = "mgs4_grab_scan"
		local scanned_anim = "mgs4_grabbed_scan"

		if target:GetNWBool("is_grabbed_crouched", false) then
			scan_anim = "mgs4_grab_crouched_scan"
			scanned_anim = "mgs4_grabbed_crouched_scan"
		end

		-- Temporarily remove weapon from player until scan is complete
		local current_weapon = self:GetActiveWeapon()
		if IsValid(current_weapon) then
			self:SetActiveWeapon(NULL)
		end

		self:PlayMGS4Animation(scan_anim, function()
			-- Give back the weapon
			if IsValid(current_weapon) then
				self:SetActiveWeapon(current_weapon)
			end
		end, true)

		target:PlayMGS4Animation(scanned_anim, nil, true)
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
					target:GetUp()
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
					target:GetUp()
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
				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
			end, true)
		else
			-- Normal throw
			self:SetNWBool("is_in_cqc", true)
			self:ForcePosition(true, self:GetPos(), self:EyeAngles())
			self:PlayMGS4Animation("mgs4_cqc_throw", function()
				self:Cqc_reset()
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

				if target:GetNWFloat("psyche", 100) > 0 then
					target:GetUp()
				end

				target:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
				target:ForcePosition(false)
			end, true)
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
				self:GetUp()
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

		local grab_anim
		local grabbed_anim
		local angle_offset = Angle(0,0,0)

		if angleAround > 135 and angleAround <= 225 then
			-- Grabbing from back
			local grab_standing_anim = "mgs4_grab_behind"
			local grabbed_standing_anim = "mgs4_grabbed_behind"

			local grab_crouched_anim = "mgs4_grab_crouched_behind"
			local grabbed_crouched_anim = "mgs4_grabbed_crouched_behind"

			if self:Crouching() then
				grab_anim = grab_crouched_anim
				grabbed_anim = grabbed_crouched_anim
			else
				grab_anim = grab_standing_anim
				grabbed_anim = grabbed_standing_anim
			end
		else
			-- Grabbing from front
			local grab_standing_anim = "mgs4_grab_front"
			local grabbed_standing_anim = "mgs4_grabbed_front"

			local grab_crouched_anim = "mgs4_grab_crouched_front"
			local grabbed_crouched_anim = "mgs4_grabbed_crouched_front"

			if self:Crouching() then
				grab_anim = grab_crouched_anim
				grabbed_anim = grabbed_crouched_anim
			else
				grab_anim = grab_standing_anim
				grabbed_anim = grabbed_standing_anim
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

		if self:Crouching() then
			target:SetNWBool("is_grabbed_crouched", true)
		else
			target:SetNWBool("is_grabbed_crouched", false)
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
			local target = self:GetNWEntity("cqc_grabbing", Entity(0))

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
			self:SetNWFloat("cqc_immunity_remaining", GetConVar("mgs4_cqc_immunity"):GetFloat())
		end, true)
	end

	-- == Loop sequence to ensure correct positions at all times and handle grabbing actions ==
	function ent:Cqc_loop()
		if not self then return end

		local target = self:GetNWEntity("cqc_grabbing", Entity(0))
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

		if not self:GetNWBool("is_aiming", false) then
			-- Normal mode, hold cqc button to choke, hold+forward or backward to throw, click to throat cut, e to scan.
			if self:GetNWBool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) then
				-- Holding the CQC button starts choking
				target:SetNWFloat("psyche", math.max(target:GetNWFloat("psyche", 100) - ((20 * FrameTime()) * self:GetNWInt("cqc_level", 1)), 0))
				target:SetNWInt("last_nonlethal_damage_type", 2)
				target:SetNWBool("is_choking", true)
			elseif self:GetNWBool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) and not target:GetNWBool("is_grabbed_crouched", false) then
				-- Holding and moving forward throws the target in front
				self:Cqc_throw(target, 1)
			elseif self:GetNWBool("cqc_button_held", false) and not self:KeyPressed(IN_USE) and not self:KeyPressed(IN_FORWARD) and self:KeyPressed(IN_BACK) and not target:GetNWBool("is_grabbed_crouched", false) then
				-- Holding and moving backward throws the target behind
				self:Cqc_throw(target, 2)
			elseif self:GetNWBool("cqc_button_held", false) and self:KeyPressed(IN_USE) and self:GetNWBool("blades3", false) and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) then
				-- press e while holding does the throat cut
				self:Cqc_throat_cut(target)
			elseif not self:GetNWBool("cqc_button_held", false) and self:KeyPressed(IN_USE) and self:GetNWBool("scanner3", false) and not self:KeyPressed(IN_FORWARD) and not self:KeyPressed(IN_BACK) then
				-- press e while not holding does the scan
				self:Cqc_sop_scan(target)
			elseif self:KeyPressed(IN_BACK) and not target:GetNWBool("is_grabbed_crouched", false) then
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
		local large_weapon = false -- Large weapons have a different CQC action and can only throw with EX level CQC

		local current_weapon = self:GetActiveWeapon()
		if IsValid(current_weapon) then
			local weapon_slot = current_weapon:GetSlot()
			if weapon_slot ~= 1 then
				large_weapon = true
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
			self:PlayMGS4Animation("mgs4_wakeup_start", function()
				self:SetNWBool("helping_up", true)
				self:SetCycle(0)
			end, true)
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

		if key == IN_ATTACK2 and ply:GetNWEntity("cqc_grabbing") ~= Entity(0) then
			ply:SetNWBool("is_aiming", not ply:GetNWBool("is_aiming", false))
		end

		if key == IN_ATTACK and ply:GetNWEntity("cqc_grabbing") ~= Entity(0) and not ply:GetNWBool("is_aiming", false) then
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
			entity:GetUp()
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
		ent:SetNWEntity("cqc_grabbing", Entity(0))

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

		--- Each CQC Level grants you:
		--- -2 = Nothing
		--- -1 = Punch punch kick combo
		---  0 = CQC throw
		---  1 = (CQC+1) Grabs
		---  2 = (CQC+2) Higher stun damage
		---  3 = (CQC+3) Higher stun damage and take weapons from enemies
		---  4 = (CQCEX) Counter CQC and maximum stun damage
		ent:SetNWInt("cqc_level", GetConVar("mgs4_base_cqc_level"):GetInt())

		-- How long the player is holding the CQC button for (for knowing if they want to grab or punch)
		ent:SetNWBool("cqc_button_held", false)
		ent:SetNWFloat("cqc_button_hold_time", 0)

		-- Time of the punch punch kick combo. Keep pressing to complete the combo, press it once to just punch once.
		ent:SetNWFloat("cqc_punch_time_left", 0)

		ent:SetNWInt("cqc_punch_combo", 0) -- 1 = First punch, 2 = Second punch, 3 = Kick
		ent:SetNWBool("helping_up", false)

		--- Immunity to CQC for a few seconds to make it fairer
		ent:SetNWFloat("cqc_immunity_remaining", 0)

		--- Grab abilities, requires at least CQC level 1
		ent:SetNWBool("blades3", true)
		ent:SetNWBool("scanner3", true)

		--- Psyche
		--- If it reaches 0, the entity will be knocked out
		--- Only regenerates when knocked out or if reading a magazine
		ent:SetNWFloat("psyche", 100)

		ent:SetNWBool("is_knocked_out", false)

		---- Last Non-Lethal Damage Type
		--- 0 = CQC Stun (Face up)
		--- 1 = Tranquilizers
		--- 2 = Generic Stun
		--- 3 = CQC Stun (Face down)
		ent:SetNWInt("last_nonlethal_damage_type", 0)
	end)

	-- Cleanup on player death
	hook.Add("PostPlayerDeath", "MGS4PlayerDeathCleanup", function(ply)
		ply:SetNWBool("animation_playing", false)
		ply:SetNWBool("will_grab", false)
		ply:SetNWEntity("cqc_grabbing", Entity(0))
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
		ply:SetNWBool("cqc_button_held", false)
		ply:SetNWFloat("cqc_button_hold_time", 0)
		ply:SetNWFloat("cqc_punch_time_left", 0)
		ply:SetNWInt("cqc_punch_combo", 0)
		ply:SetNWBool("helping_up", false)
		ply:SetNWFloat("cqc_immunity_remaining", 0)
		ply:SetNWBool("blades3", true)
		ply:SetNWBool("scanner3", true)
		ply:SetNWFloat("psyche", 100)
		ply:SetNWBool("is_knocked_out", false)
		ply:SetNWInt("last_nonlethal_damage_type", 0)
	end)

	hook.Add("DoPlayerDeath", "MGS4PlayerPreDeathCleanup", function(ply, attacker, dmg)
		if ply:GetNWBool("cqc_grabbing", Entity(0)) ~= Entity(0) then
			local target = ply:GetNWBool("cqc_grabbing", Entity(0))
			target:Cqc_grab_letgo(1, target:GetNWBool("is_grabbed_crouched", false))
		end
	end)

	-- === Non lethal Damage Handling ===
	hook.Add("EntityTakeDamage", "MGS4EntityTakeDamage", function(ent, dmginfo)
		if not IsValid(ent) then return end

		-- Check if the entity is a player or NPC
		if ent:IsPlayer() or ent:IsNPC() then
			if ent:GetNWBool("is_knocked_out", false) then return end

			if dmginfo:GetDamageType() == DMG_CLUB or dmginfo:GetDamageType() == DMG_SONIC or dmginfo:GetDamageType() == DMG_CRUSH then
				local psyche = ent:GetNWFloat("psyche", 100)
				psyche = psyche - dmginfo:GetDamage() * 2
				ent:SetNWFloat("psyche", math.max(psyche, 0)) -- Cap at 0
				ent:SetNWInt("last_nonlethal_damage_type", 1) -- For testing purposes, to change later.
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

			if entity:GetNWBool("cqc_button_held") and not entity:GetNWBool("animation_playing", false) and entity:GetActiveWeapon():GetSlot() ~= 0 and entity:GetActiveWeapon():GetSlot() ~= 4 and entity:OnGround() then
				entity:SetNWFloat("cqc_button_hold_time", entity:GetNWFloat("cqc_button_hold_time", 0) + FrameTime())
			end

			if entity:GetNWFloat("cqc_immunity_remaining", 0) > 0 then
				entity:SetNWFloat("cqc_immunity_remaining", entity:GetNWFloat("cqc_immunity_remaining", 0) - FrameTime())
				if entity:GetNWFloat("cqc_immunity_remaining", 0) < 0 then
					entity:SetNWFloat("cqc_immunity_remaining", 0)
				end
			end

			-- Press it once for Punch
			if entity:GetNWBool("cqc_button_held", false) == false and entity:GetNWFloat("cqc_button_hold_time", 0) > 0 and entity:GetNWFloat("cqc_button_hold_time", 0) <= 0.5 and not entity:GetNWBool("animation_playing", false) and entity:GetActiveWeapon():GetSlot() ~= 0 and entity:GetActiveWeapon():GetSlot() ~= 4 then
				entity:SetNWFloat("cqc_button_hold_time", 0)
				entity:Cqc_punch()
			end

			-- Hold the button for CQC Throw and Grab
			if entity:GetNWFloat("cqc_button_hold_time", 0) > 0.2 and entity:GetNWEntity("cqc_grabbing") == Entity(0) and not entity:GetNWBool("animation_playing", false) then
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
				end, true)
			end

			if entity:GetNWFloat("cqc_punch_time_left", 0) > 0 then
				entity:SetNWFloat("cqc_punch_time_left", math.max(entity:GetNWFloat("cqc_punch_time_left", 0) - FrameTime(), 0))
				if entity:GetNWFloat("cqc_punch_time_left", 0) <= 0 then
					entity:SetNWInt("cqc_punch_combo", 0) -- Reset combo
				end
			end

			if entity:GetNWBool("force_position", false) then
				local pos = entity:GetNWVector("forced_position", Vector(0, 0, 0))
				local ang = entity:GetNWAngle("forced_angle", Angle(0, 0, 0))

				entity:SetPos(pos)
				entity:SetEyeAngles(ang)
			end

			if entity:GetNWEntity("cqc_grabbing", Entity(0)) ~= Entity(0) then
				entity:Cqc_loop()
			end

			if entity:GetNWBool("animation_playing", true) then
				entity:Freeze(true)
				entity:SetNWFloat("stuck_check", 1.0)
			else
				entity:Freeze(false)
			end

			print(entity:GetNWFloat("stuck_check"))

			if entity:GetNWFloat("stuck_check") > 0 then
				entity:MGS4StuckCheck()
				entity:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

				entity:SetNWFloat("stuck_check", entity:GetNWFloat("stuck_check", 0) - FrameTime())
			elseif not entity:GetNWBool("is_knocked_out", true) then
				entity:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			end
		end
	end)
else
	-- === Camera ===
	hook.Add( "CalcView", "MGS4Camera", function( ply, pos, angles, fov )
		local is_in_anim = ply:GetNWBool("animation_playing", false) or (ply:GetNWEntity("cqc_grabbing", Entity(0)) ~= Entity(0) and not ply:GetNWBool("is_aiming", false)) or ply:GetNWFloat("cqc_punch_time_left", 0) > 0 or ply:GetNWBool("helping_up", false) or ply:GetNWBool("is_grabbed", false)

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

	surface.CreateFont("MGS4HudNumbers", {
		font = "Tahoma",
		size = 72,
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

		-- Player skills hud (always present regardless of gamemode)

		local cqc_level = ply:GetNWInt("cqc_level", 0)
		local blades3 = ply:GetNWBool("blades3", false)
		local scanner3 = ply:GetNWBool("scanner3", false)

		local hud_items = {}

		if cqc_level > 0 then
			if cqc_level < 4 then
				table.insert(hud_items, { label = "CQC+", value = cqc_level })
			else
				table.insert(hud_items, { label = "CQC EX", value = nil })
			end
		end

		if blades3 then
			table.insert(hud_items, { label = "BLADES", value = 3 })
		end

		if scanner3 then
			table.insert(hud_items, { label = "SCANNER", value = 3 })
		end

		local baseY = 715
		local offsetY = 20

		for i, item in ipairs(hud_items) do
			local y = baseY + (i - 1) * offsetY
			draw.SimpleText(item.label, "HudDefault", 135, y, Color(255,255,0,255), TEXT_ALIGN_LEFT)
			if item.value then
				draw.SimpleText(item.value, "HudDefault", 255, y, Color(255,255,0,255), TEXT_ALIGN_LEFT)
			end
		end

		-- Psyche in Hud (Only present in Sandbox or other modes that aren't TTT)

		local psyche = ply:GetNWFloat("psyche", 0)

		local xOffset = 0

		if ply:Armor() > 0 then
			xOffset = 295
		end


		draw.RoundedBox( 10, 315 + xOffset, 973, 245, 80, Color(0,0,0,80))
		draw.SimpleText("PSYCHE", "HudDefault", 335 + xOffset, 1015, Color(255,205,0,255), TEXT_ALIGN_LEFT)
		draw.SimpleText(tostring(math.Round(psyche, 0)), "MGS4HudNumbers", 440 + xOffset, 975, Color(255,205,0,255), TEXT_ALIGN_LEFT)
	end)


	hook.Add("HUDDrawTargetID", "MGS4PsycheTarget", function ()
		local target = LocalPlayer():GetEyeTrace().Entity
		if IsValid(target) and target:IsPlayer() then
			local psyche = target:GetNWFloat("psyche", 0)
			draw.SimpleText(tostring(math.Round(psyche, 0)) .. "%", "TargetIDSmall", ScrW() / 2, ScrH() / 2 + 70, Color(255,205,0,255), TEXT_ALIGN_CENTER)
		end
	end)

	-- === Freeze mouse when helping up ===
	hook.Add( "InputMouseApply", "FreezeTurning", function( cmd )
		local ply = LocalPlayer()

		if ply:GetNWBool("helping_up", false) then
			cmd:SetMouseX( 0 )
			cmd:SetMouseY( 0 )

			return true
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

-- === Handling buttons while grabbing ===
hook.Add("StartCommand", "MGS4StartCommand", function(ply, cmd)
	if ply:GetNWEntity("cqc_grabbing", Entity(0)) ~= Entity(0) and not ply:GetNWBool("is_aiming", false) and not ply:GetNWBool("is_knife", false) then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_RELOAD)
	elseif ply:GetNWEntity("cqc_grabbing", Entity(0)) ~= Entity(0) and ply:GetNWBool("is_aiming", false) then
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_FORWARD)
		cmd:RemoveKey(IN_BACK)
		cmd:RemoveKey(IN_MOVELEFT)
		cmd:RemoveKey(IN_MOVERIGHT)
		cmd:RemoveKey(IN_DUCK)
	elseif ply:GetNWBool("helping_up", false) then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_DUCK)
	end
end)

-- === Animation Handling for players ===
hook.Add("CalcMainActivity", "MGS4Anims", function(ply, vel)
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
	elseif ply:GetNWEntity("cqc_grabbing", Entity(0)) ~= Entity(0) and not ply:GetNWBool("animation_playing", false) then
		-- == CQC grab loop ==
		local grabbing_anim

		local grabbing_loop = ply:LookupSequence("mgs4_grab_loop")
		local grabbing_aim = ply:LookupSequence("mgs4_grab_aim")
		local grabbing_chocking = ply:LookupSequence("mgs4_grab_chocking")

		local grabbing_crouched_loop = ply:LookupSequence("mgs4_grab_crouched_loop")
		local grabbing_crouched_aim = ply:LookupSequence("mgs4_grab_crouched_aim")
		local grabbing_crouched_chocking = ply:LookupSequence("mgs4_grab_crouched_chocking")

		local target = ply:GetNWEntity("cqc_grabbing", Entity(0))

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

