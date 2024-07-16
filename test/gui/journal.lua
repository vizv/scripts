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

local function simulate_mouse_click(text_area, x, y)
    local g_x, g_y = text_area.frame_body:globalXY(x, y)
    df.global.gps.mouse_x = g_x
    df.global.gps.mouse_y = g_y

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), {
        _MOUSE_L=true,
        _MOUSE_L_DOWN=true,
    })
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), '_MOUSE_L_DOWN')

    gui_journal.view:onRender()
end

local function simulate_mouse_drag(text_area, x_from, y_from, x_to, y_to)
    local g_x_from, g_y_from = text_area.frame_body:globalXY(x_from, y_from)
    local g_x_to, g_y_to = text_area.frame_body:globalXY(x_to, y_to)

    df.global.gps.mouse_x = g_x_from
    df.global.gps.mouse_y = g_y_from


    gui.simulateInput(dfhack.gui.getCurViewscreen(true), {
        _MOUSE_L=true,
        _MOUSE_L_DOWN=true,
    })
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), '_MOUSE_L_DOWN')

    df.global.gps.mouse_x = g_x_to
    df.global.gps.mouse_y = g_y_to
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), '_MOUSE_L_DOWN')

    gui_journal.view:onRender()
end

local function arrange_empty_journal(options)
    options = options or {}

    gui_journal.main()
    local journal = gui_journal.view
    journal.save_on_change = options.save_on_change or false

    local journal_window = journal.subviews.journal_window

    journal_window.frame = {
        l = 1,
        t = 1,
        -- adjust expected size to text_area
        w = (options.w or 100) + 6,
        h = (options.h or 50) + 5,
    }

    journal:updateLayout()

    local text_area = journal_window.subviews.text_area
    text_area.enable_cursor_blink = false
    text_area:setText('')

    journal:onRender()

    return journal, text_area
end

local function read_rendered_text(text_area)
    local pen = nil
    local text = ''

    for y=0,text_area.frame_body.height do

        for x=0,text_area.frame_body.width do
            local g_x, g_y = text_area.frame_body:globalXY(x, y)
            pen = dfhack.screen.readTile(g_x, g_y)

            if pen == nil or pen.ch == nil or pen.ch == 0 or pen.fg == 0 then
                break
            else
                text = text .. string.char(pen.ch)
            end
        end

        text = text .. '\n'
    end

    return text:gsub("\n+$", "")
end

local function read_selected_text(text_area)
    local pen = nil
    local text = ''

    for y=0,text_area.frame_body.height do
        local has_sel = false

        for x=0,text_area.frame_body.width do
            local g_x, g_y = text_area.frame_body:globalXY(x, y)
            pen = dfhack.screen.readTile(g_x, g_y)

            local pen_char = string.char(pen.ch)
            if pen == nil or pen.ch == nil or pen.ch == 0 then
                break
            elseif pen.bg == COLOR_CYAN then
                has_sel = true
                text = text .. pen_char
            end
        end
        if has_sel then
            text = text .. '\n'
        end
    end

    return text:gsub("\n+$", "")
end

function test.load()
    local journal, text_area = arrange_empty_journal()

    expect.eq('dfhack/lua/journal', dfhack.gui.getCurFocus(true)[1])
    expect.eq(read_rendered_text(text_area), '_')

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
    local journal, text_area = arrange_empty_journal({w=55})

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
    local journal, text_area = arrange_empty_journal({w=55})

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
        '_urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        -- empty end lines are not rendered
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_up_navigation()
    local journal, text_area = arrange_empty_journal({w=55})

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
    local journal, text_area = arrange_empty_journal({w=55})

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
    local journal, text_area = arrange_empty_journal({w=55})

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
    local journal, text_area = arrange_empty_journal({w=55})

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
    local journal, text_area = arrange_empty_journal({w=55})

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
    local journal, text_area = arrange_empty_journal({w=55})

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

