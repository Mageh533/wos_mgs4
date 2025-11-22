AddCSLuaFile()

ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.AutomaticFrameAdvance = true

if SERVER then
    local function TransferModelData(ent, from)
        local ent1Model = from:GetModel()
        local ent1Skin = from:GetSkin()
        local ent1BodyGroups = from:GetNumBodyGroups()
        ent:SetModel(ent1Model)
        ent:SetSkin(ent1Skin)
        for i = 0, ent1BodyGroups - 1 do
            ent:SetBodygroup(i, from:GetBodygroup(i))
        end
    end

    function ENT:Initialize()
        self:SetModel("models/player/breen.mdl")
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self.NPC:SetNoDraw(true)

        self:ResetSequence(self.Sequence)
        self:SetPlaybackRate(self.Speed and self.Speed or 1)
        local delay = select(2, self:LookupSequence(self.Sequence))
        self:SetCycle( ( ( (delay-0.1)/delay )-1)*-1 )

        local bd = ents.Create("base_anim")
        bd:SetParent(self)
        bd:AddEffects(1)
        bd:SetFlexScale(1)
        bd:Spawn()
        self.bd = bd
        TransferModelData(bd, self.NPC)
        self:DeleteOnRemove(bd)
    end

    function ENT:Stop()
        local ow = self.NPC

        if !IsValid(ow) then return end

        self.NPC = nil
        ow:SetNoDraw(false)
        ow:DrawShadow(true)
        if ow:IsNPC() and ow.SetNPCState then
            ow:ClearSchedule()
            ow:SetSchedule(SCHED_IDLE_STAND)
        elseif ow:IsNextBot() then
            ow:StartActivity(ACT_IDLE)
        end

        timer.Simple(0.3, function ()
            if !IsValid(ow) then return end
            if ow.IsVJBaseSNPC then
                ow.HasDeathAnimation = true
            end
            ow:RemoveEFlags(EFL_NO_THINK_FUNCTION)
        end)
        local wep = ow:GetActiveWeapon()
        if IsValid(wep) then
            wep:SetNoDraw(false)
        end
    end

    function ENT:Think()
        local ow = self.NPC

        if !IsValid(ow) or not ow:Alive() then
            self:Stop()
            self:Remove()
            return
        else
            self:SetNoDraw(true)
            self:DrawShadow(false)
            self:NextThink(CurTime())
            self:SetPos(ow:GetPos())
            self:SetAngles(ow:GetAngles())
            ow:SetNoDraw(true)
            ow:DrawShadow(false)
            if ow.IsVJBaseSNPC then
                ow.HasDeathAnimation = false
            end
            if not ow:IsEFlagSet(EFL_NO_THINK_FUNCTION) then
                ow:AddEFlags(EFL_NO_THINK_FUNCTION)
            end
            local wep = ow:GetActiveWeapon()
            if IsValid(wep) then
                wep:SetNoDraw(true)
            end
        end
        return true
    end
end