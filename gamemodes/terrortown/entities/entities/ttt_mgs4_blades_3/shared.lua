AddCSLuaFile()

CreateConVar("ttt_mgs4_blades3_detective", 0, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Detectives be able to buy BLADES 3?")
CreateConVar("ttt_mgs4_blades3_traitor", 1, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Traitors be able to buy BLADES 3?")

EQUIP_MGS4_BLADES_3 = GenerateNewEquipmentID()

local perk = {
	id = EQUIP_MGS4_BLADES_3,
	loadout = false,
	type = "item_passive",
	material = "vgui/entities/bladesplus3",
	name = "mgs4_blades_3_name",
	desc = "mgs4_blades_3_desc",
}

if (GetConVar("ttt_mgs4_blades3_detective"):GetBool()) then
	table.insert(EquipmentItems[ROLE_DETECTIVE], perk)
end

if (GetConVar("ttt_mgs4_blades3_traitor"):GetBool()) then
	table.insert(EquipmentItems[ROLE_TRAITOR], perk)
end

-- This is a common technique for ensuring nothing below this line is executed on the Server
if not CLIENT then return end

LANG.AddToLanguage("english", "mgs4_blades_3_name", "BLADES 3")
LANG.AddToLanguage("english", "mgs4_blades_3_desc", "Skill wielding knives.\nRaising this skill enables faster knife attacks.\n\n- Can nove during knife attacks \nSkill needed: CQC+\n- Can cut throat during CQC capture")