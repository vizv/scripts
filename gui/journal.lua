-- Fort journal with a multi-line text editor
--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local utils = require 'utils'
local json = require 'json'
local text_editor = reqscript('internal/journal/text_editor')

local RESIZE_MIN = {w=32, h=10}

JOURNAL_PERSIST_KEY = 'journal'

journal_config = journal_config or json.open('dfhack-config/journal.json')

JournalWindow = defclass(JournalWindow, widgets.Window)
JournalWindow.ATTRS {
    frame_title='DF Journal',
    resizable=true,
    resize_min=RESIZE_MIN,
    frame_inset=0,
    init_text=DEFAULT_NIL,
    init_cursor=1,
    on_text_change=DEFAULT_NIL,
    on_cursor_change=DEFAULT_NIL,
    on_layout_change=DEFAULT_NIL
}

function JournalWindow:loadConfig()
    local window_frame = copyall(journal_config.data.frame or {})
    local table_of_contents = copyall(journal_config.data.toc or {
        width=20,
        visible=false
    })

    self.frame = self:sanitizeFrame(window_frame)

    local toc_panel = self.subviews.table_of_contents_panel
    toc_panel.frame.w = table_of_contents.width
    toc_panel.visible = table_of_contents.visible
end

function JournalWindow:init()
    self:addviews({
        widgets.Panel{
            frame={t=1, r=0,h=1},
            subviews={
                widgets.TextButton{
                    frame={l=0,w=13},
                    label='ToC',
                    key='CUSTOM_CTRL_T',
                    on_activate=self:callback('toggleToCVisibililty'),
                    enabled=true,
                },
            }
        },
        widgets.Panel{
            view_id='table_of_contents_panel',
            frame_title='Table of contents',
            frame_style = gui.FRAME_INTERIOR,

            resizable=true,

            frame_background = gui.CLEAR_PEN,

            resize_min={w=20},
            resize_anchors={r=true},
            frame={l=0, t=3, b=0, w=20},
            visible=false,
            on_resize_begin=self:callback('onPanelResizeBegin'),
            on_resize_end=self:callback('onPanelResizeEnd'),
            subviews={
                widgets.List{
                    frame={l=1,t=1},
                    view_id='table_of_contents',
                    choices={},
                    on_submit=self:callback('onTableOfContentsSubmit')
                },
            }
        },
        text_editor.TextEditor{
            view_id='journal_editor',
            frame={t=3, b=0, l=31, r=0},
            resize_min={w=30, h=10},
            frame_inset={r=0},
            init_text=self.init_text,
            init_cursor=self.init_cursor,
            on_text_change=function(text) self:onTextChange(text) end,
            on_cursor_change=function(cursor)
                if self.on_cursor_change ~= nil then
                    self.on_cursor_change(cursor)
                end
            end
        },
    })

    self:loadConfig()
    self:reloadTableOfContents(self.init_text)
end

function JournalWindow:toggleToCVisibililty()
    self.subviews.table_of_contents_panel.visible =
        not self.subviews.table_of_contents_panel.visible

    self:reloadTableOfContents(self.subviews.journal_editor:getText())
    self:updateLayout()
end

function JournalWindow:sanitizeFrame(frame)
    local w, h = dfhack.screen.getWindowSize()
    local min = RESIZE_MIN
    if frame.t and h - frame.t - (frame.b or 0) < min.h then
        frame.t = h - min.h
        frame.b = 0
    end
    if frame.b and h - frame.b - (frame.t or 0) < min.h then
        frame.b = h - min.h
        frame.t = 0
    end
    if frame.l and w - frame.l - (frame.r or 0) < min.w then
        frame.l = w - min.w
        frame.r = 0
    end
    if frame.r and w - frame.r - (frame.l or 0) < min.w then
        frame.r = w - min.w
        frame.l = 0
    end
    return frame
end

function JournalWindow:saveConfig()
    local toc_panel = self.subviews.table_of_contents_panel

    utils.assign(journal_config.data, {
        frame = self.frame,
        toc = {
            width = toc_panel.frame.w,
            visible = toc_panel.visible
        }
    })
    journal_config:write()
end

function JournalWindow:onPanelResizeBegin()
    self.resizing_panels = true
end

function JournalWindow:onPanelResizeEnd()
    self.resizing_panels = false
    self:esnurePanelsRelSize()

    self:updateLayout()
end

function JournalWindow:onRenderBody(painter)
    if self.resizing_panels then
        self:esnurePanelsRelSize()
        self:updateLayout()
    end

    return JournalWindow.super.onRenderBody(painter)
end

function JournalWindow:esnurePanelsRelSize()
    local toc = self.subviews.table_of_contents_panel
    local editor = self.subviews.journal_editor

    toc.frame.w = math.min(
        math.max(toc.frame.w, toc.resize_min.w),
        self.frame.w - editor.resize_min.w
    )
    editor.frame.l = toc.visible and (toc.frame.w + 1) or 1
end

function JournalWindow:preUpdateLayout()
    self:esnurePanelsRelSize()
end

function JournalWindow:postUpdateLayout()
    self:saveConfig()
end

function JournalWindow:onTextChange(text)
    self:reloadTableOfContents(text)
    if self.on_text_change ~= nil then
        self.on_text_change(text)
    end
end

function JournalWindow:reloadTableOfContents(text)
    if not self.subviews.table_of_contents_panel.visible then
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

function JournalWindow:onTableOfContentsSubmit(ind, choice)
    self.subviews.journal_editor:setCursor(choice.line_cursor)
    self.subviews.journal_editor:scrollToCursor(choice.line_cursor)
end

JournalScreen = defclass(JournalScreen, gui.ZScreen)
JournalScreen.ATTRS {
    focus_path='journal',
    save_on_change=true,
    save_prefix=''
}

function JournalScreen:init(options)
    local context = self:loadContext()

    self:addviews{
        JournalWindow{
            view_id='journal_window',
            frame={w=65, h=45},
            resize_min={w=50, h=20},
            resizable=true,
            frame_inset=0,

            init_text=context.text[1],
            init_cursor=context.cursor[1],

            on_text_change=self:callback('saveContext'),
            on_cursor_change=self:callback('saveContext')
        },
    }
end

function JournalScreen:loadContext()
    local site_data = dfhack.persistent.getSiteData(
        self.save_prefix .. JOURNAL_PERSIST_KEY
    ) or {}
    site_data.text = site_data.text or {''}
    site_data.cursor = site_data.cursor or {#site_data.text[1] + 1}

    return site_data
end

function JournalScreen:onTextChange(text)
    self:saveContext(text)
end

function JournalScreen:saveContext()
    if self.save_on_change and dfhack.isWorldLoaded() then
        local text = self.subviews.journal_editor:getText()
        local cursor = self.subviews.journal_editor:getCursor()

        dfhack.persistent.saveSiteData(
            self.save_prefix .. JOURNAL_PERSIST_KEY,
            {text={text}, cursor={cursor}}
        )
    end
end

function JournalScreen:onDismiss()
    view = nil
end

function main(options)
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('journal requires a fortress map to be loaded')
    end

    view = view and view:raise() or JournalScreen{
        save_prefix=options and options.save_prefix or ''
    }:show()
end

if not dfhack_flags.module then
    main()
end
