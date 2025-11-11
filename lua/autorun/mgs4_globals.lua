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
	"0",
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

CreateClientConVar("mgs4_show_tips_hud",
	"1",
	true,
	false,
	"Show the tips on the HUD.",
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

-- the mgs4_config command to set up the cqc key
local function OpenCQCKeySetup()
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 220)
    frame:Center()
    frame:SetTitle("Set Your CQC Key")
    frame:MakePopup()

    local label = vgui.Create("DLabel", frame)
    label:SetPos(20, 40)
    label:SetWide(360)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:SetText(
        "Snake, try to remember some of the basics of CQC...\n\n" ..
        "Press the button below, then press your preferred key to use CQC actions.\n\n" ..
        "Note: This is not a normal bind, so it will not replace an existing bind. " ..
        "Set it to a unique key."
    )

    -- Button to start listening
    local startButton = vgui.Create("DButton", frame)
    startButton:SetSize(150, 30)
    startButton:SetPos(125, 150)
    startButton:SetText("Press a key now")

    local waitingForKey = false

    startButton.DoClick = function()
        waitingForKey = true
        startButton:SetText("Waiting for key...")
    end

    -- Capture key input
    frame.OnKeyCodePressed = function(self, key)
        if not waitingForKey then return end
        waitingForKey = false

        RunConsoleCommand("mgs4_cqc_button", tostring(key))
        notification.AddLegacy("CQC key set to code: " .. key, NOTIFY_GENERIC, 5)

        startButton:SetText("Press a key now")
        frame:Close()
    end

    frame.OnMousePressed = function(self, key)
        if not waitingForKey then return end
        waitingForKey = false

        RunConsoleCommand("mgs4_cqc_button", tostring(key))
        notification.AddLegacy("CQC button set to code: " .. key, NOTIFY_GENERIC, 5)

        startButton:SetText("Press a key now")
        frame:Close()
    end
end

-- You can run this via console or from a menu:
concommand.Add("mgs4_config", OpenCQCKeySetup)

-- Run setup automatically if the key hasn't been set
timer.Simple(1, function()
    local cqc_button = GetConVar("mgs4_cqc_button"):GetInt()
    if cqc_button == 0 then
        OpenCQCKeySetup()
    end
end)

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

-- PNG Materials
Star 				= Material( "sprites/mgs4_star.png" )
Sleep 				= Material( "sprites/mgs4_z.png" )
Cqc_button 			= Material( "sprites/cqc_button.png" )
Cqc_throw_normal 	= Material( "sprites/cqc_throw_normal.png" )
Cqc_throw_weapon 	= Material( "sprites/cqc_throw_weapon.png" )
Grab_aim			= Material( "sprites/grab_aim.png" )
Grab_choke_prone	= Material( "sprites/grab_choke_prone.png" )
Grab_choke			= Material( "sprites/grab_choke.png" )
Grab_knife			= Material( "sprites/grab_knife.png" )
Grab_scan			= Material( "sprites/grab_scan.png" )
Grab_throw_backward	= Material( "sprites/grab_throw_backward.png" )
Grab_throw_forward	= Material( "sprites/grab_throw_forward.png" )
