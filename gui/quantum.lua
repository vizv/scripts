--@ module = true

local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

local assign_minecarts = reqscript('assign-minecarts')
local quickfort = reqscript('quickfort')
local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_orders = reqscript('internal/quickfort/orders')

local QuantumUI = {}

local function is_in_extents(bld, x, y)
    local extents = bld.room.extents
    if not extents then return true end -- building is solid
    local yoff = (y - bld.y1) * (bld.x2 - bld.x1 + 1)
    local xoff = x - bld.x1
    return extents[yoff+xoff] == 1
end

function QuantumUI:select_stockpile(pos)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    if not flags or occupancy.building == 0 then return end
    local bld = dfhack.buildings.findAtTile(pos)
    if not bld or bld:getType() ~= df.building_type.Stockpile then return end

    local tiles = {}

    for x=bld.x1,bld.x2 do
        for y=bld.y1,bld.y2 do
            if is_in_extents(bld, x, y) then
                ensure_key(ensure_key(tiles, bld.z), y)[x] = true
            end
        end
    end

    self.feeder = bld
    self.feeder_tiles = tiles

    self:updateLayout()
end

function QuantumUI:render_feeder_overlay()
    if not gui.blink_visible(1000) then return end

    local zlevel = self.feeder_tiles[df.global.window_z]
    if not zlevel then return end

    local function get_feeder_overlay_char(pos)
        return safe_index(zlevel, pos.y, pos.x) and 'X'
    end

    self:renderMapOverlay(get_feeder_overlay_char, self.feeder)
end

local function get_qsp_pos(cursor, offset)
    return {
        x=cursor.x+(offset.x or 0),
        y=cursor.y+(offset.y or 0),
        z=cursor.z
    }
end

local function is_valid_pos(cursor, qsp_pos)
    local stats = quickfort.apply_blueprint{mode='build', data='trackstop', pos=cursor, dry_run=true}
    if stats.build_designated.value <= 0 then return false end

    if not qsp_pos then return true end

    stats = quickfort.apply_blueprint{mode='place', data='c', pos=qsp_pos, dry_run=true}
    return stats.place_designated.value > 0
end

function QuantumUI:render_destination_overlay()
    local cursor = guidm.getCursorPos()
    local qsp_pos = self:get_qsp_pos(cursor)
    local bounds = {x1=qsp_pos.x, x2=qsp_pos.x, y1=qsp_pos.y, y2=qsp_pos.y}

    local ok = is_valid_pos(cursor, qsp_pos)

    local function get_dest_overlay_char()
        return 'X', ok and COLOR_GREEN or COLOR_RED
    end

    self:renderMapOverlay(get_dest_overlay_char, bounds)
end

function QuantumUI:onRenderBody()
    if not self.feeder then return end

    self:render_feeder_overlay()
    self:render_destination_overlay()
end

local function get_quantumstop_data(feeder, name, trackstop_dir)
    local stop_name, route_name
    if name == '' then
        local next_route_id = df.global.plotinfo.hauling.next_id
        stop_name = ('Dumper %d'):format(next_route_id)
        route_name = ('Quantum %d'):format(next_route_id)
    else
        stop_name = ('%s dumper'):format(name)
        route_name = ('%s quantum'):format(name)
    end

    return ('trackstop%s{name="%s" take_from=%d route="%s"}')
           :format(trackstop_dir, stop_name, feeder.id, route_name)
end

local function get_quantumsp_data(name)
    if name == '' then
        local next_route_id = df.global.plotinfo.hauling.next_id
        name = ('Quantum %d'):format(next_route_id-1)
    end
    return ('ry{name="%s" quantum=true}'):format(name)
end

local function order_minecart(pos)
    local quickfort_ctx = quickfort_command.init_ctx{
            command='orders', blueprint_name='gui/quantum', cursor=pos}
    quickfort_orders.enqueue_additional_order(quickfort_ctx, 'wooden minecart')
    quickfort_orders.create_orders(quickfort_ctx)
end

-- this function assumes that is_valid_pos() has already validated the positions
local function create_quantum(pos, qsp_pos, feeder, name, trackstop_dir)
    local data = get_quantumstop_data(feeder, name, trackstop_dir)
    local stats = quickfort.apply_blueprint{mode='build', pos=pos, data=data}
    if stats.build_designated.value == 0 then
        error(('failed to build trackstop at (%d, %d, %d)')
              :format(pos.x, pos.y, pos.z))
    end

    data = get_quantumsp_data(name)
    stats = quickfort.apply_blueprint{mode='place', pos=qsp_pos, data=data}
    if stats.place_designated.value == 0 then
        error(('failed to place stockpile at (%d, %d, %d)')
              :format(qsp_pos.x, qsp_pos.y, qsp_pos.z))
    end
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        is_in_extents=is_in_extents,
        is_valid_pos=is_valid_pos,
        create_quantum=create_quantum,
    }
