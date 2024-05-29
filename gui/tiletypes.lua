--@ module = true
local plugin = require('plugins.tiletypes')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')
local utils = require('utils')
local textures = require('gui.textures')
local argparse = require('argparse')

local UI_AREA = {r=2, t=18, w=38, h=35}
local POPUP_UI_AREA = {r=41, t=18, w=30, h=19}

local CONFIG_BUTTON = {
    { tile= dfhack.pen.parse{fg=COLOR_CYAN, tile=curry(textures.tp_control_panel, 7) or nil, ch=string.byte('[')} },
    { tile= dfhack.pen.parse{tile=curry(textures.tp_control_panel, 10) or nil, ch=15} }, -- gear/masterwork symbol
    { tile= dfhack.pen.parse{fg=COLOR_CYAN, tile=curry(textures.tp_control_panel, 8) or nil, ch=string.byte(']')} }
}

local OTHER_LABEL_FORMAT = { first= string.char(15).."(", last= ")"}

local UI_COLORS = {
    SELECTED= COLOR_GREEN,
    SELECTED2= COLOR_CYAN,
    SELECTED_BORDER= COLOR_LIGHTGREEN,
    DESELECTED= COLOR_GRAY,
    DESELECTED2= COLOR_DARKGRAY,
    DESELECTED_BORDER= COLOR_GRAY,
    HIGHLIGHTED= COLOR_WHITE,
    HIGHLIGHTED2= COLOR_DARKGRAY,
    HIGHLIGHTED_BORDER= COLOR_YELLOW,
    VALUE_NONE= COLOR_GRAY,
    VALUE= COLOR_YELLOW
}

local TILESET = dfhack.textures.loadTileset('hack/data/art/tiletypes.png', 8, 12, true)
local TILESET_STRIDE = 16

local OPTION_SETTINGS = {
    [-1] = { char1= " ", char2= " ", offset=  97, pen = COLOR_GRAY },
    [ 0] = { char1= "X", char2= "X", offset= 105, pen = COLOR_RED },
    [ 1] = { char1= "+", char2= "+", offset= 101, pen = COLOR_LIGHTGREEN },
}

local MORE_OPTIONS = {
    ["hidden"]       = { label= "Hidden" },
    ["light"]        = { label= "Light" },
    ["subterranean"] = { label= "Subterranean" },
    ["skyview"]      = { label= "Skyview" },
    ["aquifer"]      = { label= "Aquifer", overrides= {
        { value= 1, char1= 173, char2= 173, offset= 109, pen = COLOR_LIGHTBLUE },
        { value= 2, char1= 247, char2= 247, offset= 157, pen = COLOR_BLUE }
    } },
}

local MODE_LIST = {
    { label= "Paint"   , value= "paint"  , pen= COLOR_YELLOW     },
    { label= "Replace" , value= "replace", pen= COLOR_LIGHTGREEN },
    { label= "Fill"    , value= "fill"   , pen= COLOR_GREEN      },
    { label= "Remove"  , value= "remove" , pen= COLOR_RED        },
}

function isEmptyTile(pos)
    if pos and dfhack.maps.isValidTilePos(pos.x or -1, pos.y or -1, pos.z or -1) then
        local tiletype = dfhack.maps.getTileType(pos.x, pos.y, pos.z)
        return tiletype and (
            df.tiletype.attrs[tiletype].shape == df.tiletype_shape.NONE
            or df.tiletype.attrs[tiletype].material == df.tiletype_material.AIR
        )
    end
    return true
end

local MODE_SETTINGS = {
    ["paint"] = {
        idx= 1, config= true , char1= 219, char2= 219, offset=  1, selected_offset = 49,
        description= "Paint tiles",
        validator= function(pos) return true end
    },
    ["replace"] = {
        idx= 2, config= true , char1=   8, char2=   7, offset=  5, selected_offset = 53,
        description= "Replace non-empty tiles",
        validator= function(pos) return not isEmptyTile(pos) end
    },
    ["fill"] = {
        idx= 3, config= true , char1=   7, char2=   8, offset=  9, selected_offset = 57,
        description= "Fill in empty tiles",
        validator= function(pos) return isEmptyTile(pos) end
    },
    ["remove"] = {
        idx= 4, config= false, char1= 177, char2= 177, offset= 13, selected_offset = 61,
        description= "Remove selected tiles",
        validator= function(pos) return true end
    },
}

CYCLE_VALUES = {
    shape = {
        [df.tiletype_shape.NONE] = true,
        [df.tiletype_shape.EMPTY] = true,
        [df.tiletype_shape.FLOOR] = true,
        [df.tiletype_shape.WALL] = true,
        other = df.tiletype_shape.STAIR_UPDOWN
    },
    material = {
        [df.tiletype_material.NONE] = true,
        [df.tiletype_material.AIR] = true,
        [df.tiletype_material.SOIL] = true,
        [df.tiletype_material.STONE] = true,
        other = df.tiletype_material.LAVA_STONE
    },
    special = {
        [df.tiletype_special.NONE] = true,
        [df.tiletype_special.NORMAL] = true,
        [df.tiletype_special.SMOOTH] = true,
        other = df.tiletype_special.WORN_1
    },
}

---@class TileType
---@field shape? df.tiletype_shape
---@field material? df.tiletype_material
---@field special? df.tiletype_special
---@field variant? df.tiletype_variant
---@field dig? integer Only for filters
---@field hidden? integer
---@field light? integer
---@field subterranean? integer
---@field skyview? integer
---@field aquifer? integer
---@field stone_material? integer
---@field vein_type? df.inclusion_type

---@param pos df.coord
---@param target TileType
---@return boolean
function setTile(pos, target)
    local toValidEnumValue = function(value, enum, default)
        return value ~= nil and enum[value] and value or default
    end
    local toValidOptionValue = function(value)
        return value == nil and -1 or value
    end

    local tiletype = {
        shape          = toValidEnumValue(target.shape,    df.tiletype_shape,    df.tiletype_shape.NONE),
        material       = toValidEnumValue(target.material, df.tiletype_material, df.tiletype_material.NONE),
        special        = toValidEnumValue(target.special,  df.tiletype_special,  df.tiletype_special.NONE),
        variant        = toValidEnumValue(target.variant,  df.tiletype_variant,  df.tiletype_variant.NONE),
        hidden         = toValidOptionValue(target.hidden),
        light          = toValidOptionValue(target.light),
        subterranean   = toValidOptionValue(target.subterranean),
        skyview        = toValidOptionValue(target.skyview),
        aquifer        = toValidOptionValue(target.aquifer),
    }
    tiletype.stone_material = tiletype.material == df.tiletype_material.STONE and target.stone_material or -1
    tiletype.vein_type      = tiletype.material ~= df.tiletype_material.STONE and -1 or toValidEnumValue(target.vein_type,  df.inclusion_type,  df.inclusion_type.CLUSTER)

    return plugin.tiletypes_setTile(pos, tiletype)
end

--#region GUI

