--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

DrownCheckOverlay=defclass(DrownCheckOverlay, overlay.OverlayWidget)
DrownCheckOverlay.ATTRS {
    desc="Display a countdown to your drowning death!",
    default_pos={x=20, y=0},
    default_enabled=true,
    viewscreens= {
        'dungeonmode/Default',
    },
    frame={w=24, h=3},
}

function DrownCheckOverlay:get_drowning()
    return dfhack.world.getAdventurer().counters.suffocation
end

function DrownCheckOverlay:get_max_drown()
    local adventurer = dfhack.world.getAdventurer()
    local toughness = dfhack.units.getPhysicalAttrValue(adventurer, df.physical_attribute_type.TOUGHNESS)
    local endurance = dfhack.units.getPhysicalAttrValue(adventurer, df.physical_attribute_type.ENDURANCE)
    local base_ticks = 200

    return math.floor((endurance + toughness) / 4) + base_ticks
end

function DrownCheckOverlay:init()
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
                    text='hi nerd',
                    text_pen=COLOR_GRAY,
                },
            },
        },
    }
end

function DrownCheckOverlay:onRenderFrame(dc, rect)
    DrownCheckOverlay.super.onRenderFrame(self, dc, rect)
    self.subviews.panel.visible = self.get_drowning() > 0
    if self.subviews.panel.visible then
        self.subviews.counter:setText(string.format("Suffocating: %5d/%5d!", self.get_drowning(), self.get_max_drown()))
    end
end


OVERLAY_WIDGETS = {
    drowncheck=DrownCheckOverlay,
}