end

----------------------
-- Quantum
--

Quantum = defclass(Quantum, widgets.Window)
Quantum.ATTRS {
    frame_title='Quantum',
    frame={w=35, h=17, r=2, t=18},
    autoarrange_subviews=true,
    autoarrange_gap=1,
    feeder=DEFAULT_NIL,
}

function Quantum:init()
    local cart_count = #assign_minecarts.get_free_vehicles()

    self:addviews{
        widgets.WrappedLabel{
            text_to_wrap=self:callback('get_help_text'),
            text_pen=COLOR_GREY,
        },
        widgets.EditField{
            view_id='name',
            label_text='Name: ',
            key='CUSTOM_CTRL_N',
            key_sep=' ',
            on_char=function(char, text) return #text < 12 end,  -- TODO can be circumvented by pasting
            text='',
        },
        widgets.CycleHotkeyLabel{
            view_id='dump_dir',
            key='CUSTOM_CTRL_D',
            key_sep=' ',
            label='Dump direction:',
            options={
                {label='North', value={y=-1}, pen=COLOR_YELLOW},
                {label='South', value={y=1}, pen=COLOR_YELLOW},
                {label='East', value={x=1}, pen=COLOR_YELLOW},
                {label='West', value={x=-1}, pen=COLOR_YELLOW},
            },
        },
        widgets.ToggleHotkeyLabel{
            view_id='create_sp',
            key='CUSTOM_CTRL_Z',
            label='Create output pile:',
        },
        widgets.WrappedLabel{
            text_to_wrap=('%d minecart%s available: %s will be %s'):format(
                cart_count, cart_count == 1 and '' or 's',
                cart_count == 1 and 'it' or 'one',
                cart_count > 0 and 'automatically assigned to the quantum route'
                    or 'ordered via the manager for you to assign later'),
        },
    }
end

function Quantum:get_help_text()
    if not self.feeder then
        return 'Please select the feeder stockpile.'
    end
    return 'Please select the location of the new quantum dumper.'
end

local function get_hover_stockpile(pos)
    pos = pos or dfhack.gui.getMousePos()
    if not pos then return end
    local bld = dfhack.buildings.findAtTile(pos)
    if not bld or bld:getType() ~= df.building_type.Stockpile then return end
    return bld
end

function Quantum:render(dc)
    -- TODO: highlight feeder stockpile and stockpile under mouse cursor
    local hover_sp = get_hover_stockpile()
    Quantum.super.render(self, dc)
end

function Quantum:try_commit()
    local pos = dfhack.gui.getMousePos()
    local qsp_pos = self.subviews.create_sp:getOptionValue() and
        get_qsp_pos(pos, self.subviews.dump_dir:getOptionValue())
    if not is_valid_pos(pos, qsp_pos) then
        return
    end

    create_quantum(pos, qsp_pos, self.feeder, self.subviews.name.text,
        self.subviews.dump_dir:getOptionLabel():sub(1,1))

    local message = nil
    if assign_minecarts.assign_minecart_to_last_route(true) then
        message = 'An available minecart was assigned to your new' ..
                ' quantum stockpile. You\'re all done!'
    else
        order_minecart(pos)
        message = 'There are no minecarts available to assign to the' ..
                ' quantum stockpile, but a manager order to produce' ..
                ' one was created for you. Once the minecart is' ..
                ' built, please add it to the quantum stockpile route' ..
                ' with the "assign-minecarts all" command or manually in' ..
                ' the (h)auling menu.'
    end
    -- display a message box telling the user what we just did
    dialogs.MessageBox{text=message:wrap(70)}:show()
    return true
end

function Quantum:onInput(keys)
    if Quantum.super.onInput(self, keys) then return true end

    if not keys._MOUSE_L then return end
    local sp = get_hover_stockpile()
    if sp then
        if sp ~= self.feeder then
            self.feeder = sp
            self:updateLayout()
        end
    elseif self.feeder then
        self:try_commit()
    end
end

----------------------
-- QuantumScreen
--

QuantumScreen = defclass(QuantumScreen, gui.ZScreen)
QuantumScreen.ATTRS {
    focus_path='quantum',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
    feeder=DEFAULT_NIL,
}

function QuantumScreen:init()
    self:addviews{Quantum{feeder=self.feeder}}
end

function QuantumScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

view = view and view:raise() or QuantumScreen{feeder=dfhack.gui.getSelectedStockpile(true)}:show()