--#region UI Utilities

---@type widgets.LabelToken
local EMPTY_TOKEN = { text=' ', hpen=dfhack.pen.make(COLOR_RESET), width=1 }

---@class InlineButtonLabelSpec
---@field left_specs? widgets.ButtonLabelSpec
---@field right_specs? widgets.ButtonLabelSpec
---@field width? integer
---@field height? integer
---@field spacing? integer

---@nodiscard
---@param spec InlineButtonLabelSpec
---@return widgets.LabelToken[]
function makeInlineButtonLabelText(spec)
    spec.left_specs = safe_index(spec, "left_specs", "chars") and spec.left_specs or {chars={}}
    spec.right_specs = safe_index(spec, "right_specs", "chars") and spec.right_specs or {chars={}}
    spec.width = spec.width or -1
    spec.height = spec.height or -1
    spec.spacing = spec.spacing or -1

    local getSpecWidth = function(value)
        local width = 0
        for _,v in pairs(value.chars) do
            width = math.max(width, #v)
        end
        return width
    end

    local left_width = getSpecWidth(spec.left_specs)
    local right_width = getSpecWidth(spec.right_specs)
    spec.width = spec.width >= 0 and spec.width or (left_width + right_width + math.max(spec.spacing, 0))

    local left_height = #spec.left_specs.chars
    local right_height = #spec.right_specs.chars
    spec.height = spec.height >= 0 and spec.height or math.max(left_height, right_height)

    local left_tokens = widgets.makeButtonLabelText(spec.left_specs)
    local right_tokens = widgets.makeButtonLabelText(spec.right_specs)

    local centerHeight = function(tokens, height)
        local height_spacing = (spec.height - height) // 2
        for i=1, height_spacing do
            table.insert(tokens, 1, NEWLINE)
        end
        height_spacing = spec.height - height - height_spacing
        for i=1, height_spacing do
            table.insert(tokens, NEWLINE)
        end
    end

    centerHeight(left_tokens, left_height)
    centerHeight(right_tokens, right_height)

    local right_start = spec.spacing >= 0 and (left_width + spec.spacing + 1) or math.max(left_width, spec.width - right_width)

    local label_tokens = {}
    local left_cursor = 1
    local right_cursor = 1
    for y=1, spec.height do
        for x=1, spec.width do
            local token = nil
            if x <= left_width then
                token = left_tokens[left_cursor]
                token = token ~= NEWLINE and token or nil
                if token then
                    left_cursor = left_cursor + 1
                end
            elseif x >= right_start then
                token = right_tokens[right_cursor]
                token = token ~= NEWLINE and token or nil
                if token then
                    right_cursor = right_cursor + 1
                end
            end
            table.insert(label_tokens, token or EMPTY_TOKEN)
        end

        if y ~= spec.height then
            -- Move the cursors to the token following the next NEWLINE
            while left_tokens[left_cursor - 1] ~= NEWLINE do
                left_cursor = left_cursor + 1
            end
            while right_tokens[right_cursor - 1] ~= NEWLINE do
                right_cursor = right_cursor + 1
            end
        end

        table.insert(label_tokens, NEWLINE)
    end

    return label_tokens
end

-- Draws a list of rects with associated pens, without overlapping the given screen rect
---@param draw_queue { pen: dfhack.pen, rect: { x1: integer, x2: integer, y1: integer, y2: integer } }[]
---@param screen_rect { x1: integer, x2: integer, y1: integer, y2: integer }
function drawOutsideOfScreenRect(draw_queue, screen_rect)
    local view_dims = dfhack.gui.getDwarfmodeViewDims()
    local tile_view_size = { x= view_dims.map_x2 - view_dims.map_x1 + 1, y= view_dims.map_y2 - view_dims.map_y1 + 1 }
    local display_view_size = { x= df.global.init.display.grid_x, y= df.global.init.display.grid_y }
    local display_to_tile_ratio = { x= tile_view_size.x / display_view_size.x, y= tile_view_size.y / display_view_size.y }

    local screen_tile_rect = {
        x1= screen_rect.x1 * display_to_tile_ratio.x - 1,
        x2= screen_rect.x2 * display_to_tile_ratio.x + 1,
        y1= screen_rect.y1 * display_to_tile_ratio.y - 1,
        y2= screen_rect.y2 * display_to_tile_ratio.y + 1
    }

    for _,draw_rect in pairs(draw_queue) do
        -- If there is any overlap between the draw rect and the screen rect
        if screen_tile_rect.x1 < draw_rect.rect.x2
            and screen_tile_rect.x2 > draw_rect.rect.x1
            and screen_tile_rect.y1 < draw_rect.rect.y2
            and screen_tile_rect.y2 > draw_rect.rect.y1
        then
            local temp_rect = { x1= draw_rect.rect.x1, x2= draw_rect.rect.x2, y1= draw_rect.rect.y1, y2= draw_rect.rect.y2 }
            -- Draw to the left of the screen rect
            if temp_rect.x1 <= screen_tile_rect.x1 then
                table.insert(draw_queue, {
                    pen= draw_rect.pen,
                    rect = {
                        x1= temp_rect.x1,
                        x2= math.min(temp_rect.x2, screen_tile_rect.x1),
                        y1= temp_rect.y1,
                        y2= temp_rect.y2
                    }
                })
                temp_rect.x1 = screen_tile_rect.x1
            end
            -- Draw to the right of the screen rect
            if temp_rect.x2 >= screen_tile_rect.x2 then
                table.insert(draw_queue, {
                    pen= draw_rect.pen,
                    rect = {
                        x1= math.max(temp_rect.x1, screen_tile_rect.x2),
                        x2= temp_rect.x2,
                        y1= temp_rect.y1,
                        y2= temp_rect.y2
                    }
                })
                temp_rect.x2 = screen_tile_rect.x2
            end
            -- Draw above the screen rect
            if temp_rect.y1 <= screen_tile_rect.y1 then
                table.insert(draw_queue, {
                    pen= draw_rect.pen,
                    rect = {
                        x1= temp_rect.x1,
                        x2= temp_rect.x2,
                        y1= temp_rect.y1,
                        y2= math.min(temp_rect.y2, screen_tile_rect.y1)
                    }
                })
                temp_rect.y1 = screen_tile_rect.y1
            end
            -- Draw below the screen rect
            if temp_rect.y2 >= screen_tile_rect.y2 then
                table.insert(draw_queue, {
                    pen= draw_rect.pen,
                    rect = {
                        x1= temp_rect.x1,
                        x2= temp_rect.x2,
                        y1= math.max(temp_rect.y1, screen_tile_rect.y2),
                        y2= temp_rect.y2
                    }
                })
                temp_rect.y2 = screen_tile_rect.y2
            end

        -- No overlap
        else
            dfhack.screen.fillRect(draw_rect.pen, math.floor(draw_rect.rect.x1), math.floor(draw_rect.rect.y1), math.floor(draw_rect.rect.x2), math.floor(draw_rect.rect.y2), true)
        end
    end
end

local TILE_MAP = {
    getPenKey= function(nesw)
        return (
            (nesw.n and 8 or 0)
            + (nesw.e and 4 or 0)
            + (nesw.s and 2 or 0)
            + (nesw.w and 1 or 0)
        )
    end
}
TILE_MAP.pens= {
    [TILE_MAP.getPenKey{ n=false, e=false, s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 1,  2), fg=COLOR_GREEN, ch='X'}, -- INSIDE
    [TILE_MAP.getPenKey{ n=true,  e=false, s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 0,  1), fg=COLOR_GREEN, ch='X'}, -- NW
    [TILE_MAP.getPenKey{ n=true,  e=false, s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 1,  1), fg=COLOR_GREEN, ch='X'}, -- NORTH
    [TILE_MAP.getPenKey{ n=true,  e=true,  s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 2,  1), fg=COLOR_GREEN, ch='X'}, -- NE
    [TILE_MAP.getPenKey{ n=false, e=false, s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 0,  2), fg=COLOR_GREEN, ch='X'}, -- WEST
    [TILE_MAP.getPenKey{ n=false, e=true,  s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 2,  2), fg=COLOR_GREEN, ch='X'}, -- EAST
    [TILE_MAP.getPenKey{ n=false, e=false, s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 0,  3), fg=COLOR_GREEN, ch='X'}, -- SW
    [TILE_MAP.getPenKey{ n=false, e=false, s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 1,  3), fg=COLOR_GREEN, ch='X'}, -- SOUTH
    [TILE_MAP.getPenKey{ n=false, e=true,  s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 2,  3), fg=COLOR_GREEN, ch='X'}, -- SE
    [TILE_MAP.getPenKey{ n=true,  e=true,  s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 3,  2), fg=COLOR_GREEN, ch='X'}, -- N_NUB
    [TILE_MAP.getPenKey{ n=true,  e=true,  s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 5,  1), fg=COLOR_GREEN, ch='X'}, -- E_NUB
    [TILE_MAP.getPenKey{ n=true,  e=false, s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 3,  1), fg=COLOR_GREEN, ch='X'}, -- W_NUB
    [TILE_MAP.getPenKey{ n=false, e=true,  s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 4,  2), fg=COLOR_GREEN, ch='X'}, -- S_NUB
    [TILE_MAP.getPenKey{ n=false, e=true,  s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 3,  3), fg=COLOR_GREEN, ch='X'}, -- VERT_NS
    [TILE_MAP.getPenKey{ n=true,  e=false, s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 4,  1), fg=COLOR_GREEN, ch='X'}, -- VERT_EW
    [TILE_MAP.getPenKey{ n=true,  e=true,  s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 4,  3), fg=COLOR_GREEN, ch='X'}, -- POINT
}

-- Box data class

---@class Box.attrs
---@field valid boolean
---@field min df.coord
---@field max df.coord

---@class Box.attrs.partial: Box.attrs

---@class Box: Box.attrs
---@field ATTRS Box.attrs|fun(attributes: Box.attrs.partial)
---@overload fun(init_table: Box.attrs.partial): self
Box = defclass(Box)
Box.ATTRS {
    valid = true, -- For output
    min = DEFAULT_NIL,
    max = DEFAULT_NIL
}

function Box:init(points)
    self.min = {}
    self.max = {}
    for _,value in pairs(points) do
        if value and dfhack.maps.isValidTilePos(value.x or -1, value.y or -1, value.z or -1) then
            self.min.x = self.min.x and math.min(self.min.x, value.x) or value.x
            self.min.y = self.min.y and math.min(self.min.y, value.y) or value.y
            self.min.z = self.min.z and math.min(self.min.z, value.z) or value.z
            self.max.x = self.max.x and math.max(self.max.x, value.x) or value.x
            self.max.y = self.max.y and math.max(self.max.y, value.y) or value.y
            self.max.z = self.max.z and math.max(self.max.z, value.z) or value.z
        else
            self.valid = false
            break
        end
    end

    self.valid = self.valid and self.min and self.max
        and dfhack.maps.isValidTilePos(self.min.x or -1, self.min.y or -1, self.min.z or -1)
        and dfhack.maps.isValidTilePos(self.max.x or -1, self.max.y or -1, self.max.z or -1)

    if not self.valid then
        self.min = { x= -1, y= -1, z= -1}
        self.max = { x= -1, y= -1, z= -1}
    end
end

function Box:iterate(callback)
    if self.valid then
        for z = self.min.z, self.max.z do
            for y = self.min.y, self.max.y do
                for x = self.min.x, self.max.x do
                    callback({ x= x, y= y, z= z })
                end
            end
        end
    end
end

function Box:draw(tile_map, frame_rect, ascii_fill)
    if self.valid and df.global.window_z >= self.min.z and df.global.window_z <= self.max.z then
        local screen_min = {
            x= self.min.x - df.global.window_x,
            y= self.min.y - df.global.window_y
        }
        local screen_max = {
            x= self.max.x - df.global.window_x,
            y= self.max.y - df.global.window_y
        }

        local draw_queue = {}

        if self.min.x == self.max.x and self.min.y == self.max.y then
            -- Single point
            draw_queue = {
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=true, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
                }
            }

        elseif self.min.x == self.max.x then
            -- Vertical line
            draw_queue = {
                -- Line
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=false, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_max.y }
                },
                -- Top nub
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=false, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
                },
                -- Bottom nub
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=true, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_max.y, y2= screen_max.y }
                }
            }
        elseif self.min.y == self.max.y then
            -- Horizontal line
            draw_queue = {
                -- Line
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=true, w=false}],
                    rect= { x1= screen_min.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
                },
                -- Left nub
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=true, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
                },
                -- Right nub
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=true, w=false}],
                    rect= { x1= screen_max.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
                }
            }
        else
            -- Rectangle
            draw_queue = {
                -- North Edge
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=false, w=false}],
                    rect= { x1= screen_min.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
                },
                -- East Edge
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=false, w=false}],
                    rect= { x1= screen_max.x, x2= screen_max.x, y1= screen_min.y, y2= screen_max.y }
                },
                -- South Edge
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=true, w=false}],
                    rect= { x1= screen_min.x, x2= screen_max.x, y1= screen_max.y, y2= screen_max.y }
                },
                -- West Edge
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=false, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_max.y }
                },
                -- NW Corner
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=false, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
                },
                -- NE Corner
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=false, w=false}],
                    rect= { x1= screen_max.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
                },
                -- SE Corner
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=true, w=false}],
                    rect= { x1= screen_max.x, x2= screen_max.x, y1= screen_max.y, y2= screen_max.y }
                },
                -- SW Corner
                {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=true, w=true}],
                    rect= { x1= screen_min.x, x2= screen_min.x, y1= screen_max.y, y2= screen_max.y }
                },
            }

            if dfhack.screen.inGraphicsMode() or ascii_fill then
                -- Fill inside
                table.insert(draw_queue, 1, {
                    pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=false, w=false}],
                    rect= { x1= screen_min.x + 1, x2= screen_max.x - 1, y1= screen_min.y + 1, y2= screen_max.y - 1 }
                })
            end
        end

        if frame_rect and not dfhack.screen.inGraphicsMode() then
            -- If in ASCII and a frame_rect was specified
            -- Draw the queue, avoiding the frame_rect
            drawOutsideOfScreenRect(draw_queue, frame_rect)
        else
            -- Draw the queue
            for _,draw_rect in pairs(draw_queue) do
                dfhack.screen.fillRect(draw_rect.pen, math.floor(draw_rect.rect.x1), math.floor(draw_rect.rect.y1), math.floor(draw_rect.rect.x2), math.floor(draw_rect.rect.y2), true)
            end
        end
    end
