local flows_to_delete = {}

function clearSmoke(flows)
    local success
    for i = #flows - 1, 0, -1 do
        local flow = flows[i]
        if flow.type == df.flow_type.Smoke then
            flows:erase(i)
            flows_to_delete[flow] = true
            success = true
        end
    end
    return success
end

clearSmoke(df.global.flows)

for _,block in pairs(df.global.world.map.map_blocks) do
    if clearSmoke(block.flows) then
        dfhack.maps.enableBlockUpdates(block, true)
    end
end

for flow,_ in pairs(flows_to_delete) do
    if flow then
        flow:delete()
    end
end