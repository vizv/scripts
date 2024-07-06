local gui = require('gui')
local journal = reqscript('gui/journal')

config = {
    target = 'gui/journal',
    mode = 'fortress'
}

local function simulate_input_keys(...)
    local keys = {...}
    for _,key in ipairs(keys) do
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), key)
    end
end

local function simulate_input_text(text)
    for i = 1, #text do
        local charcode = string.byte(text:sub(i,i))
        local code_key = string.format('STRING_A%03d', charcode)

        local keys = {
            _STRING=charcode,
            [code_key]=true
        }
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), keys)
    end

    journal.view:onRender()
end

local function arrange_empty_journal(options)
    options = options or {}

    journal.main({save_on_change=false})
    journal.view.save_on_change = options.save_on_change or false

    local text_area = journal.view.subviews.journal_editor.subviews.text_area
    text_area.enable_cursor_blink = false
    text_area:setText('')

    return journal.view, text_area
end

local function read_rendered_text(text_area)
    printall(text_area.frame_body)
    local pen = nil
    local text = ''

    for y=0,text_area.frame_body.height - 1 do

        for x=0,text_area.frame_body.height - 1 do
            local g_x, g_y = text_area.frame_body:globalXY(x, y)
            pen = dfhack.screen.readTile(g_x, g_y)

            if pen == nil or pen.ch == nil or pen.ch == 0 then
                break
            else
                text = text .. string.char(pen.ch)
            end
        end

        local g_x, g_y = text_area.frame_body:globalXY(0, y + 1)
        pen = dfhack.screen.readTile(g_x, g_y)
        if pen == nil or pen.ch == nil or pen.ch == 0 then
            break
        end

        text = text .. '\n'
    end

    return text
end

function test.journal_load()
    local journal, text_area = arrange_empty_journal()

    expect.eq('dfhack/lua/journal', dfhack.gui.getCurFocus(true)[1])
    expect.eq(read_rendered_text(text_area), '')

    journal:dismiss()
end

function test.journal_load_input_multiline_text()
    local journal, text_area = arrange_empty_journal()

    local text = 'text without wrapping\nbut with many lines visible\nat once'
    simulate_input_text(text)

    expect.eq('dfhack/lua/journal', dfhack.gui.getCurFocus(true)[1])
    expect.eq(read_rendered_text(text_area), text)

    journal:dismiss()
end
