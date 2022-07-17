-- The DFHack in-game command launcher
--@module=true

local gui = require('gui')
local helpdb = require('helpdb')
local json = require('json')
local utils = require('utils')
local widgets = require('gui.widgets')

local AUTOCOMPLETE_PANEL_WIDTH = 20
local EDIT_PANEL_HEIGHT = 4

local HISTORY_SIZE = 5000
local HISTORY_ID = 'gui/launcher'
local HISTORY_FILE = 'dfhack-config/launcher.history'
local CONSOLE_HISTORY_FILE = 'dfhack.history'
local FREQUENCY_FILE = 'dfhack-config/command_counts.json'

-- trims the history down to its maximum size, if needed
local function trim_history(hist, hist_set)
    if #hist <= HISTORY_SIZE then return end
    -- we can only ever go over by one, so no need to loop
    -- This is O(N) in the HISTORY_SIZE. if we need to make this more efficient,
    -- we can use a ring buffer.
    local line = table.remove(hist, 1)
    -- since all lines are guaranteed to be unique, we can just remove the hash
    -- from the set instead of, say, decrementing a counter
    hist_set[line] = nil
end

-- removes duplicate existing history lines and adds the given line to the front
local function add_history(hist, hist_set, line)
    if hist_set[line] then
        for i,v in ipairs(hist) do
            if v == line then
                table.remove(hist, i)
                break
            end
        end
    end
    table.insert(hist, line)
    hist_set[line] = true
    trim_history(hist, hist_set)
end

local function init_history()
    local hist, hist_set = {}, {}
    -- snarf the console history into our active history. it would be better if
    -- both the launcher and the console were using the same history object so
    -- the sharing would be "live", but we can address that later.
    for line in io.lines(CONSOLE_HISTORY_FILE) do
        add_history(hist, hist_set, line)
    end
    for _,line in ipairs(dfhack.getCommandHistory(HISTORY_ID, HISTORY_FILE)) do
        add_history(hist, hist_set, line)
    end
    return hist, hist_set
end

if not history then
    history, history_set = init_history()
end

local function get_frequency_data()
    local ok, data = pcall(json.decode_file, FREQUENCY_FILE)
    return ok and data or {}
end

local function get_first_word(text)
    return text:trim():split(' +')[1]
end

command_counts = command_counts or get_frequency_data()

local function record_command(line)
    add_history(history, history_set, line)
    local firstword = get_first_word(line)
    command_counts[firstword] = (command_counts[firstword] or 0) + 1
    json.encode_file(command_counts, FREQUENCY_FILE)
end

----------------------------------
-- AutocompletePanel
--
AutocompletePanel = defclass(AutocompletePanel, widgets.Panel)
AutocompletePanel.ATTRS{
    on_tab=DEFAULT_NIL,
    on_tab2=DEFAULT_NIL,
}

function AutocompletePanel:init()
    self:addviews{
        widgets.Label{
            frame={l=0, t=0},
            text='Autocomplete'
        },
        widgets.HotkeyLabel{
            frame={l=1, t=1},
            key='CHANGETAB',
            key_sep='/',
            label='',
            on_activate=self.on_tab},
        widgets.HotkeyLabel{
            frame={l=5, t=1},
            key='SEC_CHANGETAB',
            key_sep='',
            label='',
            on_activate=self.on_tab2},
        widgets.List{
            view_id='autocomplete_list',
            scroll_keys={},
            frame={l=0, t=3}},
    }
end

function AutocompletePanel:set_options(options, initially_selected)
    local list = self.subviews.autocomplete_list
    list:setChoices(options, 1)
    list.cursor_pen = initially_selected and COLOR_LIGHTCYAN or COLOR_CYAN
    self.first_advance = true
end

function AutocompletePanel:advance(delta)
    local list = self.subviews.autocomplete_list
    if self.first_advance then
        if list.cursor_pen == COLOR_CYAN and delta > 0 then
            delta = 0
        end
        self.first_advance = false
    end
    list.cursor_pen = COLOR_LIGHTCYAN -- enable highlight
    list:moveCursor(delta)
    local _, option = list:getSelected()
    return option and option.text or nil
