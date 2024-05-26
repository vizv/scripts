--@ module = true
local plugin = require('plugins.tiletypes')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')
local utils = require('utils')
local guimat = require('gui.materials')

local UI_AREA = {r=4, t=19, w=35, h=35}
local POPUP_UI_AREA = {r=40, t=19, w=30, h=22}

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
    OPTION_ANY= COLOR_GRAY,
    OPTION_YES= COLOR_LIGHTGREEN,
    OPTION_NO= COLOR_RED,
    VALUE_NONE= COLOR_GRAY,
    VALUE= COLOR_YELLOW
}

local MORE_OPTIONS = {
    ["dig"]          = { label= "Designated" },
    ["hidden"]       = { label= "Hidden" },
    ["light"]        = { label= "Light" },
    ["subterranean"] = { label= "Subterranean" },
    ["skyview"]      = { label= "Skyview" },
    ["aquifer"]      = { label= "Aquifer" },
}

local MODE_LIST = {
    { label= "Place"   , value= "place"  , pen= COLOR_YELLOW     },
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
    [ "place"   ] = { idx= 1 , config= true  , description= "Place tiles"             , validator= function(pos) return true end                 },
    [ "replace" ] = { idx= 2 , config= true  , description= "Replace non-empty tiles" , validator= function(pos) return not isEmptyTile(pos) end },
    [ "fill"    ] = { idx= 3 , config= true  , description= "Fill in empty tiles"     , validator= function(pos) return isEmptyTile(pos) end     },
    [ "remove"  ] = { idx= 4 , config= false , description= "Remove selected tiles"   , validator= function(pos) return true end                 },
}

local shape_list = {}
local mat_list = {}
local stone_list = {}
local stone_dict = {}
local special_list = {}
local variant_list = {}
local vein_type_list = {}

