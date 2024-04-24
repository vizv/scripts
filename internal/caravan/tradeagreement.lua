--@ module = true
local dlg = require('gui.dialogs')
local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

TradeAgreementOverlay = defclass(TradeAgreementOverlay, overlay.OverlayWidget)
TradeAgreementOverlay.ATTRS {
    desc = 'Adds select all/none functionality when requesting trade agreement items.',
    default_pos = { x = 45, y = -6 },
    default_enabled = true,
    viewscreens = 'dwarfmode/Diplomacy/Requests',
    frame = { w = 40, h = 4 },
    frame_style = gui.MEDIUM_FRAME,
    frame_background = gui.CLEAR_PEN,
}
local diplomacy = df.global.game.main_interface.diplomacy
local civilization = df.historical_entity.find(diplomacy.actor.civ_id)
local resources = civilization.resources
local lasttab, lastresult = -1, nil

local function TabCtor(pages, labelSingular, labelPlural, getCivResourceList, funcGetValue)
    return {
        pages = pages,
        labelSingular = labelSingular,
        labelPlural = labelPlural,
        getCivResourceList = getCivResourceList,
        funcGetValue = funcGetValue,
    }
end

local Tabs = {}

local function SquashMatIndexType(matList)
    local list = {}
    for key, value in pairs(matList.mat_index) do
        list[key] = { type = matList.mat_type[key], index = value }
    end
    return list
end
local function DecodeMatInfoFromSquash(mat)
    return dfhack.matinfo.decode(mat.type, mat.index).material.material_value
end

table.insert(Tabs, TabCtor({ 6, 7 }, "gem", "gems",
    function() return resources.gems end,
    function(id) return dfhack.matinfo.decode(0, id).material.material_value end)
)
table.insert(Tabs, TabCtor({ 0 }, "leather", "leathers",
    function() return SquashMatIndexType(resources.organic.leather) end,
    DecodeMatInfoFromSquash)
)
table.insert(Tabs, TabCtor({ 29 }, "meat", "meats",
    function() return SquashMatIndexType(resources.misc_mat.meat) end,
    DecodeMatInfoFromSquash)
)
table.insert(Tabs, TabCtor({ 62 }, "parchment", "parchments",
    function() return SquashMatIndexType(resources.organic.parchment) end,
    DecodeMatInfoFromSquash)
)

local function GetCurrentTabId()
    return diplomacy.taking_requests_tablist[diplomacy.taking_requests_selected_tab];
end

local function GetTab()
    local curtab = GetCurrentTabId()
    if (curtab == lasttab) then return lastresult end
    lasttab = curtab
    for _, tab in ipairs(Tabs) do
        for _, page in ipairs(tab.pages) do
            if page == curtab then
                lastresult = tab
                return tab
            end
        end
    end
    lastresult = nil
end

local function diplomacy_toggle_cat()
    local priority_idx = GetCurrentTabId()
    local priority = diplomacy.environment.dipev.sell_requests.priority[priority_idx]
    if #priority == 0 then return end
    local target_val = priority[0] == 0 and 4 or 0
    for i in ipairs(priority) do
        priority[i] = target_val
    end
end

local function OrderGemWithMinValue(matPrices, val)
    local priority_idx = GetCurrentTabId()

    local priority = diplomacy.environment.dipev.sell_requests.priority[priority_idx]
    for i in ipairs(priority) do
        if matPrices[i] == val then
            priority[i] = 4
        end
    end
end

local function GetCivMatPrices(tabSelected)
    local resource = tabSelected.getCivResourceList()
    local matPrices = {}
    local matValuesUnique = {}
    local filter = {}
    for civid, matid in pairs(resource) do
        local matPrice = tabSelected.funcGetValue(matid)
        matPrices[civid] = matPrice
        if not filter[matPrice] then
            local val = { value = matPrice, count = 1 }
            filter[matPrice] = val
            table.insert(matValuesUnique, val)
        else
            filter[matPrice].count = filter[matPrice].count + 1
        end
    end
    table.sort(matValuesUnique, function(a, b) return a.value < b.value end)
    return matPrices, matValuesUnique
end

local function ValueSelector()
    local currTab = GetTab()
    local matPrices, matValuesUnique = GetCivMatPrices(currTab)
    local list = {}
    for index, value in ipairs(matValuesUnique) do
        list[index] = tostring(value.value) ..
        " - " .. tostring(value.count) .. " " .. (value.count == 1 and currTab.labelSingular or currTab.labelPlural)
    end
    dlg.showListPrompt(
        "Select materials with base value", "",
        COLOR_WHITE,
        list,
        function(id, choice)
            OrderGemWithMinValue(matPrices, matValuesUnique[id].value)
        end
    )
end

function TradeAgreementOverlay:init()
    self:addviews {
        widgets.HotkeyLabel {
            frame = { t = 0, l = 0 },
            label = 'Select all/none',
            key = 'CUSTOM_CTRL_A',
            on_activate = diplomacy_toggle_cat,
        },
    }
    self:addviews {
        widgets.HotkeyLabel {
            frame = { t = 1, l = 0 },
            label = 'Select materials with value',
            key = 'CUSTOM_CTRL_M',
            on_activate = ValueSelector,
            visible = function() return GetTab() ~= nil end,
        },
    }
end