end

----------------------------------
-- EditPanel
--
EditPanel = defclass(EditPanel, widgets.Panel)
EditPanel.ATTRS{
    on_change=DEFAULT_NIL,
    on_submit=DEFAULT_NIL,
    on_submit2=DEFAULT_NIL
}

function EditPanel:init()
    self:reset_history_idx()
    self.stack = {}

    self:addviews{
        widgets.EditField{
            view_id='editfield',
            frame={l=1, t=1, r=1},
            on_change=self.on_change,
            on_submit=self.on_submit,
            on_submit2=self.on_submit2},
        widgets.EditField{
            view_id='search',
            frame={l=3, t=3, r=1},
            key='CUSTOM_ALT_S',
            label_text='history search: ',
            on_change=self:callback('on_search_text'),
            on_unfocus=function()
                self:reset_history_idx()
                self.subviews.search:setText('')
                self.subviews.editfield:setFocus(true) end,
            on_submit=function()
                self.on_submit(self.subviews.editfield.text) end,
            on_submit2=function()
                self.on_submit2(self.subviews.editfield.text) end},
    }
end

function EditPanel:reset_history_idx()
    self.history_idx = #history + 1
end

-- set the edit field text and save the current text in the stack in case the
-- user wants it back
function EditPanel:set_text(text, push)
    local editfield = self.subviews.editfield
    if push and #editfield.text > 0 then
        table.insert(self.stack, editfield.text)
    end
    editfield:setText(text)
    self:reset_history_idx()
end

