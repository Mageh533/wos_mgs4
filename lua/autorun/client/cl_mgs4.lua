include("autorun/sh_mgs4.lua")

surface.CreateFont("MGS4HudNumbers", {
    font = "HudNumbers",
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
