include("autorun/sh_mgs4.lua")

surface.CreateFont("MGS4HudNumbers", {
    font = "Tahoma",
    size = 72,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
})

hook.Add("HUDPaint", "MGS4HUDPaint", function()
    local ply = LocalPlayer()

    if ply:Alive() == false then return end

    -- Player skills hud (always present regardless of gamemode)

    local cqc_level = ply:GetNW2Int("cqc_level", 0)
    local blades3 = ply:GetNW2Bool("blades3", false)
    local scanner3 = ply:GetNW2Bool("scanner3", false)

    local hud_items = {}

    if cqc_level > 0 then
        if cqc_level < 4 then
            table.insert(hud_items, { label = "CQC+", value = cqc_level })
        else
            table.insert(hud_items, { label = "CQC EX", value = nil })
        end
    end

    if blades3 then
        table.insert(hud_items, { label = "BLADES", value = 3 })
    end

    if scanner3 then
        table.insert(hud_items, { label = "SCANNER", value = 3 })
    end

    local baseY = 715
    local offsetY = 20

    for i, item in ipairs(hud_items) do
        local y = baseY + (i - 1) * offsetY
        draw.SimpleText(item.label, "HudDefault", 135, y, Color(255,255,0,255), TEXT_ALIGN_LEFT)
        if item.value then
            draw.SimpleText(item.value, "HudDefault", 255, y, Color(255,255,0,255), TEXT_ALIGN_LEFT)
        end
    end

    -- Psyche in Hud (Only present in Sandbox or other modes that aren't TTT)

    local psyche = ply:GetNW2Float("psyche", 0)

    local xOffset = 0

    if ply:Armor() > 0 then
        xOffset = 295
    end


    draw.RoundedBox( 10, 315 + xOffset, 973, 245, 80, Color(0,0,0,80))
    draw.SimpleText("PSYCHE", "HudDefault", 335 + xOffset, 1015, Color(255,205,0,255), TEXT_ALIGN_LEFT)
    draw.SimpleText(tostring(math.Round(psyche, 0)), "MGS4HudNumbers", 440 + xOffset, 975, Color(255,205,0,255), TEXT_ALIGN_LEFT)
end)


hook.Add("HUDDrawTargetID", "MGS4PsycheTarget", function ()
    local target = LocalPlayer():GetEyeTrace().Entity
    if IsValid(target) and target:IsPlayer() then
        local psyche = target:GetNW2Float("psyche", 0)
        draw.SimpleText(tostring(math.Round(psyche, 0)) .. "%", "TargetIDSmall", ScrW() / 2, ScrH() / 2 + 70, Color(255,205,0,255), TEXT_ALIGN_CENTER)
    end
end)

-- === Freeze mouse when helping up ===
hook.Add( "InputMouseApply", "FreezeTurning", function( cmd )
    local ply = LocalPlayer()

    if ply:GetNW2Bool("helping_up", false) then
        cmd:SetMouseX( 0 )
        cmd:SetMouseY( 0 )

        return true
    end

end )

local star = Material( "sprites/mgs4_star.png" )
local sleep = Material( "sprites/mgs4_z.png" )
hook.Add( "PostDrawTranslucentRenderables", "MGS4DrawKnockedoutStars", function()
    for _, ent in ipairs( ents.GetAll() ) do
        local is_knocked_out = ent:GetNW2Bool("is_knocked_out", false)
        local last_dmg_type = ent:GetNW2Int("last_nonlethal_damage_type", 0)

        if ( is_knocked_out and last_dmg_type ~= 1 ) then
            local attach = ent:GetAttachment( ent:LookupAttachment( "eyes" ) )
            local psyche = ent:GetNW2Float("psyche", 0)

            if ( attach ) then
                local stars = math.Clamp( math.ceil( ( 100 - psyche ) / 20 ), 1, 5 )
                
                for i = 1, stars do
                    local time = CurTime() * 3 + ( math.pi * 2 / stars * i )
                    local offset = Vector( math.sin( time ) * 5, math.cos( time ) * 5, 10 )
                    
                    render.SetMaterial( star )
                    render.DrawSprite( attach.Pos + offset, 5, 5, Color( 255, 215, 94 ) )
                end
            end
        elseif ( is_knocked_out and last_dmg_type == 1 ) then
            local attach = ent:GetAttachment( ent:LookupAttachment( "eyes" ) )
            local psyche = ent:GetNW2Float("psyche", 0)

            if ( attach ) then
                local zzz = math.Clamp( math.ceil( ( 100 - psyche ) / 33 ), 1, 3 )

                for i = 1, zzz do
                    local time = CurTime() * 2 + ( math.pi * 4 / zzz * i * 4 )
                    local vertical_offset = (time % 6 * 4) + 10
                    local horizontal_offset = math.sin(time + i) * 4 
                    local offset = Vector(horizontal_offset, 0, vertical_offset)

                    local t = (vertical_offset - 10) / (6 * 4)
                    local size = (1 - math.abs(t - 0.5) * 2) * 6

                    render.SetMaterial(sleep)
                    render.DrawSprite(attach.Pos + offset, size, size, Color(255, 215, 94, 220))
                end
            end
        end
    end
end )
