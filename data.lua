do
    data:extend({{
        type = "sprite",
        name = "railway_signalling_overseer_icon",
        filename = "__base__/graphics/icons/rail-chain-signal.png",
        width = 64,
        height = 64,
        scale = 0.5,
        priority = "extra-high-no-scale"
    }})

    local correct_rail_signal = util.table.deepcopy(data.raw["rail-signal"]["rail-signal"])
    correct_rail_signal.name = "correct-rail-signal"
    correct_rail_signal.localised_name = "Correct rail signal"
    correct_rail_signal.localised_description = "A rail signal that indicates to the Railway Signal Overseer mod that it should be assumed correct"
    correct_rail_signal.placeable_by = {{item="rail-signal", count=1}}
    data:extend({correct_rail_signal})

    data:extend({
        {
            type = "custom-input",
            name = "railway_signalling_overseer_assume_correct_tool",
            localised_name = "Correct rail signal marker",
            localised_description = "Marks a rail signal as correct for the Railway Signalling Overseer mod",
            key_sequence = "ALT + L",
            action = "spawn-item",
            item_to_spawn = "railway_signalling_overseer_assume_correct_tool",
        },
        {
            type = "selection-tool",
            name = "railway_signalling_overseer_assume_correct_tool",
            localised_name = "Correct rail signal marker",
            localised_description = "Marks a rail signal as correct for the Railway Signalling Overseer mod",
            icon = "__base__/graphics/icons/rail-signal.png",
            icon_size = 64,
            icon_mipmaps = 4,
            stack_size = 1,
            flags = { "hidden", "not-stackable", "spawnable" },
            entity_filters = { "rail-signal" },
            selection_mode = { "blueprint" },
            selection_color = { r = 1, g = 1 },
            selection_cursor_box_type = "entity",
            alt_selection_mode = { "any-entity" },
            alt_selection_color = { r = 1, g = 1, b = 0.5 },
            alt_selection_cursor_box_type = "entity",
            draw_label_for_cursor_render = true,
        },
        {
            type = "shortcut",
            name = "railway_signalling_overseer_assume_correct_tool",
            localised_name = "Correct rail signal marker",
            localised_description = "Marks a rail signal as correct for the Railway Signalling Overseer mod",
            icon = { filename = "__base__/graphics/icons/rail-signal.png", size = 64, mipmap_count = 4 },
            action = "spawn-item",
            item_to_spawn = "railway_signalling_overseer_assume_correct_tool",
            associated_control_input = "railway_signalling_overseer_assume_correct_tool",
        },
    })

end