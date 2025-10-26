AddCSLuaFile()

CreateConVar("ttt_mgs4_cqc_plus_3_detective", 0, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Detectives be able to buy CQC+3?")
CreateConVar("ttt_mgs4_cqc_plus_3_traitor", 1, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Traitors be able to buy CQC+3?")

EQUIP_MGS4_CQC_PLUS_3 = GenerateNewEquipmentID()

local perk = {
	id = EQUIP_MGS4_CQC_PLUS_3,
	loadout = false,
	type = "item_passive",
	material = "vgui/entities/cqcplus3",
	name = "mgs4_cqcplus3_name",
	desc = "mgs4_cqcplus3_desc",
}

if (GetConVar("ttt_mgs4_cqc_plus_3_detective"):GetBool()) then
	table.insert(EquipmentItems[ROLE_DETECTIVE], perk)
end

if (GetConVar("ttt_mgs4_cqc_plus_3_traitor"):GetBool()) then
	table.insert(EquipmentItems[ROLE_TRAITOR], perk)
end

-- This is a common technique for ensuring nothing below this line is executed on the Server
if not CLIENT then return end

LANG.AddToLanguage("english", "mgs4_cqcplus3_name", "CQC+3")
LANG.AddToLanguage("english", "mgs4_cqcplus3_desc", "Close quarters combat skill. \nPress and hold the CQC button without pressing the movement buttons to grab a player as a Human shield. \n\n- Can capture and use advanced CQC\n- Can take weapons from enemies\n- Knockout damage *** (75)")