end

--================================--
--||        BoxSelection        ||--
--================================--
-- Allows for selecting a box

---@class BoxSelection.attrs: widgets.Window.attrs
---@field box? Box
---@field screen? gui.Screen
---@field tile_map? { pens: { key: dfhack.pen }, getPenKey: fun(nesw: { n: boolean, e: boolean, s: boolean, w: boolean }): any }
---@field avoid_rect? gui.ViewRect|fun():gui.ViewRect
---@field on_confirm? fun(box: Box)
---@field first_point? df.coord
---@field last_point? df.coord
---@field flat boolean
---@field ascii_fill boolean

---@class BoxSelection.attrs.partial: BoxSelection.attrs

---@class BoxSelection: widgets.Window, BoxSelection.attrs
BoxSelection = defclass(BoxSelection, widgets.Window)
BoxSelection.ATTRS {
    box=DEFAULT_NIL, -- For output
    screen=DEFAULT_NIL, -- Allows the DimensionsTooltip to be shown
    tile_map=TILE_MAP,
    avoid_rect=DEFAULT_NIL,
    on_confirm=DEFAULT_NIL,
    first_point=DEFAULT_NIL,
    last_point=DEFAULT_NIL,
    flat=false,
    ascii_fill=false,
}

function BoxSelection:init()
    self.frame = { w=0, h=0 }

    -- Set the cursor to the center of the screen
    local dims = dfhack.gui.getDwarfmodeViewDims()
    guidm.setCursorPos {
        x= df.global.window_x + (dims.map_x2 - dims.map_x1 + 1) // 2,
        y= df.global.window_y + (dims.map_y2 - dims.map_y1 + 1) // 2,
        z= df.global.window_z,
    }

    -- Show cursor
    df.global.game.main_interface.main_designation_selected = df.main_designation_type.TOGGLE_ENGRAVING -- Alternative: df.main_designation_type.REMOVE_CONSTRUCTION
    self.lastCursorPos = guidm.getCursorPos()

    if self.screen and self.screen.addviews then
        self.screen:addviews{
            widgets.DimensionsTooltip{
                view_id="dimensions_tooltip",
                get_anchor_pos_fn=function()
                    if self.first_point and self.flat then
                        return { x= self.first_point.x, y= self.first_point.y, z= df.global.window_z }
                    end
                    return self.first_point
                end,
            },
        }
    else
        qerror("No screen provided to BoxSelection, unable to display DimensionsTooltip")
    end
