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
	"Show the psyche in the HUD, generally recommended to be off in TTT since it would be too obvious when someone is using tranquilizers"
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
	"knife",
	"magic"
}