--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local to_pen = dfhack.pen.parse

local view_sheets = df.global.game.main_interface.view_sheets

local active_tab = {
    'Labor',
    'Combat',
    'Social',
    'Other Skills',
}

local function get_active_tab()
    return active_tab[view_sheets.unit_skill_active_tab]
end

local function get_skill(id)
    return view_sheets.unit_skill[id], view_sheets.unit_skill_val[id], view_sheets.unit_skill_val_w_rust[id]
end

SkillProgressOverlay=defclass(SkillProgressOverlay, overlay.OverlayWidget)
SkillProgressOverlay.ATTRS {
    desc="Display progress bars for learning skills!",
    default_pos={x=-44,y=20},
    default_enabled=true,
    viewscreens= {
        'dwarfmode/ViewSheets/UNIT/Skills/Labor',
        'dwarfmode/ViewSheets/UNIT/Skills/Combat',
        'dwarfmode/ViewSheets/UNIT/Skills/Social',
        'dwarfmode/ViewSheets/UNIT/Skills/Other',

        'dungeonmode/ViewSheets/UNIT/Skills/Labor',
        'dungeonmode/ViewSheets/UNIT/Skills/Combat',
        'dungeonmode/ViewSheets/UNIT/Skills/Social',
        'dungeonmode/ViewSheets/UNIT/Skills/Other',
    },
    frame={w=8, h=66},
}

function SkillProgressOverlay:init()
    self.dirty = true

    self:addviews{
        widgets.Label{
            view_id='annotations',
            frame={t=0, l=0},
            text='',
            text_pen=COLOR_GREEN,
        }
    }
end

function SkillProgressOverlay:preUpdateLayout(parent_rect)
    return
    -- local list_height = parent_rect.height - 17
    -- self.frame.w = parent_rect.width - 85
    -- self.frame.h = list_height
    -- local margin = (parent_rect.width - 114) // 3
    -- self.subviews.annotations.frame.l = margin
end

function SkillProgressOverlay:onRenderFrame(dc, rect)
    local margin = self.subviews.annotations.frame.l
    local num_elems = self.frame.h // 3
    local max_elem = math.min(#view_sheets.unit_skill-1,
        view_sheets.scroll_position_unit_skill+num_elems-1)

    local annotations = {}
    for idx = view_sheets.scroll_position_unit_skill, max_elem do
        table.insert(annotations, NEWLINE)
        table.insert(annotations, {text='[', pen=COLOR_GRAY})
        local skill, value, rusted = get_skill(idx)
        if true then
            table.insert(annotations, tostring(rusted))
        end
        table.insert(annotations, {text=']', pen=COLOR_GRAY})
        table.insert(annotations, NEWLINE)
        table.insert(annotations, NEWLINE)
    end
    self.subviews.annotations:setText(annotations)
    self.subviews.annotations:updateLayout()

    SkillProgressOverlay.super.onRenderFrame(self, dc, rect)
end

OVERLAY_WIDGETS = {
    skillprogress=SkillProgressOverlay,
}