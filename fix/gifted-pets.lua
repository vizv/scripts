-- Fixes pets gifted to another unit in Adventure Mode

local adventurer_record = df.nemesis_record.find(df.global.adventure.player_id)
local alreadyProcessed = {}

for i, nem_id in ipairs(adventurer_record.companions) do
    local companion_record = df.nemesis_record.find(nem_id)
    if companion_record.unit then
        local pet_owner = companion_record.unit.relationship_ids.Pet
        if pet_owner ~= -1 and pet_owner ~= adventurer_record.unit_id then
            local pet_owner_record = df.nemesis_record.find(pet_owner)
            -- pet_owner_record.histfig_links
            local site_links = pet_owner_record.figure.site_links

            -- If the person we're gifting the pet to is part of an active army
            if pet_owner_record.unit.enemy.army_controller_id ~= -1 and pet_owner_record.unit.enemy.army_controller then
                companion_record.unit.army_controller_id = pet_owner_record.unit.enemy.army_controller_id
                companion_record.unit.army_controller = pet_owner_record.unit.enemy.army_controller
            end

            companion_record.unit.relationship_ids.GroupLeader = pet_owner_record.unit_id
            companion_record.group_leader_id = pet_owner
            
            for u, link in ipairs(site_links) do
                local new_site_link = df.new(link)
                new_site_link.site = link.site
                new_site_link.sub_id = link.sub_id
                new_site_link.entity = link.entity

                companion_record.figure.site_links:insert('#', new_site_link)
            end
            -- pet_owner_record.companions:insert('#', companion_record.id)
            alreadyProcessed[tostring(companion_record.id)] = true
        end
    end
end

-- clean up our records
for index = #adventurer_record.companions-1, 0, -1 do
    if alreadyProcessed[tostring(adventurer_record.companions[index])] then
        adventurer_record.companions:erase(index)
    end
end