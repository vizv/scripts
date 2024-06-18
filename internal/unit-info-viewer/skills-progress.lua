--@ module=true

local utils = require("utils")
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local view_sheets = df.global.game.main_interface.view_sheets

local function get_skill(id)
    return utils.binsearch(
        df.unit.find(view_sheets.viewing_unid[0]).status.current_soul.skills,
        view_sheets.unit_skill[id],
        "id"
    )
end

SkillProgressOverlay=defclass(SkillProgressOverlay, overlay.OverlayWidget)
SkillProgressOverlay.ATTRS {
    desc="Display progress bars for learning skills on unit viewsheets.",
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
    frame={w=54, h=67},
}

function SkillProgressOverlay:init()
    self.progress_bar = true
    self.display_experience = true

    self:addviews{
        widgets.Label{
            view_id='annotations',
            frame={t=0, r=0, w=16},
            text='',
            text_pen=COLOR_GRAY,
        },
        widgets.ToggleHotkeyLabel{
            frame={b=1, l=2, w=25},
            label='Progress Bar',
            key='CUSTOM_CTRL_B',
            options={
                {label='No', value=false, pen=COLOR_WHITE},
                {label='Yes', value=true, pen=COLOR_YELLOW},
            },
            view_id='toggle_progress',
            on_change=function(val) self.progress_bar = val end,
        },
        widgets.ToggleHotkeyLabel{
            frame={b=1, l=28, w=25},
            label='Experience  ',
            key='CUSTOM_CTRL_E',
            options={
                {label='No', value=false, pen=COLOR_WHITE},
                {label='Yes', value=true, pen=COLOR_YELLOW},
            },
            view_id='toggle_experience',
            on_change=function(val) self.display_experience = val end,
        },
    }
end

-- Use render to set On/Off dynamically for each unit
function SkillProgressOverlay:render(dc)
    local unit = dfhack.gui.getSelectedUnit(true)

    if unit then
        self.subviews.toggle_progress:setOption(self.progress_bar)
        self.subviews.toggle_experience:setOption(self.display_experience)
    end

    SkillProgressOverlay.super.render(self, dc)
end

function SkillProgressOverlay:onRenderFrame(dc, rect)
    local margin = self.subviews.annotations.frame.w
    local num_elems = self.frame.h // 3
    local max_elem = math.min(#view_sheets.unit_skill-1,
        view_sheets.scroll_position_unit_skill+num_elems-1)

    local annotations = {}
    for idx = view_sheets.scroll_position_unit_skill, max_elem do
        local skill = get_skill(idx)
        local rating = df.skill_rating.attrs[math.max(0, math.min(skill.rating, 19))]
        if self.display_experience then
            if not self.progress_bar then
                table.insert(annotations, NEWLINE)
            end
            local level_color = COLOR_GRAY
            local level_chara = "Lv"

            level_color = COLOR_WHITE
            if skill.rating == df.skill_rating.Legendary then
                level_color = COLOR_CYAN
            end

            if skill.rating > df.skill_rating.Legendary then
                level_color = COLOR_LIGHTCYAN
            end

            if skill.demotion_counter > 0 then
                level_color = COLOR_YELLOW
            end

            if skill.rating - skill.demotion_counter < 0 then
                level_color = COLOR_BROWN
            end

            if skill.rating - skill.demotion_counter >= 100 then
                level_chara = "L"
            end

            table.insert(annotations, { text=tostring(
                    level_chara .. skill.rating - skill.demotion_counter
                ),
                width = 7,
                pen = level_color }
            )

            table.insert(annotations, { text=string.format(
                    "%4d/%4d",
                    skill.experience,
                    rating.xp_threshold
                ),
                pen = level_color,
                width = 9,
                rjustify=true, }
            )
        end

        -- 3rd line (last)

        -- Progress Bar
        if self.progress_bar then
            table.insert(annotations, NEWLINE)
            local percentage = skill.experience / rating.xp_threshold
            local barstop = math.floor((margin * percentage) + 0.5)
            for idx = 0, margin-1 do
                local color = COLOR_LIGHTCYAN
                local char = 219
                -- start with the filled middle progress bar
                local tex_idx = 1
                -- at the beginning, use the left rounded corner
                if idx == 0 then
                    tex_idx = 0
                end
                -- at the beginning, use the right rounded corner
                if idx == margin-1 then
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
        end
        -- End!
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
