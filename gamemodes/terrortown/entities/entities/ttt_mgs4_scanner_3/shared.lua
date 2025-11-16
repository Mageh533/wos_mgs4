AddCSLuaFile()

CreateConVar("ttt_mgs4_scanner_3_detective", 1, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Detectives be able to buy SCANNER 3?")
CreateConVar("ttt_mgs4_scanner_3_traitor", 0, SERVER and {FCVAR_ARCHIVE, FCVAR_REPLICATED} or FCVAR_REPLICATED, "Should Traitors be able to buy SCANNER 3?")

EQUIP_MGS4_SCANNER_3 = GenerateNewEquipmentID()

local perk = {
	id = EQUIP_MGS4_SCANNER_3,
	loadout = false,
	type = "item_passive",
	material = "vgui/entities/scannerplus3",
	name = "mgs4_scannerplus3_name",
	desc = "mgs4_scannerplus3_desc",
}

-- There is no point in buying this if the traitors/detectives cannot use cqc grabs

if (GetConVar("ttt_mgs4_scanner_3_detective"):GetBool()) and GetConVar("ttt_mgs4_base_cqc_level_detective"):GetInt() > 0 then
	table.insert(EquipmentItems[ROLE_DETECTIVE], perk)
end

if (GetConVar("ttt_mgs4_scanner_3_traitor"):GetBool()) and GetConVar("ttt_mgs4_base_cqc_level_traitor"):GetInt() > 0 then
	table.insert(EquipmentItems[ROLE_TRAITOR], perk)
end

-- This is a common technique for ensuring nothing below this line is executed on the Server
if not CLIENT then return end

LANG.AddToLanguage("english", "mgs4_scannerplus3_name", "SCANNER 3")
LANG.AddToLanguage("english", "mgs4_scannerplus3_desc", "Skill needed: CQC+ or CQC EX\n\nPress the use button to inject while in a grab.\nCan share data through SOP to other detectives/traitors.\n- Scanning time *** (30 seconds)")
