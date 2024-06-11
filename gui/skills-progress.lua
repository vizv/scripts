--@ module=true

local utils = require("utils")
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
    return utils.binsearch(
        df.unit.find(view_sheets.viewing_unid[0]).status.current_soul.skills,
        view_sheets.unit_skill[id],
        "id"
    )
end

SkillProgressOverlay=defclass(SkillProgressOverlay, overlay.OverlayWidget)
SkillProgressOverlay.ATTRS {
    desc="Display progress bars for learning skills!",
    default_pos={x=-43,y=20},
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
    frame={w=16, h=66},
}

function SkillProgressOverlay:init()
    self.dirty = true

    self:addviews{
        widgets.Label{
            view_id='annotations',
            frame={t=0, l=0},
            text='',
            text_pen=COLOR_GRAY,
        }
    }
end

function SkillProgressOverlay:onRenderFrame(dc, rect)
    local margin = self.subviews.annotations.frame.l
    local num_elems = self.frame.h // 3
    local max_elem = math.min(#view_sheets.unit_skill-1,
        view_sheets.scroll_position_unit_skill+num_elems-1)

    local annotations = {}
    for idx = view_sheets.scroll_position_unit_skill, max_elem do
        local skill = get_skill(idx)
        local rating = df.skill_rating.attrs[math.max(0, math.min(skill.rating, 19))]
        local level = skill.rating

        local level_color = COLOR_GRAY

        if level == df.skill_rating.Legendary then
            level_color = COLOR_WHITE
        end

        if level > df.skill_rating.Legendary then
            level_color = COLOR_LIGHTCYAN
        end

        if skill.demotion_counter > 0 then
            level_color = COLOR_YELLOW
        end

        if level - skill.demotion_counter <= 0 then
            level_color = COLOR_BROWN
        end

        table.insert(annotations, NEWLINE)

        table.insert(annotations, { text=string.format(
                "L%d",
                level - skill.demotion_counter
            ),
            width = 3,
            pen = level_color }
        )
        table.insert(annotations, " -- ")

        table.insert(annotations, { text=string.format(
                "%4d/%4d",
                skill.experience,
                rating.xp_threshold
            ),
            pen = COLOR_GREEN,
            width = 9,
            rjustify=true, }
        )

        table.insert(annotations, NEWLINE)
        local percentage = skill.experience / rating.xp_threshold
        local barstop = math.floor((self.frame.w * percentage) + 0.5)
        for idx = 0, self.frame.w-1 do
            local color = COLOR_LIGHTCYAN
            local char = 219
            -- start with the filled middle progress bar
            local tex_idx = 1
            -- at the beginning, use the left rounded corner
            if idx == 0 then
                tex_idx = 0
            end
            -- at the beginning, use the right rounded corner
            if idx == self.frame.w-1 then
                tex_idx = 2
            end
            if idx >= barstop then
                -- offset it to the hollow graphic
                tex_idx = tex_idx + 3
                color = COLOR_DARKGRAY
                char = 177
            end
            table.insert(annotations, { width = 1, tile={tile=df.global.init.load_bar_texpos[tex_idx], ch=char, fg=color}})
        end

        table.insert(annotations, NEWLINE)
    end
    self.subviews.annotations:setText(annotations)
    self.subviews.annotations:updateLayout()

    SkillProgressOverlay.super.onRenderFrame(self, dc, rect)
end

OVERLAY_WIDGETS = {
    skillprogress=SkillProgressOverlay,
}