---@class TileType
---@field shape? df.tiletype_shape
---@field material? df.tiletype_material
---@field special? df.tiletype_special
---@field variant? df.tiletype_variant
---@field dig? boolean
---@field hidden? boolean
---@field light? boolean
---@field subterranean? boolean
---@field skyview? boolean
---@field aquifer? boolean
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
        return value ~= nil and (value and 1 or 0) or -1
    end
    local tiletype = {
        shape          = toValidEnumValue(target.shape,    df.tiletype_shape,    df.tiletype_shape.NONE),
        material       = toValidEnumValue(target.material, df.tiletype_material, df.tiletype_material.NONE),
        special        = toValidEnumValue(target.special,  df.tiletype_special,  df.tiletype_special.NONE),
        variant        = toValidEnumValue(target.variant,  df.tiletype_variant,  df.tiletype_variant.NONE),
        dig            = toValidOptionValue(target.dig),
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

local function generateDataLists()
    local function itemColor(name)
        return name == "NONE" and UI_COLORS.VALUE_NONE or UI_COLORS.VALUE
    end

    shape_list = {}
    for i=df.tiletype_shape._first_item, df.tiletype_shape._last_item do
        local name = df.tiletype_shape[i]
        table.insert(shape_list, { label= name, value= i, pen= itemColor(name) })
    end
    mat_list = {}
    for i=df.tiletype_material._first_item, df.tiletype_material._last_item do
        local name = df.tiletype_material[i]
        table.insert(mat_list, { label= name, value= i, pen= itemColor(name) })
    end
    stone_list = { { text = "none", mat_type = -1, mat_index = -1 } }
    stone_dict = { [-1] = { label= "NONE", value= -1, pen= itemColor("NONE") } }
    for i,mat in ipairs(df.global.world.raws.inorganics) do
        if mat and mat.material
            and not mat.flags[df.inorganic_flags.SOIL_ANY]
            and not mat.material.flags[df.material_flags.IS_METAL]
        then
            local state = mat.material.heat.melting_point <= 10015 and 1 or 0
            local name = mat.material.state_name[state]:gsub('^frozen ',''):gsub('^molten ',''):gsub('^condensed ','')
            table.insert(stone_list, {
                text = name,
                material = mat.material,
                mat_type = 0,
                mat_index = i
            })
            stone_dict[i] = { label= mat.id, value= i, pen= itemColor(mat.id) }
        end
    end
    special_list = {}
    for i=df.tiletype_special._first_item, df.tiletype_special._last_item do
        local name = df.tiletype_special[i]
        table.insert(special_list, { label= name, value= i, pen= itemColor(name) })
    end
    variant_list = {}
    for i=df.tiletype_variant._first_item, df.tiletype_variant._last_item do
        local name = df.tiletype_variant[i]
        table.insert(variant_list, { label= name, value= i, pen= itemColor(name) })
    end
    vein_type_list = { { base_label= "NONE", value= -1, base_pen= itemColor("NONE") } } -- Equivalent to CLUSTER
    for i=df.inclusion_type._first_item, df.inclusion_type._last_item do
        local name = df.inclusion_type[i]
        if name then
            table.insert(vein_type_list, { base_label= name, value= i, base_pen= itemColor(name) })
        end
    end
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
    local label = copyall(self:getOptionLabel())
    if type(label) ~= "table" then
        label = {{ text= label }}
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
        self.values[key] = "Any"
        table.insert(optionViews,
            CycleLabel {
                frame={l=1,t=height_offset},
                initial_option="Any",
                options={
                    {
                        value="Any",
                        label= makeInlineButtonLabelText{
                            left_specs={
                                chars={option.label},
                                pens=UI_COLORS.OPTION_ANY,
                                pens_hover=UI_COLORS.HIGHLIGHTED,
                            },
                            right_specs={
                                chars=makeUIChars(" "," "),
                                pens=makeUIPen(UI_COLORS.DESELECTED, UI_COLORS.OPTION_ANY),
                                pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.OPTION_ANY),
                                asset={page='INTERFACE_BITS_SHARED', x=4, y=6},
                            },
                            width=width
                        },
                    },
                    {
                        value=true,
                        label= makeInlineButtonLabelText{
                            left_specs={
                                chars={option.label},
                                pens=UI_COLORS.OPTION_YES,
                                pens_hover=UI_COLORS.HIGHLIGHTED,
                            },
                            right_specs={
                                chars=makeUIChars("+","+"),
                                pens=makeUIPen(UI_COLORS.DESELECTED, UI_COLORS.OPTION_YES),
                                pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.OPTION_YES),
                                asset={page='INTERFACE_BITS_SHARED', x=0, y=6},
                            },
                            width=width
                        },
                    },
                    {
                        value=false,
                        label= makeInlineButtonLabelText{
                            left_specs={
                                chars={option.label},
                                pens=UI_COLORS.OPTION_NO,
                                pens_hover=UI_COLORS.HIGHLIGHTED,
                            },
                            right_specs={
                                chars=makeUIChars("X","X"),
                                pens=makeUIPen(UI_COLORS.DESELECTED, UI_COLORS.OPTION_NO),
                                pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.OPTION_NO),
                                asset={page='INTERFACE_BITS_SHARED', x=8, y=3},
                            },
                            width=width
                        },
                    },
                },
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
    on_change_shape=DEFAULT_NIL,
    on_change_mat=DEFAULT_NIL,
    on_change_stone=DEFAULT_NIL,
    on_change_vein_type=DEFAULT_NIL,
    on_change_special=DEFAULT_NIL,
    on_change_variant=DEFAULT_NIL,
}

function TileConfig:init()
    self.stone_enabled = false

    for _,value in pairs(vein_type_list) do
        value.label = {{ text= value.base_label, pen= value.base_pen } }
    end

    self:addviews {
        widgets.CycleHotkeyLabel {
            frame={l=1, t=0},
            key_back='CUSTOM_SHIFT_H',
            key='CUSTOM_H',
            label='Shape:',
            options=shape_list,
            initial_option=-1,
            on_change=self.on_change_shape,
        },
        widgets.Divider { frame={t=2}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            frame={l=1, t=4},
            key_back='CUSTOM_SHIFT_J',
            key='CUSTOM_J',
            label='Material:',
            options=mat_list,
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
            options=vein_type_list,
            on_change=self.on_change_vein_type,
        },
        widgets.Divider { frame={t=10}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            frame={l=1, t=12},
            key_back='CUSTOM_SHIFT_K',
            key='CUSTOM_K',
            label='Special:',
            options=special_list,
            initial_option=-1,
            on_change=self.on_change_special,
        },
        widgets.Divider { frame={t=14}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            frame={l=1, t=16},
            key_back='CUSTOM_SHIFT_L',
            key='CUSTOM_L',
            label='Variant:',
            options=variant_list,
            initial_option=-1,
            on_change=self.on_change_variant,
        },
        widgets.Divider { frame={t=18}, frame_style_l=false, frame_style_r=false, },
    }

    self:changeStone(-1)
    self:setVisibility(self.visible)
