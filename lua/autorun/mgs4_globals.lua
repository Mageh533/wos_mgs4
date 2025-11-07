-- === Server convars ===
CreateConVar(
	"mgs4_psyche_recovery",
	"1",
	{ FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE },
	"How much psyche is recovered per second when knocked out"
)
CreateConVar(
	"mgs4_psyche_recovery_action",
	"2",
	{ FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE },
	"How much psyche is recovered when the player presses the action button"
)
CreateConVar(
	"mgs4_psyche_physics_damage",
	"1",
	{ FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE },
	"Should physics damage cause psyche damage as well?",
	0,
	1
)
CreateConVar(
	"mgs4_psyche_physics_mutliplier",
	"2",
	{ FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE },
	"Physics damage will be reduced in exchange for dealing damage to the psyche (for example a value of 2 would halve physics dmg and double psyche dmg). Negative numbers would disable physical dmg and only damage the psyche."
)
CreateConVar(
	"mgs4_base_cqc_level",
	"0",
	{ FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE },
	"Base CQC level each player spawns with. 0 = Just CQC throws, 1 = CQC+1 (Grabs), 2 = CQC+2 (Higher stun damage), 3 = CQC+3 (Able to take weapons away and higher damage), 4 = CQCEX (Counters anyone without EX and maximum stun damage), -1 = Just Punch punch kick combo, -2 = Nothing"
)
CreateConVar(
	"mgs4_cqc_immunity",
	"5",
	{ FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE },
	"How long a person is immune to CQC after being CQCed"
)

CreateConVar(
	"mgs4_show_psyche_hud",
	"1",
	{ FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE },
	"Show the psyche in the HUD, generally recommended to be off in TTT since it would be too obvious when someone is using tranquilizers",
	0,
	1
)

-- === Client convars ===
CreateClientConVar(
	"mgs4_cqc_button",
	"110",
	true,
	true,
	"This is the BUTTON_CODE which handles the CQC button. If you don't know what this means, just use the mgs4_config command to set your button there."
)

CreateClientConVar("mgs4_show_skill_hud",
	"1",
	true,
	false,
	"Show the skill HUD.",
	0,
	1
)

CreateClientConVar("mgs4_actions_in_thirdperson",
	"1",
	true,
	false,
	"Show actions in third-person view.",
	0,
	1
)

-- === Global variables ===
Small_weapons_holdtypes = {
	"pistol",
	"revolver",
	"duel",
	"camera",
	"normal",
	"fist",
	"melee",
	"grenade",
	"slam",
	"knife",
	"magic"
}

Ability_names = {
	["cqc_level"] = function( lvl, displayOnly )
		if lvl >= 4 then return "CQC EX" end
		if displayOnly then return "CQC+" end
		return "CQC+ " .. lvl
	end,
	["blades"] = function( lvl, displayOnly )
		if lvl >= 4 then return "BLADES EX" end
		if displayOnly then return "BLADES" end
		return "BLADES " .. lvl
	end,
	["scanner"] = function( lvl, displayOnly )
		if lvl >= 4 then return "SCANNER EX" end
		if displayOnly then return "SCANNER" end
		return "SCANNER " .. lvl
	end
}

Ammo_types = {
	["mk2"] = "BULLET_MK2_TRANQ"
}

if not CLIENT then return end

-- Bones to hide when aiming in first person
Bones_to_hide = {
	"ValveBiped.Bip01_L_Clavicle",
	"ValveBiped.Bip01_L_UpperArm",
	"ValveBiped.Bip01_L_Forearm",
	"ValveBiped.Bip01_L_Hand",
	"ValveBiped.Bip01_L_Finger0",
	"ValveBiped.Bip01_L_Finger01",
	"ValveBiped.Bip01_L_Finger02",
	"ValveBiped.Bip01_L_Finger1",
	"ValveBiped.Bip01_L_Finger11",
	"ValveBiped.Bip01_L_Finger12",
	"ValveBiped.Bip01_L_Finger2",
	"ValveBiped.Bip01_L_Finger21",
	"ValveBiped.Bip01_L_Finger22",
	"ValveBiped.Bip01_L_Finger3",
	"ValveBiped.Bip01_L_Finger31",
	"ValveBiped.Bip01_L_Finger32",
	"ValveBiped.Bip01_L_Finger4",
	"ValveBiped.Bip01_L_Finger41",
	"ValveBiped.Bip01_L_Finger42",
}

-- Locale strings
language.Add("BULLET_MK2_TRANQ_ammo", "MK.2 Tranquiler rounds")