end

function BoxSelection:confirm()
    if self.first_point and self.last_point
        and dfhack.maps.isValidTilePos(self.first_point.x or -1, self.first_point.y or -1, self.first_point.z or -1)
        and dfhack.maps.isValidTilePos(self.last_point.x or -1, self.last_point.y or -1, self.last_point.z or -1)
    then
        self.box = Box{
            self.first_point,
            self.last_point
        }
        if type(self.on_confirm) == "function" then
            self.on_confirm(self.box)
        end
    end
end

function BoxSelection:clear()
    self.box = nil
    self.first_point = nil
    self.last_point = nil
end

function BoxSelection:onInput(keys)
    if BoxSelection.super.onInput(self, keys) then
        return true
    end
    if keys.LEAVESCREEN or keys._MOUSE_R then
        return false
    end

    local mousePos = dfhack.gui.getMousePos(true)
    local cursorPos = copyall(df.global.cursor)

    if keys.SELECT then
        if self.first_point and not self.last_point then
            if not self.flat or cursorPos.z == self.first_point.z then
                df.global.cursor.x = math.max(math.min(cursorPos.x, df.global.world.map.x_count - 1), 0)
                df.global.cursor.y = math.max(math.min(cursorPos.y, df.global.world.map.y_count - 1), 0)
                cursorPos = guidm.getCursorPos()
                self.last_point = cursorPos
                self:confirm()
            end
        elseif dfhack.maps.isValidTilePos(cursorPos.x, cursorPos.y, cursorPos.z) then
            self.first_point = self.first_point or cursorPos
        end

        return true
    end

    local avoid_rect = type(self.avoid_rect) == "function" and self.avoid_rect() or self.avoid_rect

    -- Get the position of the mouse in coordinates local to avoid_rect, if it's specified
    local mouseFramePos = avoid_rect and self:getMousePos(gui.ViewRect{
        rect=gui.mkdims_wh(
            avoid_rect.x1,
            avoid_rect.y1,
            avoid_rect.width,
            avoid_rect.height
        )
    })

    if keys._MOUSE_L and not mouseFramePos then
        -- If left click and the mouse is not in the avoid_rect
        if self.first_point and not self.last_point then
            if not self.flat or mousePos.z == self.first_point.z then
                local inBoundsMouse = {
                    x = math.max(math.min(mousePos.x, df.global.world.map.x_count - 1), 0),
                    y = math.max(math.min(mousePos.y, df.global.world.map.y_count - 1), 0),
                    z = mousePos.z,
                }
                self.last_point = inBoundsMouse
                self:confirm()
            end
        elseif dfhack.maps.isValidTilePos(mousePos.x, mousePos.y, mousePos.z) then
            self.first_point = self.first_point or mousePos
        end

        return true
    end

    -- Switch to the cursor if the cursor was moved (Excluding up and down a Z level)
    local filteredKeys = utils.clone(keys)
    filteredKeys["CURSOR_DOWN_Z"] = nil
    filteredKeys["CURSOR_UP_Z"] = nil
    self.useCursor = self.useCursor or guidm.getMapKey(filteredKeys)
        or (self.lastCursorPos and (self.lastCursorPos.x ~= cursorPos.x or self.lastCursorPos.y ~= cursorPos.y))
    self.lastCursorPos = cursorPos

    return false
end