end

function TileConfig:openStonePopup()
    local dialog = guimat.MaterialDialog {
        frame_title = "Stone Types",
        use_inorganic = false,
        use_creature = false,
        use_plant = false,
        on_select = function(_,value) self:changeStone(value) end,
    }:show()

    dialog.subviews.list:setChoices(stone_list, 1)
    dialog.context_str= "Stone"
end

function TileConfig:setStoneEnabled(bool)
    self.stone_enabled = bool
    if not bool then
        self.subviews.vein_type_label:setOption(self.subviews.vein_type_label.initial_option)
        self:changeStone(nil)
    end
    self.subviews.vein_type_label:updateOptionLabel()
end

function TileConfig:changeStone(stone_index)
    local stone_option = stone_dict[-1]
    if stone_index then
        stone_option = stone_dict[stone_index]
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
    cur_mode="place",
    mode_description = "",
    cur_shape=-1,
    cur_mat=-1,
    cur_special=-1,
    cur_variant=-1,
    first_point=DEFAULT_NIL, ---@type df.coord
    last_point=DEFAULT_NIL, ---@type df.coord
}

function TiletypeWindow:init()
    local makeUIChars = function(center_char1, center_char2)
        return {
            {218, 196,          196,          191},
            {179, center_char1, center_char2, 179},
            {192, 196,          196,          217},
        }
    end
    local makeUIPen = function(border_pen, center_pen)
        --border_pen = type(border_pen) == "table" and border_pen or {fg=border_pen}
        --border_pen.tile_color=true
        center_pen = type(center_pen) == "table" and center_pen or {fg=center_pen}
        center_pen.tile_color=true
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
                            chars=makeUIChars(219, 219),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=0, y=0},
                            tiles_override={[2]={[2]=219, [3]=219}},
                        },
                        {
                            chars=makeUIChars(8, 7),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=0, y=0},
                            tiles_override={[2]={[2]=8, [3]=7}},
                        },
                        {
                            chars=makeUIChars(7, 8),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, {fg=UI_COLORS.DESELECTED,bg=UI_COLORS.DESELECTED2}),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, {fg=UI_COLORS.HIGHLIGHTED,bg=UI_COLORS.HIGHLIGHTED2}),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=0, y=0},
                            tiles_override={[2]={[2]=7, [3]=8}},
                        },
                        {
                            chars=makeUIChars(177, 177),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=0, y=0},
                            tiles_override={[2]={[2]=177, [3]=177}},
                        },
                    },
                    button_specs_selected={
                        {
                            chars=makeUIChars(219, 219),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=4, y=0},
                            tiles_override={[2]={[2]=219, [3]=219}},
                        },
                        {
                            chars=makeUIChars(8, 7),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=4, y=0},
                            tiles_override={[2]={[2]=8, [3]=7}},
                        },
                        {
                            chars=makeUIChars(7, 8),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, {fg=UI_COLORS.SELECTED,bg=UI_COLORS.SELECTED2}),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=4, y=0},
                            tiles_override={[2]={[2]=7, [3]=8}},
                        },
                        {
                            chars=makeUIChars(177, 177),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED2),
                            asset={page='INTERFACE_BITS_BUILDING_PLACEMENT', x=4, y=0},
                            tiles_override={[2]={[2]=177, [3]=177}},
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
            local parseOption = function(option)
                if option == "Any" then
                    return nil
                else
                    return option
                end
            end

            ---@type TileType
            local tiletype = {
                shape          = self.cur_shape,
                material       = self.cur_mat,
                special        = self.cur_special,
                variant        = self.cur_variant,
                dig            = parseOption(option_values.dig),
                hidden         = parseOption(option_values.hidden),
                light          = parseOption(option_values.light),
                subterranean   = parseOption(option_values.subterranean),
                skyview        = parseOption(option_values.skyview),
                aquifer        = parseOption(option_values.aquifer),
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
}

function TiletypeScreen:init()
    local options_popup = OptionsPopup{
        view_id="options_popup",
        visible=false
    }
    self:addviews {
        TiletypeWindow {
            view_id="main_window",
            screen=self,
            options_popup=options_popup
        },
        options_popup
    }
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

if dfhack_flags.module then return end

if not dfhack.isMapLoaded() then
    qerror("This script requires a fortress map to be loaded")
end

generateDataLists()
view = view and view:raise() or TiletypeScreen{}:show()