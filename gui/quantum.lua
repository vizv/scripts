-- interactively creates quantum stockpiles
--@ module = true

local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

local assign_minecarts = reqscript('assign-minecarts')
local quickfort = reqscript('quickfort')
local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_orders = reqscript('internal/quickfort/orders')


-- UI Layout
QuantumUI = defclass(QuantumUI, gui.ZScreen)
QuantumUI.ATTRS {
    focus_path='quantum',
	defocusable=true
}

function QuantumUI:init()
    local cart_count = #assign_minecarts.get_free_vehicles()

    local main_panel = widgets.Window{
		frame_title = 'Quantum Stockpile',
		frame = { w=60, h=26 },
		resizable = true,
		autoarrange_subviews=true
	}
	
    main_panel:addviews{
        widgets.Label{
			text='Quantum'
		},
        widgets.WrappedLabel{
            text_to_wrap=self:callback('get_help_text'),
            text_pen=COLOR_GREY
		},
		widgets.HotkeyLabel{
            key='CUSTOM_Q',
            label='Place QSP under cursor',
            on_activate=self:callback('commit')
		},
        widgets.Panel{autoarrange_subviews=true, 
			frame = { w=75, h=5 },
			resizable = true,
			subviews={
				widgets.EditField{
					view_id='name',
					key='CUSTOM_N',
					on_char=self:callback('on_name_char'),
					text=''
				},
				widgets.TooltipLabel{
					text_to_wrap='Give the quantum stockpile a custom name.',
					show_tooltip=true
				}
			}
		},
        widgets.Panel{
			autoarrange_subviews=true, 
			frame = { w=75, h=5 },
			resizable = true,
			subviews={
				widgets.CycleHotkeyLabel{
					view_id='dir',
					key='CUSTOM_D',
					options={
						{label='North', value={y=-1}},
                        {label='South', value={y=1}},
                        {label='East', value={x=1}},
                        {label='West', value={x=-1}}
					}
				},
				widgets.TooltipLabel{
					text_to_wrap='Set the dump direction of the quantum stop.',
					show_tooltip=true
				}
			}
		},
        widgets.Panel{
			autoarrange_subviews=true, 
			frame = { w=75, h=5 },
			resizable = true,
			subviews={
				widgets.ToggleHotkeyLabel{
					view_id='refuse',
					key='CUSTOM_R',
					label='Allow refuse/corpses',
					initial_option=false
				},
				widgets.TooltipLabel{
					text_to_wrap='Note that enabling refuse will cause clothes' ..
                    ' and armor in this stockpile to quickly rot away.',
					show_tooltip=true
				}
			}
		},
        widgets.WrappedLabel{
            text_to_wrap=('%d minecart%s available: %s %s'):format(
                cart_count, cart_count == 1 and '' or 's',
                cart_count == 1 and 'it' or 'one',
                cart_count > 0 and 'will be automatically assigned to the quantum route'
                    or 'will need to be ordered for you to assign later')
		},
        widgets.HotkeyLabel{
            key='LEAVESCREEN',
            label=self:callback('get_back_text'),
            on_activate=self:callback('on_back')
		}
    }

    self:addviews{main_panel}
end

-- UI Functions
function QuantumUI:get_help_text()
    if not dfhack.gui.getSelectedStockpile() then
        return 'Please select the feeder stockpile with the cursor or mouse.'
    end
    return 'Please select the location of the new quantum stockpile with the' ..
            ' cursor or mouse, then press "q"'
end

function QuantumUI:get_back_text()
    if 
		self.feeder 
	then
        return 'Cancel selection'
	end
    return 'Back'
end

function QuantumUI:on_back()
    if 
		self.feeder 
	then
        self.feeder = nil
        self:updateLayout()
    else
        self:dismiss()
	end
end

function QuantumUI:on_name_char(char, text)
    return #text < 12
end

--UI Data Tables
qspOutputHor = {
	["North"]=0,
	["East"]=1,
	["South"]=0,
	["West"]=-1
}

qspOutputVert = {
	["North"]=-1,
	["East"]=0,
	["South"]=1,
	["West"]=0
}

qspTrackstopDir = {
	["North"]='trackstopN',
	["East"]='trackstopE',
	["South"]='trackstopS',
	["West"]='trackstopW'
}

qspOutputType = {
	[true]='afunswebhlzSgpdyr',
	[false]='afunswebhlzSgpd'
}



--Actually making the QSP
function QuantumUI:commit()
	name = self.subviews.name.text
    dump_dir = self.subviews.dir:getOptionLabel()
    allow_refuse = self.subviews.refuse:getOptionValue()
	input_id = dfhack.gui.getSelectedStockpile().id
	output_hor = qspOutputHor[dump_dir]
	output_vert = qspOutputVert[dump_dir]
	output_type = qspOutputType[allow_refuse]
	trackstop_dir = qspTrackstopDir[dump_dir]
	if
		name == ''
	then
		name = 'Unnamed QSP'
	end
	placed_output = output_type..'{quantum=true}'
	placed_trackstop = trackstop_dir..'{take_from='..input_id..' route="'..name..'"}'
	
	quickfort.apply_blueprint{
		mode='place',
		pos=dfhack.gui.getMousePos(), 
		data={
			[0]={
				[output_vert]={[output_hor]=placed_output}
			}
		}
	}
	
	quickfort.apply_blueprint{
		mode='build',
		pos=dfhack.gui.getMousePos(), 
		data={
			[0]={
				[0]={[0]=placed_trackstop}
			}
		}
	}
	dfhack.run_command('assign-minecarts all')
	self:updateLayout()
	message= 'QSP Placed!'
	dialogs.MessageBox{text=message:wrap(70)}:show()
end

local function order_minecart(pos)
    local quickfort_ctx = quickfort_command.init_ctx{
            command='orders', blueprint_name='gui/quantum', cursor=pos}
    quickfort_orders.enqueue_additional_order(quickfort_ctx, 'wooden minecart')
    quickfort_orders.create_orders(quickfort_ctx)
end
--Key Input
function QuantumUI:onInput(keys)
	pos = dfhack.gui.getSelectedStockpile()
	
    if 
		QuantumUI.super.onInput(self, keys) 
	then 
		message="burp"
		dialogs.MessageBox{text=message:wrap(70)}:show()
		return true 
	end

    self:propagateMoveKeys(keys)

    local pos = nil
	if
		keys.CUSTOM_H
	then
		message="burp"
		dialogs.MessageBox{text=message:wrap(70)}:show()
    elseif 
		keys._MOUSE_L_DOWN and not self:getMouseFramePos() 
	then
		message="burp"
		dialogs.MessageBox{text=message:wrap(70)}:show()
        quickfort.apply_blueprint{
			mode='place',
			pos=dfhack.gui.getMousePos(), 
			data={
				[0]={
					[0]={[0]="c"}
				}
	}
}
    elseif 
		keys.SELECT 
	then
        pos = guidm.getCursorPos()
    end

   
end

function QuantumUI:onDismiss()
    view = nil
end


--Misc
if dfhack_flags.module then
    return
end

view = view and view:raise() or QuantumUI{}:show()