function EditPanel:pop_text()
    local editfield = self.subviews.editfield
    local text = self.stack[#self.stack]
    if text then
        self.stack[#self.stack] = nil
        editfield:setText(text)
    end
    return text
end

function EditPanel:move_history(delta)
    local history_idx = self.history_idx + delta
    if history_idx < 1 or history_idx > #history then
        return
    end
    self.history_idx = history_idx
    local text = history[history_idx]
    self.subviews.editfield:setText(text)
    self.on_change(text)
end

function EditPanel:on_search_text(search_str)
    for history_idx = math.min(self.history_idx, #history), 1, -1 do
        if history[history_idx]:find(search_str, 1, true) then
            self:move_history(history_idx - self.history_idx)
            return
        end
    end
    -- no matches. restart at top of history on next search
    self:reset_history_idx()
end

function EditPanel:onInput(keys)
    if EditPanel.super.onInput(self, keys) then return true end

    if keys.STANDARDSCROLL_UP then
        self:move_history(-1)
        return true
    elseif keys.STANDARDSCROLL_DOWN then
        self:move_history(1)
        return true
    elseif keys.CUSTOM_ALT_S then
        -- search to the next match with the current search string
        -- only reaches here if the search field is already active
        self.history_idx = math.max(1, self.history_idx - 1)
        self:on_search_text(self.subviews.search.text)
        return true
    elseif keys.A_CARE_MOVE_W then -- Alt-Left
        local text = self:pop_text()
        if text then
            self.on_change(text)
        end
        return true
    end
end

----------------------------------
-- HelpPanel
--
HelpPanel = defclass(HelpPanel, widgets.Panel)

local DEFAULT_HELP_TEXT = [[Welcome to DFHack!

Type a command to see it's help text here. Hit ENTER
to run the command, or Shift-ENTER to run the
command and close this dialog. The dialog also
closes automatically if you run a command that shows
a new GUI screen.

Not sure what to do? Run the "help" command to get
started!

To see help for this command launcher, type
"launcher" and autocomplete to "gui/launcher" with
the TAB key.]]

function HelpPanel:init()
    self.cur_entry = ""

    self:addviews{
        widgets.WrappedLabel{
            view_id='help_label',
            frame={l=0, t=0},
            auto_height=false,
            scroll_keys={
                A_MOVE_N_DOWN=-1, -- Ctrl-Up
                A_MOVE_S_DOWN=1,  -- Ctrl-Down
                STANDARDSCROLL_PAGEUP='-page',
                STANDARDSCROLL_PAGEDOWN='+page',
            },
            text_to_wrap=DEFAULT_HELP_TEXT}
    }
end

function HelpPanel:set_help(help_text)
    local label = self.subviews.help_label
    label.text_to_wrap = help_text
    label:postComputeFrame()
    label:updateLayout() -- to update the scroll arrows after rewrapping text
end

function HelpPanel:set_entry(entry_name)
    if not helpdb.is_entry(entry_name) then
        entry_name = ""
    end
    if #entry_name == 0 or entry_name == self.cur_entry then
        return
    end
    self.cur_entry = entry_name
    self:set_help(helpdb.get_entry_long_help(entry_name))
end

function HelpPanel:onInput(keys)
    if HelpPanel.super.onInput(self, keys) then
        return true
    elseif keys._MOUSE_L and self:getMousePos() then
        local label = self.subviews.help_label
        label:scroll(label.frame_body.height)
        return true
    elseif keys._MOUSE_R and self:getMousePos() then
        local label = self.subviews.help_label
        label:scroll(-label.frame_body.height)
        return true
    end
end

----------------------------------
-- LauncherUI
--
LauncherUI = defclass(LauncherUI, gui.FramedScreen)
LauncherUI.ATTRS{
    frame_title='DFHack Launcher',
    frame_style = gui.GREY_LINE_FRAME,
    focus_path='launcher',
    parent_focus=DEFAULT_NIL,
}

function LauncherUI:init()
    self.firstword = ""

    self:addviews{
        AutocompletePanel{
            view_id='autocomplete',
            frame={t=0, r=0, w=AUTOCOMPLETE_PANEL_WIDTH},
            on_tab=self:callback('do_autocomplete', 1),
            on_tab2=self:callback('do_autocomplete', -1)},
        EditPanel{
            view_id='edit',
            frame={t=0, l=0, r=AUTOCOMPLETE_PANEL_WIDTH+2, h=EDIT_PANEL_HEIGHT},
            on_change=self:callback('on_edit_input'),
            on_submit=self:callback('run_command', true),
            on_submit2=self:callback('run_command', false)},
        HelpPanel{
            view_id='help',
            frame={t=EDIT_PANEL_HEIGHT+2, l=0, r=AUTOCOMPLETE_PANEL_WIDTH+2}},
    }
end

function LauncherUI:update_help(text, firstword)
    local firstword = firstword or get_first_word(text)
    if firstword == self.firstword then
        return
    end
    self.firstword = firstword
    self.subviews.help:set_entry(firstword)
end

local function extract_entry(entries, firstword)
    for i,v in ipairs(entries) do
        if v == firstword then
            table.remove(entries, i)
            return true
        end
    end
end

function LauncherUI:update_autocomplete(text, firstword)
    local entries = helpdb.search_entries(
        {str=firstword},
        {str={'modtools/', 'devel/'}})
    -- if firstword is in the list, extract it so we can add it to the top later
    local found = extract_entry(entries, firstword)
    -- remember starting position of each entry so we can sort stably
    local indices = utils.invert(entries)
    local stable_sort_by_frequency = function(a, b)
        if (command_counts[a] or 0) > (command_counts[b] or 0) then return true
        elseif (command_counts[a] or 0) == (command_counts[b] or 0) then
            return indices[a] < indices[b]
        end
        return false
    end
    table.sort(entries, stable_sort_by_frequency)
    if found then
        table.insert(entries, 1, firstword)
    end
    self.subviews.autocomplete:set_options(entries, found)
end

function LauncherUI:on_edit_input(text)
    self.input_is_worth_saving = true
    local firstword = get_first_word(text)
    self:update_help(text, firstword)
    self:update_autocomplete(text, firstword)
end

function LauncherUI:do_autocomplete(delta)
    local text = self.subviews.autocomplete:advance(delta)
    if not text then return end
    self.subviews.edit:set_text(text, self.input_is_worth_saving)
    self:update_help(text)
    self.input_is_worth_saving = false
end

local function launch(kwargs)
    view = LauncherUI{parent_focus=dfhack.gui.getCurFocus(true)}
    view:show()
    view:on_edit_input('')
    if kwargs.initial_help then
        view.subviews.help:set_help(kwargs.initial_help)
    end
    if kwargs.command then
        view.subviews.edit:set_text(kwargs.command)
        view:on_edit_input(kwargs.command)
    end
end

function LauncherUI:onDismiss()
    view = nil
end

function LauncherUI:run_command(reappear, text)
    text = text:trim()
    if #text == 0 then return end
    self:dismiss()
    dfhack.addCommandToHistory(HISTORY_ID, HISTORY_FILE, text)
    record_command(text)
    local output = dfhack.run_command_silent(text)
    -- if we displayed a new dfhack screen, don't come back up even if reappear
    -- is true. otherwise, the user can't interact with the new screen. if we're
    -- not reappearing with the output, print the output to the console.
    local parent_focus = dfhack.gui.getCurFocus(true)
    if not reappear or (parent_focus:startswith('dfhack/') and
                        parent_focus ~= self.parent_focus) then
        if #output > 0 then
            print('Output from command run from gui/launcher:')
            print('> '..text)
            print(output)
        end
        return
    end
    -- reappear and show the command output
    local initial_help = ('> %s\n\n%s'):format(text, output)
    launch({initial_help=initial_help})
end

function LauncherUI:getWantedFrameSize()
    local width, height = dfhack.screen.getWindowSize()
    return math.max(76, width-10), math.max(24, height-10)
end

local H_SPLIT_PEN = dfhack.pen.parse{ch=205, fg=COLOR_GREY, bg=COLOR_BLACK}
local V_SPLIT_PEN = dfhack.pen.parse{ch=186, fg=COLOR_GREY, bg=COLOR_BLACK}
local TOP_SPLIT_PEN = dfhack.pen.parse{ch=203, fg=COLOR_GREY, bg=COLOR_BLACK}
local BOTTOM_SPLIT_PEN = dfhack.pen.parse{ch=202, fg=COLOR_GREY, bg=COLOR_BLACK}
local LEFT_SPLIT_PEN = dfhack.pen.parse{ch=204, fg=COLOR_GREY, bg=COLOR_BLACK}
local RIGHT_SPLIT_PEN = dfhack.pen.parse{ch=185, fg=COLOR_GREY, bg=COLOR_BLACK}

-- paint autocomplete panel border
local function paint_vertical_border(rect)
    local x = rect.x2 - (AUTOCOMPLETE_PANEL_WIDTH + 2)
    local y1, y2 = rect.y1, rect.y2
    dfhack.screen.paintTile(TOP_SPLIT_PEN, x, y1)
    dfhack.screen.paintTile(BOTTOM_SPLIT_PEN, x, y2)
    for y=y1+1,y2-1 do
        dfhack.screen.paintTile(V_SPLIT_PEN, x, y)
    end
end

-- paint border between edit area and help area
local function paint_horizontal_border(rect)
    local panel_height = EDIT_PANEL_HEIGHT + 1
    local x1, x2 = rect.x1, rect.x2
    local v_border_x = x2 - (AUTOCOMPLETE_PANEL_WIDTH + 2)
    local y = rect.y1 + panel_height
    dfhack.screen.paintTile(LEFT_SPLIT_PEN, x1, y)
    dfhack.screen.paintTile(RIGHT_SPLIT_PEN, v_border_x, y)
    for x=x1+1,v_border_x-1 do
        dfhack.screen.paintTile(H_SPLIT_PEN, x, y)
    end
end

function LauncherUI:onRenderFrame(dc, rect)
    LauncherUI.super.onRenderFrame(self, dc, rect)
    paint_vertical_border(rect)
    paint_horizontal_border(rect)
end

function LauncherUI:onInput(keys)
    if self:inputToSubviews(keys) then
        return true
    elseif keys.LEAVESCREEN then
        self:dismiss()
        return true
    elseif keys.CUSTOM_CTRL_C then
        self.subviews.edit:set_text('', self.input_is_worth_saving)
    end
end

if dfhack_flags.module then
    return
end

if view then
    -- hitting the launcher hotkey while it is open should close the dialog
    view:dismiss()
else
    local args = {...}
    launch({command=table.concat(args, ' ')})
end
