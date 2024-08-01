--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'

local INVISIBLE_FRAME = {
    frame_pen=gui.CLEAR_PEN,
    signature_pen=false,
}

TableOfContents = defclass(TableOfContents, widgets.Panel)
TableOfContents.ATTRS {
    frame_style=INVISIBLE_FRAME,
    frame_background = gui.CLEAR_PEN,
    on_submit=DEFAULT_NIL
}

function TableOfContents:init()
    self:addviews({
        widgets.List{
            frame={l=1, t=0, r=1, b=0},
            view_id='table_of_contents',
            choices={},
            on_submit=self.on_submit
        },
    })
end

function TableOfContents:cursorSection(cursor)
    local section_ind = nil

    for ind, choice in ipairs(self.subviews.table_of_contents.choices) do
        if choice.line_cursor > cursor then
            break
        end
        section_ind = ind
    end

    return section_ind, self.subviews.table_of_contents.choices[section_ind]
end

function TableOfContents:setSelectedSection(section_index)
    local curr_sel = self.subviews.table_of_contents:getSelected()
    if curr_sel ~= section_index then
        self.subviews.table_of_contents:setSelected(section_index)
    end
end

function TableOfContents:submit()
    return self.subviews.table_of_contents:submit()
end

function TableOfContents:reload(text)
    if not self.visible then
        return
    end

    local sections = {}

    local line_cursor = 1
    for line in text:gmatch("[^\n]*") do
        local header, section = line:match("^(#+)%s(.+)")
        if header ~= nil then
            table.insert(sections, {
                line_cursor=line_cursor,
                text=string.rep(" ", #header - 1) .. section,
            })
        end

        line_cursor = line_cursor + #line + 1
    end

    self.subviews.table_of_contents:setChoices(sections)
end
