hook.Add("InitLoadAnimations", "wOS.DynaBase.MGS4", function()
    wOS.DynaBase:RegisterSource({
        Name = "MGS4 Animations",
        Type = WOS_DYNABASE.EXTENSION,
        Male = "models/mgs4/mgs4_shared.mdl",
        Female = "models/mgs4/mgs4_shared.mdl",
        Zombie = "models/mgs4/mgs4_shared.mdl",
    })

    hook.Add("PreLoadAnimations", "wOS.DynaBase.MGS4", function(gender)
        if gender == WOS_DYNABASE.SHARED then
            IncludeModel("models/mgs4/mgs4_shared.mdl")
        end
    end)
end)