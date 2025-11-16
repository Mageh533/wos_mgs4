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
        ow:SetRenderMode(RENDERMODE_NORMAL)
        ow:DrawShadow(true)
        ow:RemoveEFlags(EFL_NO_THINK_FUNCTION)
        local wep = ow:GetActiveWeapon()
        if IsValid(wep) then
            wep:SetNoDraw(false)
        end
    end

    function ENT:Think()
        local ow = self.NPC

        if !IsValid(ow) or ow:Health() <= 0 then
            self:Stop()
            self:Remove()
        else
            ow:SetNoDraw(true)
            ow:SetRenderMode(RENDERMODE_NONE)
            ow:DrawShadow(false)
            if ow.IsVJBaseSNPC then
                ow.HasDeathAnimation = false
            end
            ow:AddEFlags(EFL_NO_THINK_FUNCTION)
            local wep = ow:GetActiveWeapon()
            if IsValid(wep) then
                wep:SetNoDraw(true)
            end
        end
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self:NextThink(CurTime())
        return true
    end
end