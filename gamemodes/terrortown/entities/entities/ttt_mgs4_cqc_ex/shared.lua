AddCSLuaFile()

CreateConVar("ttt_mgs4_cqcex_detective", 1, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Detectives be able to buy CQC EX?")
CreateConVar("ttt_mgs4_cqcex_traitor", 0, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Traitors be able to buy CQC EX?")

EQUIP_MGS4_CQC_EX = GenerateNewEquipmentID()

local perk = {
	id = EQUIP_MGS4_CQC_EX,
	loadout = false,
	type = "item_passive",
	material = "vgui/entities/cqcex",
	name = "mgs4_cqc_ex_name",
	desc = "mgs4_cqc_ex_desc",
}

if (GetConVar("ttt_mgs4_cqcex_detective"):GetBool()) then
	table.insert(EquipmentItems[ROLE_DETECTIVE], perk)
end

if (GetConVar("ttt_mgs4_cqcex_traitor"):GetBool()) then
	table.insert(EquipmentItems[ROLE_TRAITOR], perk)
end

-- This is a common technique for ensuring nothing below this line is executed on the Server
if not CLIENT then return end

LANG.AddToLanguage("english", "mgs4_cqc_ex_name", "CQC EX")
LANG.AddToLanguage("english", "mgs4_cqc_ex_desc", "The true form of CQC, surpasses standard CQC skill. \n\nAllows to perform a variety of CQC related moves and counters anyone without CQC EX. \nPress hold the CQC without pressing the movement keys to grab a player as a human shield.")