function BoxSelection:onRenderFrame(dc, rect)
    -- Switch to cursor if the mouse is offscreen, or if it hasn't moved
    self.useCursor = (self.useCursor or (self.lastMousePos and (self.lastMousePos.x < 0 or self.lastMousePos.y < 0)))
        and self.lastMousePos.x == df.global.gps.precise_mouse_x and self.lastMousePos.y == df.global.gps.precise_mouse_y
    self.lastMousePos = { x= df.global.gps.precise_mouse_x, y= df.global.gps.precise_mouse_y }

    if self.screen and self.screen.subviews.dimensions_tooltip then
        self.screen.subviews.dimensions_tooltip.visible = not self.useCursor
    end

    if self.tile_map then
        local box = self.box

        if not box then
            local selectedPos = dfhack.gui.getMousePos(true)
            if self.useCursor or not selectedPos then
                selectedPos = copyall(df.global.cursor)
            end

            if self.flat and self.first_point then
                selectedPos.z = self.first_point.z
            end

            local inBoundsMouse = {
                x = math.max(math.min(selectedPos.x, df.global.world.map.x_count - 1), 0),
                y = math.max(math.min(selectedPos.y, df.global.world.map.y_count - 1), 0),
                z = selectedPos.z,
            }

            box = Box {
                self.first_point or selectedPos,
                self.last_point or (self.first_point and inBoundsMouse or selectedPos)
            }
        end

        if box then
            local avoid_rect = type(self.avoid_rect) == "function" and self.avoid_rect() or self.avoid_rect
            box:draw(self.tile_map, avoid_rect, self.ascii_fill)
        end
    end

    -- Don't call super.onRenderFrame, since this widget should not be drawn
end

function BoxSelection:hideCursor()
    -- Hide cursor
    df.global.game.main_interface.main_designation_selected = df.main_designation_type.NONE
end

--================================--
--||        SelectDialog        ||--
--================================--
-- Popup for selecting an item from a list, with a search bar

---@class CategoryChoice
---@field text string|widgets.LabelToken[]
---@field category string?
---@field key string?
---@field item_list (widgets.ListChoice|CategoryChoice)[]

ARROW = string.char(26)

SelectDialog = defclass(SelectDialog, gui.FramedScreen)

SelectDialog.ATTRS{
    focus_path = "SelectDialog",
    prompt = "Type or select a item from this list",
    base_category = "Any item",
    frame_style = gui.GREY_LINE_FRAME,
    frame_inset = 1,
    frame_title = "Select Item",
    item_list = DEFAULT_NIL, ---@type (widgets.ListChoice|CategoryChoice)[]
    on_select = DEFAULT_NIL,
    on_cancel = DEFAULT_NIL,
    on_close = DEFAULT_NIL,
}

function SelectDialog:init()
    self:addviews{
        widgets.Label{
            text = {
                self.prompt, '\n\n',
                'Category: ', { text = self:cb_getfield('category_str'), pen = COLOR_CYAN }
            },
            text_pen = COLOR_WHITE,
            frame = { l = 0, t = 0 },
        },
        widgets.Label{
            view_id = 'back',
            visible = false,
            text = { { key = 'LEAVESCREEN', text = ': Back' } },
            frame = { r = 0, b = 0 },
            auto_width = true,
        },
        widgets.FilteredList{
            view_id = 'list',
            not_found_label = 'No matching items',
            frame = { l = 0, r = 0, t = 4, b = 2 },
            icon_width = 2,
            on_submit = self:callback('onSubmitItem'),
            edit_on_char=function(c) return c:match('%l') end,
        },
        widgets.Label{
            text = { {
                key = 'SELECT', text = ': Select',
                disabled = function() return not self.subviews.list:canSubmit() end
            } },
            frame = { l = 0, b = 0 },
        }
    }

    self:initCategory(self.base_category, self.item_list)
end

