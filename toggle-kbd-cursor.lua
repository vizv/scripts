local guidm = require('gui.dwarfmode')

local flags4 = df.global.d_init.flags4

if flags4.KEYBOARD_CURSOR then
    flags4.KEYBOARD_CURSOR = false
    guidm.setCursorPos(xyz2pos(-30000, -30000, -30000))
    print('Keyboard cursor disabled.')
else
    guidm.setCursorPos(guidm.Viewport.get():getCenter())
    flags4.KEYBOARD_CURSOR = true
    print('Keyboard cursor enabled.')
end
