do
    -- I can't believe that there's no easy way to make selection ignore tiles.
    -- Why the fuck does empty whitelist act as if there were no whitelist?!

    local tiles = {}
    for _, tile in pairs(data.raw["tile"]) do
        table.insert(tiles, tile.name)
    end

    local selection_tool = data.raw["selection-tool"]["railway_signalling_overseer_assume_correct_tool"]

    selection_tool.tile_filters = tiles
    selection_tool.tile_filter_mode = "blacklist"
    selection_tool.alt_tile_filters = tiles
    selection_tool.alt_tile_filter_mode = "blacklist"
end