function SelectDialog:getWantedFrameSize(rect)
    return math.max(self.frame_width or 40, #self.prompt), math.min(28, rect.height-8)
end

function SelectDialog:onDestroy()
    if self.on_close then
        self.on_close()
    end
end

function SelectDialog:initCategory(name, item_list)
    local choices = {}

    for _,value in pairs(item_list) do
        self:addItem(choices, value)
    end

    self:pushCategory(name, choices)
end

function SelectDialog:addItem(choices, item)
    if not item or not item.text then return end

    if item.item_list then
        table.insert(choices, {
            icon = ARROW, text = item.text, key = item.key,
            cb = function() self:initCategory(item.category or item.text, item.item_list) end
        })
    else
        table.insert(choices, {
            text = item.text,
            value = item.value or item.text
        })
    end
end

function SelectDialog:pushCategory(name, choices)
    if not self.back_stack then
        self.back_stack = {}
        self.subviews.back.visible = false
    else
        table.insert(self.back_stack, {
            category_str = self.category_str,
            all_choices = self.subviews.list:getChoices(),
            edit_text = self.subviews.list:getFilter(),
            selected = self.subviews.list:getSelected(),
        })
        self.subviews.back.visible = true
    end

    self.category_str = name
    self.subviews.list:setChoices(choices, 1)
end

function SelectDialog:onGoBack()
    local save = table.remove(self.back_stack)
    self.subviews.back.visible = (#self.back_stack > 0)

    self.category_str = save.category_str
    self.subviews.list:setChoices(save.all_choices)
    self.subviews.list:setFilter(save.edit_text, save.selected)
end

function SelectDialog:submitItem(value)
    self:dismiss()

    if self.on_select then
        self.on_select(value)
    end
end

function SelectDialog:onSubmitItem(idx, item)
    if item.cb then
        item:cb(idx)
    else
        self:submitItem(item.value)
    end
end

function SelectDialog:onInput(keys)
    if keys.LEAVESCREEN then
        if self.subviews.back.visible then
            self:onGoBack()
        else
            self:dismiss()
            if self.on_cancel then
                self.on_cancel()
            end
        end
        return true
    end
    self:inputToSubviews(keys)
    return true
end

--#endregion


--================================--
--||         CycleLabel         ||--
--================================--
-- More customizable CycleHotkeyLabel

CycleLabel = defclass(CycleLabel, widgets.CycleHotkeyLabel)
CycleLabel.ATTRS{
    base_label=DEFAULT_NIL,
    key_pen=DEFAULT_NIL
}

function CycleLabel:init()
    self:setOption(self.initial_option)
    self:updateOptionLabel()

    local on_change_fn = self.on_change
    self.on_change = function(value)
        self:updateOptionLabel()
        if on_change_fn then
            on_change_fn(value)
        end
    end
end

function CycleLabel:updateOptionLabel()
    local label = self:getOptionLabel()
    if type(label) ~= "table" then
        label = {{ text= label }}
    else
        label = copyall(label)
    end
    if self.base_label then
        if label[1] then
            label[1].gap=self.option_gap
        end
        table.insert(label, 1, type(self.base_label) == "string" and { text= self.base_label } or self.base_label)
    end
    table.insert(label, 1, self.key ~= nil and {key=self.key, key_pen=self.key_pen, key_sep=self.key_sep, on_activate=self:callback('cycle')} or {})
    table.insert(label, 1, self.key_back ~= nil and {key=self.key_back, key_sep='', width=0, on_activate=self:callback('cycle', true)} or {})
    self:setText(label)
end

--================================--
--||        OptionsPopup        ||--
--================================--
-- Popup for more detailed options

OptionsPopup = defclass(OptionsPopup, widgets.Window)
OptionsPopup.ATTRS {
    name = "options_popup",
    frame_title = 'More Options',
    frame = POPUP_UI_AREA,
    frame_inset={b=1, t=1},
}

function OptionsPopup:init()
    local optionViews = {}
    local width = self.frame.w - 3

    local makeUIChars = function(center_char1, center_char2)
        return {
            {218, 196,          196,          191},
            {179, center_char1, center_char2, 179},
            {192, 196,          196,          217},
        }
    end
    local makeUIPen = function(border_pen, center_pen)
        return {
            border_pen,
            {border_pen, center_pen, center_pen, border_pen},
            border_pen,
        }
    end

    self.values = {}
    local height_offset = 0
    for key,option in pairs(MORE_OPTIONS) do
        self.values[key] = -1
        local options = {
            {
                value=-1,
                label= makeInlineButtonLabelText{
                    left_specs={
                        chars={option.label},
                        pens=OPTION_SETTINGS[-1].pen,
                        pens_hover=UI_COLORS.HIGHLIGHTED,
                    },
                    right_specs={
                        chars=makeUIChars(OPTION_SETTINGS[-1].char1, OPTION_SETTINGS[-1].char2),
                        pens=makeUIPen(UI_COLORS.DESELECTED, OPTION_SETTINGS[-1].pen),
                        pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, OPTION_SETTINGS[-1].pen),
                        tileset=TILESET,
                        tileset_offset=OPTION_SETTINGS[-1].offset,
                        tileset_stride=TILESET_STRIDE,
                    },
                    width=width
                },
            },
            {
                value=0,
                label= makeInlineButtonLabelText{
                    left_specs={
                        chars={option.label},
                        pens=OPTION_SETTINGS[0].pen,
                        pens_hover=UI_COLORS.HIGHLIGHTED,
                    },
                    right_specs={
                        chars=makeUIChars(OPTION_SETTINGS[0].char1, OPTION_SETTINGS[0].char2),
                        pens=makeUIPen(UI_COLORS.DESELECTED, OPTION_SETTINGS[0].pen),
                        pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, OPTION_SETTINGS[0].pen),
                        tileset=TILESET,
                        tileset_offset=OPTION_SETTINGS[0].offset,
                        tileset_stride=TILESET_STRIDE,
                    },
                    width=width
                },
            },
        }

        local addOption = function(value, pen, char1, char2, offset)
            table.insert(options, #options, {
                value=value,
                label= makeInlineButtonLabelText{
                    left_specs={
                        chars={option.label},
                        pens=pen,
                        pens_hover=UI_COLORS.HIGHLIGHTED,
                    },
                    right_specs= {
                        chars=makeUIChars(char1, char2),
                        pens=makeUIPen(UI_COLORS.DESELECTED, pen),
                        pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, pen),
                        tileset=TILESET,
                        tileset_offset=offset,
                        tileset_stride=TILESET_STRIDE,
                    },
                    width=width
                },
            })
        end

        if option.overrides then
            for _, value in pairs(option.overrides) do
                addOption(value.value, value.pen, value.char1, value.char2, value.offset)
            end
        else
            addOption(1, OPTION_SETTINGS[1].pen, OPTION_SETTINGS[1].char1, OPTION_SETTINGS[1].char2, OPTION_SETTINGS[1].offset)
        end

        table.insert(optionViews,
            CycleLabel {
                frame={l=1,t=height_offset},
                initial_option=-1,
                options=options,
                on_change=function(value) self.values[key] = value end
            }
        )
        height_offset = height_offset + 3
    end

    self:addviews(optionViews)
end

--================================--
--||         TileConfig         ||--
--================================--
-- Tile config options

TileConfig = defclass(TileConfig, widgets.Widget)
TileConfig.ATTRS {
    data_lists=DEFAULT_NIL,
    on_change_shape=DEFAULT_NIL,
    on_change_mat=DEFAULT_NIL,
    on_change_stone=DEFAULT_NIL,
    on_change_vein_type=DEFAULT_NIL,
    on_change_special=DEFAULT_NIL,
    on_change_variant=DEFAULT_NIL,
}

function TileConfig:init()
    self.stone_enabled = false

    local function getListOther(short_list)
        for i=1, #short_list do
            if short_list[i].value == short_list.other.value then
                return short_list.other
            end
        end
        table.insert(short_list, short_list.other)
        short_list.other.label = OTHER_LABEL_FORMAT.first..short_list.other.label..OTHER_LABEL_FORMAT.last
        return short_list.other
    end

    self.other_shape = getListOther(self.data_lists.short_shape_list)
    self.other_mat = getListOther(self.data_lists.short_mat_list)
    self.other_special = getListOther(self.data_lists.short_special_list)

    local config_btn_width = #CONFIG_BUTTON
    local config_btn_l = UI_AREA.w - 2 - config_btn_width

    self:addviews {
        widgets.CycleHotkeyLabel {
            view_id="shape_cycle",
            frame={l=1, r=config_btn_width, t=0},
            key_back='CUSTOM_SHIFT_H',
            key='CUSTOM_H',
            label='Shape:',
            options=self.data_lists.short_shape_list,
            initial_option=-1,
            on_change=self.on_change_shape,
        },
        widgets.Divider { frame={t=2}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            view_id="mat_cycle",
            frame={l=1, r=config_btn_width, t=4},
            key_back='CUSTOM_SHIFT_J',
            key='CUSTOM_J',
            label='Material:',
            options=self.data_lists.short_mat_list,
            initial_option=-1,
            on_change=self.on_change_mat,
        },
        widgets.HotkeyLabel {
            view_id="stone_label",
            frame={l=3, t=6},
            key='CUSTOM_N',
            label={ text= "Stone:", pen=function() return self.stone_enabled and UI_COLORS.HIGHLIGHTED or UI_COLORS.DESELECTED end },
            enabled=function() return self.stone_enabled end,
            on_activate=function() self:openStonePopup() end
        },
        CycleLabel {
            view_id="vein_type_label",
            frame={l=3, t=8},
            key='CUSTOM_I',
            base_label={ text= "Vein Type:", pen=function() return self.stone_enabled and UI_COLORS.HIGHLIGHTED or UI_COLORS.DESELECTED end },
            enabled=function() return self.stone_enabled end,
            initial_option=-1,
            options=self.data_lists.vein_type_list,
            on_change=self.on_change_vein_type,
        },
        widgets.Divider { frame={t=10}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            view_id="special_cycle",
            frame={l=1, r=config_btn_width, t=12},
            key_back='CUSTOM_SHIFT_K',
            key='CUSTOM_K',
            label='Special:',
            options=self.data_lists.short_special_list,
            initial_option=-1,
            on_change=self.on_change_special,
        },
        widgets.Divider { frame={t=14}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            frame={l=1, t=16},
            key_back='CUSTOM_SHIFT_L',
            key='CUSTOM_L',
            label='Variant:',
            options=self.data_lists.variant_list,
            initial_option=-1,
            on_change=self.on_change_variant,
        },
        widgets.Divider { frame={t=18}, frame_style_l=false, frame_style_r=false, },
    }

    -- Advanced config buttons
    self:addviews {
        -- Shape
        widgets.Label {
            frame={l=config_btn_l, t=0},
            text=CONFIG_BUTTON,
            on_click=function() self:openShapePopup() end,
        },
        -- Material
        widgets.Label {
            frame={l=config_btn_l, t=4},
            text=CONFIG_BUTTON,
            on_click=function() self:openMaterialPopup() end,
        },
        -- Special
        widgets.Label {
            frame={l=config_btn_l, t=12},
            text=CONFIG_BUTTON,
            on_click=function() self:openSpecialPopup() end,
        },
    }

    self:changeStone(-1)
    self:setVisibility(self.visible)