function test.handle_backspace()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero_',
    }, '\n'));

    for i=1,3 do
        simulate_input_keys('STRING_A000')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec lib_',
    }, '\n'));

    text_area:setCursor(62)
    journal:onRender()

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._12: Sed consectetur, urna sit amet aliquet ',
        'egestas, ante nibh porttitor mi, vitae rutrum eros ',
        'metus nec lib',
    }, '\n'));

    text_area:setCursor(2)
    journal:onRender()

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.112: Sed consectetur, urna sit amet aliquet ',
        'egestas, ante nibh porttitor mi, vitae rutrum eros ',
        'metus nec lib',
    }, '\n'));

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.112: Sed consectetur, urna sit amet aliquet ',
        'egestas, ante nibh porttitor mi, vitae rutrum eros ',
        'metus nec lib',
    }, '\n'));

    journal:dismiss()
end

function test.handle_delete()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_D')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(124)
    journal:onRender()
    simulate_input_keys('CUSTOM_CTRL_D')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        '_rttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(123)
    journal:onRender()
    simulate_input_keys('CUSTOM_CTRL_D')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibh_rttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(171)
    journal:onRender()
    simulate_input_keys('CUSTOM_CTRL_D')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibhorttitor mi, vitae rutrum eros metus nec libero._0: Lorem ',
        'ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    for i=1,59 do
        simulate_input_keys('CUSTOM_CTRL_D')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibhorttitor mi, vitae rutrum eros metus nec libero._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_D')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibhorttitor mi, vitae rutrum eros metus nec libero._',
    }, '\n'));

    journal:dismiss()
end

function test.line_end()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_E')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(70)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_E')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero._',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(200)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_E')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_E')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    journal:dismiss()
end

function test.line_beging()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_H')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(173)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_H')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_12: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_H')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.line_delete()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(65)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_'
    }, '\n'));

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_'
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_'
    }, '\n'));

    journal:dismiss()
end

function test.line_delete_to_end()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(70)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed_',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_last_word()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing _',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur _',
    }, '\n'));

    text_area:setCursor(82)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed _ urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    text_area:setCursor(37)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, _ctetur adipiscing elit.',
        '112: Sed , urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    for i=1,6 do
        simulate_input_keys('CUSTOM_CTRL_W')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '_ctetur adipiscing elit.',
        '112: Sed , urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_ctetur adipiscing elit.',
        '112: Sed , urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    journal:dismiss()
end

function test.jump_to_text_end()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('KEYBOARD_CURSOR_DOWN_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    journal:dismiss()
end

function test.jump_to_text_begin()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('KEYBOARD_CURSOR_UP_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.select_all()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.text_key_replace_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_text('+')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: +_psum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 6, 1, 6, 2)

    simulate_input_text('!')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: +ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: S!_r mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 3, 1, 6, 2)

    simulate_input_text('@')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: +ipsum dolor sit amet, consectetur adipiscing elit.',
        '112@_m ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.arrows_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('KEYBOARD_CURSOR_UP')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.fast_rewind_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT_FAST')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT_FAST')
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.click_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_mouse_click(text_area, 4, 0)
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_mouse_click(text_area, 4, 8)
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.line_navigation_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_H')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_E')
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.jump_begin_or_end_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP_FAST')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('KEYBOARD_CURSOR_DOWN_FAST')
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.new_line_override_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
         '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum ero',
    }, '\n'));

    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ',
        '_ metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.backspace_delete_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
         '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum ero',
    }, '\n'));

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _ metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_char_delete_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
         '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum ero',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_D')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _ metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_line_delete_selection_lines()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_12: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 4, 1, 29, 2)

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_1: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_line_rest_delete_selection_lines()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 6, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ',
        '112: S_',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 3, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ',
        '112_',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_last_word_delete_selection()
        local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _psum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 6, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: S_r mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 3, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ipsum dolor sit amet, consectetur adipiscing elit.',
        '112_m ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.single_mouse_click_set_cursor()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_click(text_area, 4, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _orem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 40, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus ne_ libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 49, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero._',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 60, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero._',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 10)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 21, 10)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor_sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 63, 10)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    journal:dismiss()
end

