
-- Camera during CQC
hook.Add( "CalcView", "MGS4CQCCamera", function( ply, pos, angles, fov )

    local function hide_player_head(bool)
        local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if bone < 1 then return end

        if bool then
            ply:ManipulateBoneScale(bone, Vector(0,0,0))
        else
            ply:ManipulateBoneScale(bone, Vector(1,1,1))
        end
    end

    local thirdperson = GetConVar("mgs4_cqc_thirdperson"):GetBool()

    hide_player_head(!thirdperson)

    local view = {
        origin = pos - ( angles:Forward() * (thirdperson and 100 or 0) ),
        angles = angles,
        fov = fov,
        drawviewer = true
    }

    return view
end )