end

function TileConfig:openShapePopup()
    SelectDialog {
        frame_title = "Shape Values",
        base_category = "Shape",
        item_list = self.data_lists.shape_list,
        on_select = function(item)
            self.other_shape.label = OTHER_LABEL_FORMAT.first..item.label..OTHER_LABEL_FORMAT.last
            self.other_shape.value = item.value
            self.subviews.shape_cycle.option_idx=#self.subviews.shape_cycle.options
        end,
    }:show()
end

function TileConfig:openMaterialPopup()
    SelectDialog {
        frame_title = "Material Values",
        base_category = "Material",
        item_list = self.data_lists.mat_list,
        on_select = function(item)
            self.other_mat.label = OTHER_LABEL_FORMAT.first..item.label..OTHER_LABEL_FORMAT.last
            self.other_mat.value = item.value
            self.subviews.mat_cycle.option_idx=#self.subviews.mat_cycle.options
        end,
    }:show()
end

function TileConfig:openSpecialPopup()
    SelectDialog {
        frame_title = "Special Values",
        base_category = "Special",
        item_list = self.data_lists.special_list,
        on_select = function(item)
            self.other_special.label = OTHER_LABEL_FORMAT.first..item.label..OTHER_LABEL_FORMAT.last
            self.other_special.value = item.value
            self.subviews.special_cycle.option_idx=#self.subviews.special_cycle.options
        end,
    }:show()
end

function TileConfig:openStonePopup()
    SelectDialog {
        frame_title = "Stone Types",
        base_category = "Stone",
        item_list = self.data_lists.stone_list,
        on_select = function(value) self:changeStone(value) end,
    }:show()
end

function TileConfig:changeStone(stone_index)
    local stone_option = self.data_lists.stone_dict[-1]
    if stone_index then
        stone_option = self.data_lists.stone_dict[stone_index]
        self.on_change_stone(stone_option.value)
    end

    local label = self.subviews.stone_label
    local base_label = copyall(label.label)
    base_label.key = label.key
    base_label.key_sep = label.key_sep
    base_label.on_activate = label.on_activate
    label:setText({
        base_label,
        { gap=1, text=stone_option.label, pen=stone_option.pen }
    })
end

function TileConfig:setStoneEnabled(bool)
    self.stone_enabled = bool
    if not bool then
        self.subviews.vein_type_label:setOption(self.subviews.vein_type_label.initial_option)
        self:changeStone(nil)
    end
    self.subviews.vein_type_label:updateOptionLabel()
end

function TileConfig:setVisibility(visibility)
    self.frame = visibility and { h=19 } or { h=0 }
    self.visible = visibility
end

--================================--
--||       TiletypeWindow       ||--
--================================--
-- Interface for editing tiles

TiletypeWindow = defclass(TiletypeWindow, widgets.Window)
TiletypeWindow.ATTRS {
    name = "tiletype_window",
    frame_title="Tiletypes",
    frame=UI_AREA,
    frame_inset={b=1, t=1},
    screen=DEFAULT_NIL,
    options_popup=DEFAULT_NIL,
    data_lists=DEFAULT_NIL,
}