function test.double_mouse_click_select_word()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)
    simulate_mouse_click(text_area, 0, 0)

    expect.eq(read_selected_text(text_area), '60:')

    simulate_mouse_click(text_area, 4, 0)
    simulate_mouse_click(text_area, 4, 0)

    expect.eq(read_selected_text(text_area), 'Lorem')

    simulate_mouse_click(text_area, 40, 2)
    simulate_mouse_click(text_area, 40, 2)

    expect.eq(read_selected_text(text_area), 'nec')

    simulate_mouse_click(text_area, 58, 3)
    simulate_mouse_click(text_area, 58, 3)
    expect.eq(read_selected_text(text_area), 'elit')

    simulate_mouse_click(text_area, 60, 3)
    simulate_mouse_click(text_area, 60, 3)
    expect.eq(read_selected_text(text_area), '.')

    journal:dismiss()
end

function test.double_mouse_click_select_white_spaces()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = 'Lorem ipsum dolor sit amet,     consectetur elit.'
    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), text .. '_')

    simulate_mouse_click(text_area, 29, 0)
    simulate_mouse_click(text_area, 29, 0)

    expect.eq(read_selected_text(text_area), '     ')

    journal:dismiss()
end

function test.triple_mouse_click_select_line()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)
    simulate_mouse_click(text_area, 0, 0)
    simulate_mouse_click(text_area, 0, 0)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    simulate_mouse_click(text_area, 4, 0)
    simulate_mouse_click(text_area, 4, 0)
    simulate_mouse_click(text_area, 4, 0)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    simulate_mouse_click(text_area, 40, 2)
    simulate_mouse_click(text_area, 40, 2)
    simulate_mouse_click(text_area, 40, 2)

    expect.eq(read_selected_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_mouse_click(text_area, 58, 3)
    simulate_mouse_click(text_area, 58, 3)
    simulate_mouse_click(text_area, 58, 3)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    simulate_mouse_click(text_area, 60, 3)
    simulate_mouse_click(text_area, 60, 3)
    simulate_mouse_click(text_area, 60, 3)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    journal:dismiss()
end

function test.mouse_selection_control()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ipsum dolor sit amet')

    simulate_mouse_drag(text_area, 0, 0, 29, 0)

    expect.eq(read_selected_text(text_area), '60: Lorem ipsum dolor sit amet')

    simulate_mouse_drag(text_area, 32, 0, 32, 1)

    expect.eq(read_selected_text(text_area), table.concat({
        'consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit am'
    }, '\n'));

    simulate_mouse_drag(text_area, 32, 1, 48, 2)

    expect.eq(read_selected_text(text_area), table.concat({
        'met aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 59, 3)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 65, 3)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 65, 6)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 42, 6)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur'
    }, '\n'));

    journal:dismiss()
end

function test.copy_and_paste_text_line()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_mouse_click(text_area, 15, 3)
    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum_dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 5, 0)
    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '112: _ed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 6, 0)
    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_mouse_click(text_area, 5, 6)
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: L_rem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.copy_and_paste_selected_text()
        local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 8, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem')

    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem_ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 4, 2)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLorem_itor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'Lorem_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLoremtitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 60, 4)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'Lorem60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLoremtitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.Lorem_',
    }, '\n'));

    journal:dismiss()
end

function test.cut_and_paste_text_line()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)
    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 60, 2)
    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_',
    }, '\n'));

    journal:dismiss()
end

function test.cut_and_paste_selected_text()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 8, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem')

    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem_ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_drag(text_area, 4, 0, 8, 0)
    simulate_input_keys('CUSTOM_CTRL_X')

    simulate_mouse_click(text_area, 4, 2)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60:  ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLorem_itor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_drag(text_area, 5, 2, 8, 2)
    simulate_input_keys('CUSTOM_CTRL_X')

    simulate_mouse_click(text_area, 0, 0)
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'orem_0:  ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLtitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_drag(text_area, 5, 2, 8, 2)
    simulate_input_keys('CUSTOM_CTRL_X')

    simulate_mouse_click(text_area, 60, 4)
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'orem60:  ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLr mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.tito_',
    }, '\n'));

    journal:dismiss()
end
