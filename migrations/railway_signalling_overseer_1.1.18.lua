do
    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered{
            name={"correct-rail-signal"}
        }

        if global.railway_signalling_overseer_data.correct_signals == nil then
            global.railway_signalling_overseer_data.correct_signals = {}
        end
        local correct_signals = global.railway_signalling_overseer_data.correct_signals

        for _, entity in ipairs(entities) do
            local new_entity = surface.create_entity{
                name = "rail-signal",
                position = entity.position,
                direction = entity.direction,
                force = entity.force,
                spill = false,
                target = entity,
                fast_replace = true
            }
            correct_signals[new_entity.unit_number] = true
            script.register_on_entity_destroyed(new_entity)
        end
    end
end