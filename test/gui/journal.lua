local gui = require('gui')
local gui_journal = reqscript('gui/journal')

config = {
    target = 'gui/journal',
    mode = 'fortress'
}

local function simulate_input_keys(...)
    local keys = {...}
    for _,key in ipairs(keys) do
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), key)
    end

    gui_journal.view:onRender()
end

local function simulate_input_text(text)
    local screen = dfhack.gui.getCurViewscreen(true)

    for i = 1, #text do
        local charcode = string.byte(text:sub(i,i))
        local code_key = string.format('STRING_A%03d', charcode)

        gui.simulateInput(screen, { [code_key]=true })
    end

    gui_journal.view:onRender()
end

local function arrange_empty_journal(options)
    options = options or {}

    gui_journal.main()
    local journal = gui_journal.view
    journal.save_on_change = options.save_on_change or false

    local journal_window = journal.subviews.journal_window

    journal_window.frame.w = options.w or 100
    journal_window.frame.h = options.h or 50

    journal:updateLayout()

    local text_area = journal_window.subviews.text_area
    text_area.enable_cursor_blink = false
    text_area:setText('')

    return journal, text_area
end

local function read_rendered_text(text_area)
    local pen = nil
    local text = ''

    for y=0,text_area.frame_body.height do

        for x=0,text_area.frame_body.width do
            local g_x, g_y = text_area.frame_body:globalXY(x, y)
            pen = dfhack.screen.readTile(g_x, g_y)

            if pen == nil or pen.ch == nil or pen.ch == 0 then
                break
            else
                text = text .. string.char(pen.ch)
            end
        end

        text = text .. '\n'
    end

    return text:gsub("%s+$", "")
end

function test.load()
    local journal, text_area = arrange_empty_journal()

    expect.eq('dfhack/lua/journal', dfhack.gui.getCurFocus(true)[1])
    expect.eq(read_rendered_text(text_area), '')

    journal:dismiss()
end

function test.load_input_multiline_text()
    local journal, text_area = arrange_empty_journal()

    local text = table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Pellentesque dignissim volutpat orci, sed molestie metus elementum vel.',
        'Donec sit amet mattis ligula, ac vestibulum lorem.',
    }, '\n')
    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), text .. '_')

    journal:dismiss()
end

function test.wrap_text_to_available_width()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor est pellentesque ac.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac._',
    }, '\n'));

    journal:dismiss()
end

function test.submit_new_line()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('SELECT')
    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '',
        '_',
    }, '\n'));

    text_area:setCursor(58)
    journal:onRender()

    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'el',
        '_t.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        -- empty end lines are not rendered
    }, '\n'));

    text_area:setCursor(84)
    journal:onRender()

    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'el',
        'it.',
        '112: Sed consectetur,',
        -- wrapping changed
        '_urna sit amet aliquet egestas, ante nibh porttitor mi, ',
        'vitae rutrum eros metus nec libero.',
        -- empty end lines are not rendered
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_up_navigation()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor est pellentesque ac.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim _uismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim li_ero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor _i, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur_ urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_down_navigation()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor est pellentesque ac.',
    }, '\n')

    simulate_input_text(text)
    text_area:setCursor(11)
    journal:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem _psum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed c_nsectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellen_esque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac._',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin _ignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_left_navigation()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero_',
    }, '\n'));

    for i=1,6 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        '_ibero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec_',
        'libero.',
    }, '\n'));

    for i=1,105 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,60 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_right_navigation()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)
    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '6_: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,53 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing_',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        '_lit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,5 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,113 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    journal:dismiss()
end

function test.fast_rewind_words_right()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)
    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60:_Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem_ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,6 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing_',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112:_Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,17 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    journal:dismiss()
end


function test.fast_rewind_words_left()
    local journal, text_area = arrange_empty_journal({w=60})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('KEYBOARD_CURSOR_LEFT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        '_ibero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus _ec ',
        'libero.',
    }, '\n'));

    for i=1,8 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT_FAST')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        '_nte nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet _gestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,16 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT_FAST')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    journal:dismiss()
end
