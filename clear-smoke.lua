local flowsToDelete = {}

function clearSmoke(flows)
    for i = #flows - 1, 0, -1 do
        local flow = flows[i]
        if flow.type == df.flow_type.Smoke then
            flows:erase(i)
            flowsToDelete[flow] = true
        end
    end
end

clearSmoke(df.global.flows)

for _, block in pairs(df.global.world.map.map_blocks) do
    clearSmoke(block.flows)
    dfhack.maps.enableBlockUpdates(block, true)
end

for flow,_ in pairs(flowsToDelete) do
    if flow then
        flow:delete()
    end
end
