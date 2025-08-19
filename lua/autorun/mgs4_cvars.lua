CreateConVar( "mgs4_psyche_recovery", "10", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How much psyche is recovered per second when knocked out" )
CreateConVar( "mgs4_psyche_recovery_action", "5", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How much psyche is recovered when the player presses the action button" )
CreateConVar( "mgs4_base_cqc_level", "0", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Base CQC level each player spawns with. 0 = Just CQC throws, 1 = CQC+1 (Grabs), 2 = CQC+2 (Higher stun damage), 3 = CQC+3 (Able to take weapons away and higher damage), 4 = CQCEX (Counters anyone without EX and maximum stun damage), -1 = Just Punch punch kick combo, -2 = Nothing" )

-- Note: Disabled in TTT
CreateClientConVar( "mgs4_actions_in_thirdperson", "0", true, false, "Show actions in third-person view", 0, 1 )
