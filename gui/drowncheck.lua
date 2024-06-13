--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

DrownCheckOverlay=defclass(DrownCheckOverlay, overlay.OverlayWidget)
DrownCheckOverlay.ATTRS {
    desc="Display a countdown to your drowning death!",
    default_pos={x=0, y=50},
    default_enabled=true,
    viewscreens= {
        'dungeonmode/Default',
    },
    frame={w=33, h=6},
}

local function get_blood()
    return dfhack.world.getAdventurer().body.blood_count
end

local function get_max_blood()
    return dfhack.world.getAdventurer().body.blood_max
end

local function get_max_breath()
    local adventurer = dfhack.world.getAdventurer()
    local toughness = dfhack.units.getPhysicalAttrValue(adventurer, df.physical_attribute_type.TOUGHNESS)
    local endurance = dfhack.units.getPhysicalAttrValue(adventurer, df.physical_attribute_type.ENDURANCE)
    local base_ticks = 200

    return math.floor((endurance + toughness) / 4) + base_ticks
end

local function get_breath()
    return get_max_breath() - dfhack.world.getAdventurer().counters.suffocation
end


function DrownCheckOverlay:init()
    self.frame_blink_counter = 0
    self.blink = true
    self:addviews{
        widgets.Panel{
            view_id='panel',
            frame={t=0, l=0},
            frame_style=gui.FRAME_MEDIUM,
            frame_background=gui.CLEAR_PEN,
            subviews={
                widgets.Label{
                    view_id='counter',
                    frame={t=0, l=0},
                    text_pen=COLOR_GRAY,
                },
            },
        },
    }
end

function DrownCheckOverlay:onRenderFrame(dc, rect)
    DrownCheckOverlay.super.onRenderFrame(self, dc, rect)
    self.subviews.panel.visible = self.get_drowning() > 0 or self.get_blood() < self.get_max_blood()
    if not self.subviews.panel.visible then return end

    local label_text = {}

    if self.frame_blink_counter % 10 == 0 then
        self.blink = not self.blink
    end

    if self.get_drowning() > 0 then
        local suffocation_pen = COLOR_CYAN
        if self.blink then
            suffocation_pen = COLOR_LIGHTCYAN
        end
        table.insert(label_text, {text = "Suffocating!", pen = suffocation_pen, width = 14})

        local margin = 16
        local percentage = get_breath() / get_max_breath()
        local barstop = math.floor((margin * percentage) + 0.5)
        for idx = 0, margin-1 do
            local color = COLOR_LIGHTCYAN
            local char = 219
            if idx >= barstop then
                -- offset it to the hollow graphic
                color = COLOR_DARKGRAY
                char = 177
            end
            table.insert(label_text, { width = 1, tile={ch=char, fg=color}})
        end

        -- table.insert(label_text, {
        --     text = string.format("%d/%d", get_breath(), get_max_breath()),
        --     gap = 2,
        --     width = 12,
        --     rjustify = true,
        --     pen = COLOR_LIGHTCYAN,
        -- })
        table.insert(label_text, NEWLINE)
    end

    if get_blood() < get_max_blood() then
        local bloodloss_pen = COLOR_RED
        if self.blink then
            bloodloss_pen = COLOR_LIGHTRED
        end
        table.insert(label_text, {text = "Bloodloss!", pen = bloodloss_pen, width = 14})

        local margin = 14
        local percentage = get_blood() / get_max_blood()
        local barstop = math.floor((margin * percentage) + 0.5)
        for idx = 0, margin-1 do
            local color = COLOR_RED
            local char = 219
            if idx >= barstop then
                -- offset it to the hollow graphic
                color = COLOR_DARKGRAY
                char = 177
            end
            table.insert(label_text, { width = 1, tile={ch=char, fg=color}})
        end

        -- table.insert(label_text, {
        --     text = string.format("%d/%d", get_blood(), get_max_blood()),
        --     gap = 2,
        --     width = 12,
        --     rjustify = true,
        --     pen = COLOR_LIGHTRED,
        -- })
        table.insert(label_text, NEWLINE)
    end

    self.subviews.counter:setText(label_text)
    self.subviews.counter:updateLayout()
    self.frame_blink_counter = self.frame_blink_counter + 1
end


OVERLAY_WIDGETS = {
    drowncheck=DrownCheckOverlay,
}