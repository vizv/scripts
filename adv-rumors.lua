-- Improve "Bring up specific incident or rumor", "Ask for Directions" and "Ask about Somebody" menus in Adventure mode

--@ module=true

local help = [====[

adv-rumors
==========
Improves the "Bring up specific incident or rumor" menu in Adventure mode.

- Adds all words to keywords for easier filtering/searching everywhere
- slay/slain/slew keywords for all relevant instances

]====]

local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

local adventure = df.global.game.main_interface.adventure

-- experimental, set this to 'true' to make the choices less verbose
local shortening = false

AdvRumorsOverlay = defclass(AdvRumorsOverlay, overlay.OverlayWidget)
AdvRumorsOverlay.ATTRS{
    desc='Adds keywords to conversation entries.',
    overlay_only=true,
    default_enabled=true,
    viewscreens='dungeonmode/Conversation',
}

function AdvRumorsOverlay:render()
    rumorUpdate()
end

OVERLAY_WIDGETS = {message=AdvRumorsOverlay}

-- CORE FUNCTIONS

-- Converts the choice's print string to a lua string
function choiceToString(choice)
    local line_table = {}
    for i, data in ipairs(choice.print_string.text) do
        table.insert(line_table, data.value)
    end
    return table.concat(line_table, "\n")
end

-- Renames the choice's print string based on string, respecting the newlines
function renameChoice(text, choice)
    -- Clear the string
    for i, data in ipairs(choice.print_string.text) do
        df.delete(data)
    end
    choice.print_string.text:resize(0)

    -- Split the string assuming \n is newline
    local line_table = string.split(text, "\n")
    for i, line in ipairs(line_table) do
        -- Create a df string for each line
        local line_ptr = df.new('string')
        line_ptr.value = line
        -- Insert it into the text data
        choice.print_string.text:insert('#', line_ptr)
    end
end

function addKeyword(choice, keyword)
    -- Prevent duplicate keywords
    for i, kword in ipairs(choice.key_word) do
        if kword.value == keyword then
            return
        end
    end
    local keyword_ptr = df.new('string')
    keyword_ptr.value = keyword
    choice.key_word:insert('#', keyword_ptr)
end

function addKeywordsForChoice(choice)
    local fulltext = choiceToString(choice)

    -- Special cases
    if string.find(fulltext, "slew") or string.find(fulltext, "slain") then
        addKeyword(choice, 'slew')
        addKeyword(choice, 'slay')
        addKeyword(choice, 'slain')
    end

    -- add a "sane" handling of you/your/me
    if string.find(fulltext, " you ") or string.find(fulltext, " your ") then
        addKeyword(choice, 'me')
    end

    -- Transform the whole thing into keywords barring blacklist
    local names_blacklist = utils.invert{"the", "a", "an", "of", "to", "attacked", "slew", "was", "slain", "by"}
    local title = fulltext
    if title:find('%(') then
        title = title:sub(1, title:find('%(') - 1)
    end
    local new_keywords, keywords_set = {}, utils.invert(getKeywords(choice))
    for word in text:gmatch('[%w(]+') do
        if word:startswith('(') then break end
        word = dfhack.toSearchNormalized(word)
        if not ignore_words[word] and not keywords_set[word] then
            table.insert(new_keywords, word)
            keywords_set[word] = true
        end
    end
    addKeywords(choice, new_keywords)
end

-- Returns a string that shortens the options
function shortenChoiceText(text)
    return text
        :gsub("Summarize the conflict in which +", "A fight where ")
        :gsub("This occurred +", "")
        :gsub("Bring up +", "")
        :gsub("Spread rumor of +", "")
        :gsub("Ask about +", "")
        :gsub("Ask for directions to +", "where is ")
        :gsub("Ask for the whereabouts of +", "where is ")
end

function shortenChoice(choice)
    local fulltext = choiceToString(choice)
    fulltext = shortenChoiceText(fulltext)
    renameChoice(fulltext, choice)
end

-- Condense the rumor system choices
function rumorUpdate()
    for i, choice in ipairs(adventure.conversation.conv_choice_info) do
        if shortening and adventure.conversation.conv_actce.state ~= df.conversation_state_type.MAIN then
            shortenChoice(choice)
        end
        addKeywordsForChoice(choice)
    end
end