function TiletypeWindow:init()
    self.cur_mode="paint"
    self.mode_description = ""
    self.cur_shape=-1
    self.cur_mat=-1
    self.cur_special=-1
    self.cur_variant=-1
    self.first_point=nil ---@type df.coord
    self.last_point=nil ---@type df.coord

    local makeUIChars = function(center_char1, center_char2)
        return {
            {218, 196,          196,          191},
            {179, center_char1, center_char2, 179},
            {192, 196,          196,          217},
        }
    end
    local makeUIPen = function(border_pen, center_pen)
        return {
            border_pen,
            {border_pen, center_pen, center_pen, border_pen},
            border_pen
        }
    end

    self:addviews {
        BoxSelection {
            view_id="box_selection",
            screen=self.screen,
            avoid_rect=function() return self.frame_rect end,
            on_confirm=function() self:confirm() end,
        },
        widgets.ResizingPanel {
            frame={t=0},
            autoarrange_subviews=true,
            autoarrange_gap=1,
            subviews={
                widgets.ButtonGroup {
                    frame={l=1},
                    button_specs={
                        {
                            chars=makeUIChars(MODE_SETTINGS["paint"].char1, MODE_SETTINGS["paint"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["paint"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["replace"].char1, MODE_SETTINGS["replace"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["replace"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["fill"].char1, MODE_SETTINGS["fill"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, {fg=UI_COLORS.DESELECTED,bg=UI_COLORS.DESELECTED2}),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, {fg=UI_COLORS.HIGHLIGHTED,bg=UI_COLORS.HIGHLIGHTED2}),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["fill"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["remove"].char1, MODE_SETTINGS["remove"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["remove"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                    },
                    button_specs_selected={
                        {
                            chars=makeUIChars(MODE_SETTINGS["paint"].char1, MODE_SETTINGS["paint"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["paint"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["replace"].char1, MODE_SETTINGS["replace"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["replace"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["fill"].char1, MODE_SETTINGS["fill"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, {fg=UI_COLORS.SELECTED,bg=UI_COLORS.SELECTED2}),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["fill"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["remove"].char1, MODE_SETTINGS["remove"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED2),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["remove"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                    },
                    key_back='CUSTOM_SHIFT_M',
                    key='CUSTOM_M',
                    label='Mode:',
                    options=MODE_LIST,
                    initial_option=MODE_SETTINGS[self.cur_mode].idx,
                    on_change=function(value)
                        self:setMode(value)
                    end,
                },
                widgets.WrappedLabel {
                    frame={l=1},
                    text_to_wrap=function() return self.mode_description end
                },
                widgets.Divider { frame={h=1}, frame_style_l=false, frame_style_r=false, },
                TileConfig {
                    view_id="tile_config",
                    data_lists=self.data_lists,
                    on_change_shape=function(value)
                        self.cur_shape = value
                    end,
                    on_change_mat=function(value)
                        if value == df.tiletype_material.STONE then
                            self.subviews.tile_config:setStoneEnabled(true)
                            self.subviews.tile_config:changeStone(self.cur_stone)
                        else
                            self.subviews.tile_config:setStoneEnabled(false)
                        end
                        self.cur_mat = value
                    end,
                    on_change_stone=function(value)
                        self.cur_stone = value
                    end,
                    on_change_vein_type=function(value)
                        self.cur_vein_type = value
                    end,
                    on_change_special=function(value)
                        self.cur_special = value
                    end,
                    on_change_variant=function(value)
                        self.cur_variant = value
                    end
                },
                widgets.HotkeyLabel {
                    frame={l=1},
                    key='STRING_A059',
                    label='More Options',
                    on_activate=function()
                        self.options_popup.visible = not self.options_popup.visible
                    end
                }
            }
        },
    }

    self:setMode(self.cur_mode)
end

function TiletypeWindow:setMode(mode)
    self.cur_mode = mode
    local settings = MODE_SETTINGS[mode]
    self.mode_description = settings.description
    self.subviews.tile_config:setVisibility(settings.config)
    if self.frame_parent_rect then
        self:updateLayout()
    end
end

function TiletypeWindow:confirm()
    local box = self.subviews.box_selection.box

    if box then
        local settings = MODE_SETTINGS[self.cur_mode]

        if self.cur_mode == "remove" then
            ---@type TileType
            local emptyTiletype = {
                shape = df.tiletype_shape.EMPTY,
                material = df.tiletype_material.AIR,
                special = df.tiletype_special.NORMAL,
            }
            box:iterate(function(pos)
                if settings.validator(pos) then
                    setTile(pos, emptyTiletype)
                end
            end)
        else
            local option_values = self.options_popup.values

            ---@type TileType
            local tiletype = {
                shape          = self.cur_shape,
                material       = self.cur_mat,
                special        = self.cur_special,
                variant        = self.cur_variant,
                hidden         = option_values.hidden,
                light          = option_values.light,
                subterranean   = option_values.subterranean,
                skyview        = option_values.skyview,
                aquifer        = option_values.aquifer,
                stone_material = self.cur_stone,
                vein_type      = self.cur_vein_type,
            }
            box:iterate(function(pos)
                if settings.validator(pos) then
                    setTile(pos, tiletype)
                end
            end)
        end

        self.subviews.box_selection:clear()
    end
end

function TiletypeWindow:onInput(keys)
    if TiletypeWindow.super.onInput(self, keys) then
        return true
    end
    if keys.LEAVESCREEN or keys._MOUSE_R then
        if self.options_popup.visible then
            self.options_popup.visible = false
            return true
        end
        return false
    end

    -- send movement and pause keys through
    return not (keys.D_PAUSE or guidm.getMapKey(keys))
end

function TiletypeWindow:onDismiss()
    self.subviews.box_selection:hideCursor()
end

--================================--
--||       TiletypeScreen       ||--
--================================--
-- The base UI element that contains the visual widgets

TiletypeScreen = defclass(TiletypeScreen, gui.ZScreen)
TiletypeScreen.ATTRS {
    focus_path = "tiletypes",
    pass_pause = true,
    pass_movement_keys = true,
    unrestricted = false
}

function TiletypeScreen:init()
    self.data_lists = self:generateDataLists()

    local options_popup = OptionsPopup{
        view_id="options_popup",
        visible=false
    }
    self:addviews {
        TiletypeWindow {
            view_id="main_window",
            screen=self,
            options_popup=options_popup,
            data_lists = self.data_lists
        },
        options_popup
    }
end

function TiletypeScreen:generateDataLists()
    local function itemColor(name)
        return name == "NONE" and UI_COLORS.VALUE_NONE or UI_COLORS.VALUE
    end

    local function getEnumLists(enum, short_dict)
        list = {}
        short_list = {}

        for i=enum._first_item, enum._last_item do
            local name = enum[i]
            if name then
                local item = { label= name, value= i, pen= itemColor(name) }
                table.insert(list, { text=name, value=item })
                if short_dict then
                    if short_dict.all or short_dict[i] then
                        table.insert(short_list, item)
                    elseif short_dict.other == i then
                        short_list.other = copyall(item)
                    end
                end
            end
        end

        return list, short_list
    end


    local data_lists = {}
    data_lists.shape_list, data_lists.short_shape_list = getEnumLists(df.tiletype_shape, CYCLE_VALUES.shape)
    data_lists.mat_list, data_lists.short_mat_list = getEnumLists(df.tiletype_material, CYCLE_VALUES.material)
    data_lists.special_list, data_lists.short_special_list = getEnumLists(df.tiletype_special, CYCLE_VALUES.special)
    _, data_lists.variant_list = getEnumLists(df.tiletype_variant, { all = true})

    data_lists.stone_list = { { text = "none", value = -1 } }
    data_lists.stone_dict = { [-1] = { label= "NONE", value= -1, pen= itemColor("NONE") } }
    for i,mat in ipairs(df.global.world.raws.inorganics) do
        if mat and mat.material
            and not mat.flags[df.inorganic_flags.SOIL_ANY]
            and not mat.material.flags[df.material_flags.IS_METAL]
            and (self.unrestricted or not mat.flags[df.inorganic_flags.GENERATED])
        then
            local state = mat.material.heat.melting_point <= 10015 and 1 or 0
            local name = mat.material.state_name[state]:gsub('^frozen ',''):gsub('^molten ',''):gsub('^condensed ','')
            if mat.flags[df.inorganic_flags.GENERATED] then
                -- Position 2 so that it is located immediately after "none"
                if not data_lists.stone_list[2].item_list then
                    table.insert(data_lists.stone_list, 2, { text = "generated materials", category = "Generated", item_list = {} })
                end
                table.insert(data_lists.stone_list[2].item_list, { text = name, value = i })
            else
                table.insert(data_lists.stone_list, { text = name, value = i })
            end
            data_lists.stone_dict[i] = { label= mat.id, value= i, pen= itemColor(mat.id) }
        end
    end

    _, data_lists.vein_type_list = getEnumLists(df.inclusion_type, { all = true})
    table.insert(data_lists.vein_type_list, 1, { label= "NONE", value= -1, pen= itemColor("NONE") }) -- Equivalent to CLUSTER
    for _, value in pairs(data_lists.vein_type_list) do
        value.label = {{ text= value.label, pen= value.pen }}
    end

    return data_lists
end

function TiletypeScreen:onDismiss()
    view = nil
    for _,value in pairs(self.subviews) do
        if value.onDismiss then
            value:onDismiss()
        end
    end
end

--#endregion

function main(...)
    local args = {...}
    local positionals = argparse.processArgsGetopt(args, {
        { 'f', 'unrestricted', handler = function() args.unrestricted = true end },
    })

    if not dfhack.isMapLoaded() then
        qerror("This script requires a fortress map to be loaded")
    end

    view = view and view:raise() or TiletypeScreen{ unrestricted = args.unrestricted }:show()
end

if not dfhack_flags.module then
    main(...)
end