local gui = require('gui')
local utils = require('utils')
local widgets = require('gui.widgets')

--
-- Sitemap
--

Sitemap = defclass(Sitemap, widgets.Window)
Sitemap.ATTRS {
    frame_title='Sitemap',
    frame={w=47, r=2, t=18, h=23},
    resizable=true,
}

local function get_desc(loc)
    if df.abstract_building_hospitalst:is_instance(loc) then
        return 'Hospital', COLOR_WHITE
    elseif df.abstract_building_inn_tavernst:is_instance(loc) then
        return 'Tavern', COLOR_LIGHTRED
    elseif df.abstract_building_libraryst:is_instance(loc) then
        return 'Library', COLOR_BLUE
    elseif df.abstract_building_guildhallst:is_instance(loc) then
        local prof = df.profession[loc.contents.profession]
        if not prof then return 'Guildhall', COLOR_MAGENTA end
        return ('%s guildhall'):format(dfhack.capitalizeStringWords(dfhack.lowerCp437(prof))), COLOR_MAGENTA
    elseif df.abstract_building_templest:is_instance(loc) then
        local is_deity = loc.deity_type == df.temple_deity_type.Deity
        local id = loc.deity_data[is_deity and 'Deity' or 'Religion']
        local entity = is_deity and df.historical_figure.find(id) or df.historical_entity.find(id)
        local desc = 'Temple'
        if not entity then return desc, COLOR_YELLOW end
        local name = dfhack.TranslateName(entity.name, true)
        if #name > 0 then
            desc = ('%s of %s'):format(desc, name)
        end
        return desc, COLOR_YELLOW
    end
end

local function get_label(loc, zones)
    local tokens = {}
    table.insert(tokens, dfhack.TranslateName(loc.name, true))
    local desc, pen = get_desc(loc)
    if desc then
        table.insert(tokens, ' (')
        table.insert(tokens, {
            text=desc,
            pen=pen,
        })
        table.insert(tokens, ')')
    end
    if #zones > 1 then
        table.insert(tokens, ' [')
        table.insert(tokens, ('%d zones'):format(#zones))
        table.insert(tokens, ']')
    end
    return tokens
end

local function get_choices(site)
    local choices = {}
    if not site then return choices end
    for _,loc in ipairs(site.buildings) do
        local zones = loc.contents.building_ids
        if #zones == 0 then goto continue end
        table.insert(choices, {
            text=get_label(loc, zones),
            data={
                -- clone since an adventurer might wander off the site
                -- and the vector gets deallocated
                zones=utils.clone(zones),
                next_idx=1,
            },
        })
        ::continue::
    end
    return choices
end

local function zoom_to(_, choice)
    local data = choice.data
    if #data.zones == 0 then return end
    if data.next_idx > #data.zones then data.next_idx = 1 end
    local bld = df.building.find(data.zones[data.next_idx])
    if bld then
        dfhack.gui.revealInDwarfmodeMap(
            xyz2pos(bld.centerx, bld.centery, bld.z), true, true)
    end
    data.next_idx = data.next_idx % #data.zones + 1
end

function Sitemap:init()
    local site = dfhack.world.getCurrentSite() or false
    local choices = get_choices(site)

    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text='Locations at this site:',
            visible=site,
        },
        widgets.Label{
            frame={t=0, l=0},
            text='Please enter a site to see locations.',
            text_pen=COLOR_LIGHTRED,
            visible=not site,
        },
        widgets.Label{
            frame={t=2, l=0},
            text={
                'No temples, guildhalls, hospitals, taverns,', NEWLINE,
                'or libraries found at this site.'
            },
            text_pen=COLOR_LIGHTRED,
            visible=site and #choices == 0,
        },
        widgets.FilteredList{
            frame={t=2, b=5},
            on_submit=zoom_to,
            choices=choices,
            visible=#choices > 0,
        },
        widgets.Divider{
            frame={b=3, h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Label{
            frame={b=0, l=0},
            text={
                'Click on a name or hit ', {text='Enter', pen=COLOR_LIGHTGREEN}, NEWLINE,
                'to zoom to the selected location.'
            },
            visible=site and #choices > 0,
        },
    }
end

--
-- SitemapScreen
--

SitemapScreen = defclass(SitemapScreen, gui.ZScreen)
SitemapScreen.ATTRS {
    focus_path='sitemap',
    pass_movement_keys=true,
}

function SitemapScreen:init()
    self:addviews{Sitemap{}}
end

function SitemapScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a map to be loaded')
end

view = view and view:raise() or SitemapScreen{}:show()
