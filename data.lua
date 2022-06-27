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
    correct_rail_signal.localised_name = "DEPRECATED"
    correct_rail_signal.localised_description = "DEPRECATED"
    correct_rail_signal.enabled = false
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
            alt_entity_filters = { "rail-signal" },
            selection_mode = { "blueprint" },
            alt_selection_mode = { "blueprint" },
            selection_color = { g = 1 },
            alt_selection_color = { r = 1 },
            selection_cursor_box_type = "entity",
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