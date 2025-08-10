CreateConVar( "mgs4_psyche_recovery", "10", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How much psyche is recovered per second when knocked out" )
CreateConVar( "mgs4_psyche_recovery_action", "5", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How much psyche is recovered when the player presses the action button" )

-- Note: Disabled in TTT
CreateClientConVar( "mgs4_actions_in_thirdperson", "0", true, false, "Show actions in third-person view", 0, 1 )
