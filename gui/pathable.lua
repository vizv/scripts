-- View whether tiles on the map can be pathed to.
--@module=true

local gui = require('gui')
local plugin = require('plugins.pathable')
local widgets = require('gui.widgets')

-- ------------------------------
-- Pathable

Pathable = defclass(Pathable, widgets.Window)
Pathable.ATTRS {
    frame_title='Pathability Viewer',
    frame={t=18, r=2, w=30, h=9},
}

function Pathable:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id='draw',
            frame={t=0, l=0},
            key='CUSTOM_CTRL_D',
            label='Draw:',
            label_width=12,
            initial_option=true,
        },
        widgets.ToggleHotkeyLabel{
            view_id='lock',
            frame={t=1, l=0},
            key='CUSTOM_CTRL_T',
            label='Lock target:',
            initial_option=false,
        },
        widgets.ToggleHotkeyLabel{
            view_id='show',
            frame={t=2, l=0},
            key='CUSTOM_CTRL_U',
            label='Show hidden:',
            initial_option=false,
        },
        widgets.Label{
            frame={t=4, l=0},
            text='Pathability group:',
        },
        widgets.Label{
            view_id='group',
            frame={t=4, l=19, h=1},
            text='',
            text_pen=COLOR_LIGHTCYAN,
            auto_height=false,
        },
    }
end

function Pathable:onRenderBody()
    local target = self.subviews.lock:getOptionValue() and
            self.saved_target or dfhack.gui.getMousePos()
    self.saved_target = target

    local group = self.subviews.group
    local show = self.subviews.show:getOptionValue()

    if not target then
        group:setText('')
    elseif not show and not dfhack.maps.isTileVisible(target) then
        group:setText('Hidden')
    else
        local walk_group = dfhack.maps.getWalkableGroup(target)
        group:setText(walk_group == 0 and 'None' or tostring(walk_group))

        if self.subviews.draw:getOptionValue() then
            plugin.paintScreenPathable(target, show)
        end
    end
end

-- ------------------------------
-- PathableScreen

PathableScreen = defclass(PathableScreen, gui.ZScreen)
PathableScreen.ATTRS {
    focus_path='pathable',
    pass_movement_keys=true,
}

function PathableScreen:init()
    self:addviews{Pathable{}}
end

function PathableScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('gui/pathable requires a map to be loaded')
end

view = view and view:raise() or PathableScreen{}:show()
