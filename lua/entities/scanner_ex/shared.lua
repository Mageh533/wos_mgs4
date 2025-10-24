AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "item_box"
ENT.PrintName = "Scanner EX"
ENT.Author = "Mageh533"
ENT.Category = "MGS4"
ENT.Contact = "STEAM_0:0:53473978" -- El menda
ENT.Purpose = "Grants you Scanner EX skill"
ENT.AutomaticFrameAdvance = true -- Must be set on client
ENT.Spawnable = true
ENT.IconOverride = "vgui/entities/scannerex"

-- This will be called on both the Client and Server realms
function ENT:SecondInitialize()
	-- Ensure code for the Server realm does not accidentally run on the Client
    self:SetPickup( 1, { "scanner", 4 } )
end