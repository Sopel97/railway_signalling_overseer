do
    local mod_gui = require("mod-gui")

    local UPDATE_PERIOD_ALLOWED_VALUES = {
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        15, 20, 25, 30, 35, 40, 45, 50, 55, 60,
        70, 80, 90, 100, 110, 120,
        180, 240, 300, 360, 420, 480, 540, 600
    }

    local MAX_RAIL_SCAN_RANGE = 6*32
    local DEFAULT_RAIL_SCAN_RANGE = 3*32

    -- A rough estimate. We cannot get the actual zoom so we
    -- need to use an upper bound. This is used to determine
    -- player view area so that we can get enough rails into the graph.
    local MIN_ZOOM = 0.28

    local rail_traffic_direction = {
        indeterminate = 0,
        forward = 1,
        backward = 2,
        universal = 3
    }

    local rail_signal_type = {
        none = 0,
        normal = 1,
        chain = 2
    }

    local partial_update_type = {
        none = 0,
        create_graph = 1,
        label_graph_and_render = 2,
        all = 3
    }

    local graph_node_growth_direction = {
        forward = 0,
        backward = 1,
        both = 2
    }

    local segment_overlay_position = {
        back = 0,
        front = 1
    }

    local ALL_RAIL_DIRECTIONS = {
        defines.rail_direction.front,
        defines.rail_direction.back,
    }

    local ALL_RAIL_CONNECTION_DIRECTIONS = {
        defines.rail_connection_direction.left,
        defines.rail_connection_direction.straight,
        defines.rail_connection_direction.right
    }

    local STRAIGHT_RAIL_DIR_TO_ORIENT = {
        [defines.direction.north] = 0.125 * 6,
        [defines.direction.south] = 0.125 * 2,
        [defines.direction.east] = 0.125 * 0,
        [defines.direction.west] = 0.125 * 4,
        [defines.direction.southeast] = 0.125 * 7,
        [defines.direction.northeast] = 0.125 * 5,
        [defines.direction.southwest] = 0.125 * 1,
        [defines.direction.northwest] = 0.125 * 3,
    }

    local STRAIGHT_RAIL_DIR_TO_OFFSET = {
        [defines.direction.north] = {0, 0},
        [defines.direction.south] = {0, 0},
        [defines.direction.east] = {0, 0},
        [defines.direction.west] = {0, 0},
        [defines.direction.southeast] = {0.5, 0.5},
        [defines.direction.northeast] = {0.5, -0.5},
        [defines.direction.southwest] = {-0.5, 0.5},
        [defines.direction.northwest] = {-0.5, -0.5},
    }

    local STRAIGHT_RAIL_DIR_TO_POLYGON_VERTICES = {
        [defines.direction.north] = {
            {target={x=-0.6, y=-1}},
            {target={x=-0.6, y=1}},
            {target={x=0.6, y=-1}},
            {target={x=0.6, y=1}},
        },
        [defines.direction.south] = {
            {target={x=-0.6, y=-1}},
            {target={x=-0.6, y=1}},
            {target={x=0.6, y=-1}},
            {target={x=0.6, y=1}},
        },
        [defines.direction.east] = {
            {target={x=-1, y=-0.43}},
            {target={x=-1, y=0.43}},
            {target={x=1, y=-0.43}},
            {target={x=1, y=0.43}},
        },
        [defines.direction.west] = {
            {target={x=-1, y=-0.43}},
            {target={x=-1, y=0.43}},
            {target={x=1, y=-0.43}},
            {target={x=1, y=0.43}},
        },
        [defines.direction.southeast] = {
            {target={x=-0.5, y=0.77}},
            {target={x=0.5, y=1.2}},
            {target={x=0.5, y=-0.23}},
            {target={x=1.5, y=0.2}},
        },
        [defines.direction.northeast] = {
            {target={x=0.5, y=-1.23}},
            {target={x=-0.5, y=-0.8}},
            {target={x=1.5, y=-0.23}},
            {target={x=0.5, y=0.2}},
        },
        [defines.direction.southwest] = {
            {target={x=-0.5, y=-0.23}},
            {target={x=-1.5, y=0.2}},
            {target={x=0.5, y=0.78}},
            {target={x=-0.5, y=1.2}},
        },
        [defines.direction.northwest] = {
            {target={x=-1.5, y=-0.23}},
            {target={x=-0.5, y=0.2}},
            {target={x=-0.5, y=-1.23}},
            {target={x=0.5, y=-0.8}},
        },
    }

    local CURVED_RAIL_DIR_TO_POLYGON_VERTICES = {
        [defines.direction.north] = {
            {target={x=-2.5, y=-2.77}},
            {target={x=-1.5, y=-3.2}},
            {target={x=-1.58, y=-1.81}},
            {target={x=-0.57, y=-2.21}},
            {target={x=-0.91, y=-0.88}},
            {target={x=0.12, y=-1.31}},
            {target={x=-0.42, y=0.07}},
            {target={x=0.71, y=-0.23}},
            {target={x=0.12, y=1.45}},
            {target={x=1.26, y=1.31}},
            {target={x=0.33, y=2.48}},
            {target={x=1.48, y=2.38}},
            {target={x=0.4, y=4}},
            {target={x=1.6, y=4}},
        },
        [defines.direction.south] = {
            {target={x=2.5, y=2.77}},
            {target={x=1.5, y=3.2}},
            {target={x=1.58, y=1.81}},
            {target={x=0.57, y=2.21}},
            {target={x=0.91, y=0.88}},
            {target={x=-0.12, y=1.31}},
            {target={x=0.42, y=-0.07}},
            {target={x=-0.71, y=0.23}},
            {target={x=-0.12, y=-1.45}},
            {target={x=-1.26, y=-1.31}},
            {target={x=-0.33, y=-2.48}},
            {target={x=-1.48, y=-2.38}},
            {target={x=-0.4, y=-4}},
            {target={x=-1.6, y=-4}},
        },
        [defines.direction.east] = {
            {target={x=-4, y=0.57}},
            {target={x=-4, y=1.43}},
            {target={x=-2.56, y=0.48}},
            {target={x=-2.39, y=1.31}},
            {target={x=-1.4, y=0.25}},
            {target={x=-0.97, y=1}},
            {target={x=-0.21, y=-0.22}},
            {target={x=0.37, y=0.52}},
            {target={x=0.98, y=-0.89}},
            {target={x=1.71, y=-0.26}},
            {target={x=1.84, y=-1.54}},
            {target={x=2.7, y=-1.04}},
            {target={x=2.5, y=-2.23}},
            {target={x=3.5, y=-1.8}},
        },
        [defines.direction.west] = {
            {target={x=4, y=-0.57}},
            {target={x=4, y=-1.43}},
            {target={x=2.56, y=-0.48}},
            {target={x=2.39, y=-1.31}},
            {target={x=1.4, y=-0.25}},
            {target={x=0.97, y=-1}},
            {target={x=0.21, y=0.22}},
            {target={x=-0.37, y=-0.52}},
            {target={x=-0.98, y=0.89}},
            {target={x=-1.71, y=0.26}},
            {target={x=-1.84, y=1.54}},
            {target={x=-2.7, y=1.04}},
            {target={x=-2.5, y=2.23}},
            {target={x=-3.5, y=1.8}},
        },
        [defines.direction.southeast] = {
            {target={x=-4, y=-0.57}},
            {target={x=-4, y=-1.43}},
            {target={x=-2.56, y=-0.48}},
            {target={x=-2.39, y=-1.31}},
            {target={x=-1.4, y=-0.25}},
            {target={x=-0.97, y=-1}},
            {target={x=-0.21, y=0.22}},
            {target={x=0.37, y=-0.52}},
            {target={x=0.98, y=0.89}},
            {target={x=1.71, y=0.26}},
            {target={x=1.84, y=1.54}},
            {target={x=2.7, y=1.04}},
            {target={x=2.5, y=2.23}},
            {target={x=3.5, y=1.8}},
        },
        [defines.direction.northeast] = {
            {target={x=2.5, y=-2.8}},
            {target={x=1.5, y=-3.23}},
            {target={x=1.58, y=-1.81}},
            {target={x=0.57, y=-2.21}},
            {target={x=0.91, y=-0.88}},
            {target={x=-0.12, y=-1.31}},
            {target={x=0.42, y=0.07}},
            {target={x=-0.71, y=-0.23}},
            {target={x=-0.12, y=1.45}},
            {target={x=-1.26, y=1.31}},
            {target={x=-0.33, y=2.48}},
            {target={x=-1.48, y=2.38}},
            {target={x=-0.4, y=4}},
            {target={x=-1.6, y=4}},
        },
        [defines.direction.southwest] = {
            {target={x=-2.5, y=2.77}},
            {target={x=-1.5, y=3.2}},
            {target={x=-1.58, y=1.81}},
            {target={x=-0.57, y=2.21}},
            {target={x=-0.91, y=0.88}},
            {target={x=0.12, y=1.31}},
            {target={x=-0.42, y=-0.07}},
            {target={x=0.71, y=0.23}},
            {target={x=0.12, y=-1.45}},
            {target={x=1.26, y=-1.31}},
            {target={x=0.33, y=-2.48}},
            {target={x=1.48, y=-2.38}},
            {target={x=0.4, y=-4}},
            {target={x=1.6, y=-4}},
        },
        [defines.direction.northwest] = {
            {target={x=4, y=0.57}},
            {target={x=4, y=1.43}},
            {target={x=2.56, y=0.48}},
            {target={x=2.39, y=1.31}},
            {target={x=1.4, y=0.25}},
            {target={x=0.97, y=1}},
            {target={x=0.21, y=-0.22}},
            {target={x=-0.37, y=0.52}},
            {target={x=-0.98, y=-0.89}},
            {target={x=-1.71, y=-0.26}},
            {target={x=-1.84, y=-1.54}},
            {target={x=-2.7, y=-1.04}},
            {target={x=-2.5, y=-2.23}},
            {target={x=-3.5, y=-1.8}},
        },
    }

    local CURVED_RAIL_DIR_TO_ORIENT = {
        [defines.direction.north] = 0.125 * 1.5,
        [defines.direction.northeast] = 0.125 * 2.5,
        [defines.direction.east] = 0.125 * 3.5,
        [defines.direction.southeast] = 0.125 * 4.5,
        [defines.direction.south] = 0.125 * 5.5,
        [defines.direction.southwest] = 0.125 * 6.5,
        [defines.direction.west] = 0.125 * 7.5,
        [defines.direction.northwest] = 0.125 * 0.5
    }

    local COLOR_GOOD = {0, 1, 0}
    local COLOR_SUGGESTION = {1, 1, 0}
    local COLOR_BAD = {1, 0, 0}

    --------- GUI HANDLING

    local function setup_mod_globals(player)
        if global.railway_signalling_overseer_data == nil then
            global.railway_signalling_overseer_data = {}
        end

        if global.railway_signalling_overseer_data[player.index] == nil then
            global.railway_signalling_overseer_data[player.index] = {}
        end

        local old_data = global.railway_signalling_overseer_data[player.index]

        global.railway_signalling_overseer_data[player.index] = {
            train_length = old_data.train_length or 6,
            update_period = old_data.update_period or 60,
            enabled = old_data.enabled or true,
            suggestions_enabled = old_data.suggestions_enabled or false,
            only_show_problems = old_data.only_show_problems or false,
            renderings = old_data.renderings or {},
            initial_rail_scan_range = old_data.initial_rail_scan_range or DEFAULT_RAIL_SCAN_RANGE,
            show_as_alerts = old_data.show_as_alerts or false,
            highlight_rails = old_data.highlight_rails or false,
            partial_update_data = {
                segment_graph = nil
            }
        }
    end

    local function setup_mod_gui(player)
        local frame_flow = mod_gui.get_button_flow(player)
        local mod_gui_button = frame_flow["railway_signalling_overseer_toggle_config_window_button"]

        if mod_gui_button ~= nil then
            mod_gui_button.destroy()
        end

        frame_flow.add{
            type = "sprite-button",
            name = "railway_signalling_overseer_toggle_config_window_button",
            tooltip = "Railway Signalling Overseer",
            sprite = "railway_signalling_overseer_icon",
            style = mod_gui.button_style,
            mouse_button_filter = {"left"}
        }
    end

    local function get_config(player)
        return global.railway_signalling_overseer_data[player.index]
    end

    local function get_partial_update_type(player, tick)
        local data = global.railway_signalling_overseer_data[player.index]
        if not data.enabled then
            return partial_update_type.none
        end

        if data.update_period == 1 then
            return partial_update_type.all
        end

        local mod = tick % data.update_period
        if mod == 0 then
            return partial_update_type.create_graph
        elseif mod == math.floor(data.update_period / 2) then
            return partial_update_type.label_graph_and_render
        end

        return partial_update_type.none
    end

    local function update_period_to_slider_value(update_period)
        for i, up in ipairs(UPDATE_PERIOD_ALLOWED_VALUES) do
            if up == update_period then
                return i
            end
        end
        return nil
    end

    local function get_gui_element_by_name_recursive(element, name)
        if element.name == name then
            return element
        end

        for _, child in ipairs(element.children) do
            local found = get_gui_element_by_name_recursive(child, name)
            if found ~= nil then
                return found
            end
        end

        return nil
    end

    local function get_config_gui_element(player, name)
        local root = player.gui.left["railway_signalling_overseer_config_window"]
        if root == nil then
            return nil
        end
        return get_gui_element_by_name_recursive(root, name)
    end

    local function toggle_config_window(player)
        local data = global.railway_signalling_overseer_data[player.index]

        if player.gui.left["railway_signalling_overseer_config_window"] == nil then
            local frame = player.gui.left.add{
                type = "frame",
                caption = "Railway Signalling Overseer",
                direction = "vertical",
                name = "railway_signalling_overseer_config_window",
            }

            local flow = frame.add{type = "flow", direction = "vertical"}

            flow.add{
                type = "checkbox",
                caption = "Enable automatic updates",
                name = "railway_signalling_overseer_enable_checkbox",
                state = data.enabled
            }

            flow.add{
                type = "checkbox",
                caption = "Only show problems",
                name = "railway_signalling_overseer_only_show_problems_checkbox",
                state = data.only_show_problems
            }

            flow.add{
                type = "checkbox",
                caption = "Show problems as alerts",
                name = "railway_signalling_overseer_show_as_alerts_checkbox",
                state = data.show_as_alerts
            }

            flow.add{
                type = "checkbox",
                caption = "Highlight rails",
                name = "railway_signalling_overseer_highlight_rails_checkbox",
                state = data.highlight_rails
            }

            flow.add{
                type = "checkbox",
                caption = "Enable suggestions",
                name = "railway_signalling_overseer_enable_suggestions_checkbox",
                state = data.suggestions_enabled
            }

            flow.add{
                type = "line"
            }

            flow.add{
                type = "label",
                caption = "Initial scan range (tiles): " .. tostring(data.initial_rail_scan_range),
                name = "railway_signalling_overseer_initial_scan_range_label"
            }
            flow.add{
                type = "slider",
                name = "railway_signalling_overseer_initial_scan_range_slider",
                value = data.initial_rail_scan_range,
                value_step = 1,
                minimum_value = 32,
                maximum_value = MAX_RAIL_SCAN_RANGE,
                discrete_slider = true,
                discrete_values = true
            }

            flow.add{
                type = "line"
            }

            flow.add{
                type = "label",
                caption = "Update period (ticks): " .. tostring(data.update_period),
                name = "railway_signalling_overseer_update_period_label"
            }
            flow.add{
                type = "slider",
                name = "railway_signalling_overseer_update_period_slider",
                value = update_period_to_slider_value(data.update_period),
                value_step = 1,
                minimum_value = 1,
                maximum_value = #UPDATE_PERIOD_ALLOWED_VALUES,
                discrete_slider = true,
                discrete_values = true
            }
            flow.add{
                type = "button",
                caption = "Run single update",
                name = "railway_signalling_overseer_run_single_update_button"
            }
            local b = flow.add{
                type = "button",
                caption = "Analyze WHOLE MAP",
                name = "railway_signalling_overseer_run_single_update_whole_map_button"
            }
            b.style.font_color = {1, 0, 0}
            flow.add{
                type = "button",
                caption = "Clear overlays",
                name = "railway_signalling_overseer_clear_overlays_button"
            }

            flow.add{
                type = "line"
            }

            flow.add{
                type = "label",
                caption = "Train length (wagons): " .. tostring(data.train_length),
                name = "railway_signalling_overseer_train_length_label"
            }
            flow.add{
                type = "slider",
                name = "railway_signalling_overseer_train_length_slider",
                value = data.train_length,
                value_step = 1,
                minimum_value = 1,
                maximum_value = 20,
                discrete_slider = true,
                discrete_values = true
            }

            data.config_window = frame
        else
            player.gui.left["railway_signalling_overseer_config_window"].destroy()
        end
    end

    local function close_config_window(player)
        local wnd = player.gui.left["railway_signalling_overseer_config_window"]
        if wnd ~= nil then
            wnd.destroy()
        end
    end

    local function reinitialize()
        global.railway_signalling_overseer_data = {}
        for _, player in pairs(game.players) do
            setup_mod_globals(player)
            setup_mod_gui(player)
            close_config_window(player)
        end
    end

    --------- END OF GUI HANDLING

    --------- LOGIC

    local function table_concat(t1, t2)
        local t = {}
        for _, a in ipairs(t1) do
            table.insert(t, a)
        end
        for _, a in ipairs(t2) do
            table.insert(t, a)
        end
        return t
    end

    function deepcopy(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key)] = deepcopy(orig_value)
            end
            setmetatable(copy, deepcopy(getmetatable(orig)))
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end

    function shallowcopy(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[orig_key] = orig_value
            end
            setmetatable(copy, getmetatable(orig))
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end

    local function to_str(obj)
        if obj == nil then
            return "nil"
        else
            return tostring(obj)
        end
    end

    local function get_area_around_the_player(player, range_x)
        local x = player.position.x
        local y = player.position.y
        local resx = player.display_resolution.width
        local resy = player.display_resolution.height
        local range_y = range_x * (resy / resx)
        local top_left_x = x - range_x
        local top_left_y = y - range_y
        local bottom_right_x = x + range_x
        local bottom_right_y = y + range_y
        return {left_top={top_left_x, top_left_y}, right_bottom={bottom_right_x, bottom_right_y}}
    end

    local function get_signals_in_area(surface, area)
        return surface.find_entities_filtered{
            area=area,
            type={"rail-signal", "rail-chain-signal"}
        }
    end

    local function make_entity_id(entity)
        return entity.unit_number or (entity.type .. "$" .. entity.position.x .. "$" .. entity.position.y .. "$" .. entity.direction)
    end

    local function owns_signal(rail, signal)
        if signal == nil then
            return false
        end

        local connected_rails = nil
        if signal.type == "train-stop" then
            connected_rails = {signal.connected_rail}
        else
            connected_rails = signal.get_connected_rails()
        end

        for _, r in ipairs(connected_rails) do
            if rail == r then
                return true
            end
        end

        return false
    end

    local function insert_if_not_nil(tbl, v)
        if v ~= nil then
            table.insert(tbl, v)
        end
    end

    local function get_rail_signal_type(signal)
        if signal == nil then
            return rail_signal_type.none
        elseif signal.type == "rail-signal" then
            return rail_signal_type.normal
        elseif signal.type == "rail-chain-signal" then
            return rail_signal_type.chain
        else
            return rail_signal_type.none
        end
    end

    local function get_segment_signals_and_traffic_direction(rail)
        local front_in_signal = rail.get_rail_segment_entity(defines.rail_direction.front, true)
        local front_out_signal = rail.get_rail_segment_entity(defines.rail_direction.front, false)
        local back_in_signal = rail.get_rail_segment_entity(defines.rail_direction.back, true)
        local back_out_signal = rail.get_rail_segment_entity(defines.rail_direction.back, false)

        local segment_signals = {
            front_in = get_rail_signal_type(front_in_signal),
            front_out = get_rail_signal_type(front_out_signal),
            back_in = get_rail_signal_type(back_in_signal),
            back_out = get_rail_signal_type(back_out_signal)
        }

        local forward = (owns_signal(rail, back_in_signal) or owns_signal(rail, front_out_signal))
        local backward = (owns_signal(rail, back_out_signal) or owns_signal(rail, front_in_signal))
        local traffic_direction = rail_traffic_direction.indeterminate

        if forward and backward then
            traffic_direction = rail_traffic_direction.universal
        elseif forward then
            traffic_direction = rail_traffic_direction.forward
        elseif backward then
            traffic_direction = rail_traffic_direction.backward
        end

        return segment_signals, traffic_direction
    end

    local function get_segment_signals(rail)
        local front_in_signal = rail.get_rail_segment_entity(defines.rail_direction.front, true)
        local front_out_signal = rail.get_rail_segment_entity(defines.rail_direction.front, false)
        local back_in_signal = rail.get_rail_segment_entity(defines.rail_direction.back, true)
        local back_out_signal = rail.get_rail_segment_entity(defines.rail_direction.back, false)

        local segment_signals = {
            front_in = get_rail_signal_type(front_in_signal),
            front_out = get_rail_signal_type(front_out_signal),
            back_in = get_rail_signal_type(back_in_signal),
            back_out = get_rail_signal_type(back_out_signal)
        }

        return segment_signals
    end

    local function get_begin_end_signals(signals)
        local begin_signal = rail_signal_type.none
        local end_signal = rail_signal_type.none

        if signals.front_out ~= rail_signal_type.none then
            end_signal = signals.front_out
        elseif signals.back_out ~= rail_signal_type.none then
            end_signal = signals.back_out
        end

        if signals.front_in ~= rail_signal_type.none then
            begin_signal = signals.front_in
        elseif signals.back_in ~= rail_signal_type.none then
            begin_signal = signals.back_in
        end

        return begin_signal, end_signal
    end

    local function is_neighbour_connected_by_front(rail, neighbour)
        for _, condir in ipairs(ALL_RAIL_CONNECTION_DIRECTIONS) do
            local e = neighbour.get_connected_rail{rail_direction=defines.rail_direction.front, rail_connection_direction=condir}
            if e == rail then
                return true
            end
        end
        return false
    end

    local function get_neighbour_segments(rail, direction, is_front)
        local segments = {}

        for _, condir in ipairs(ALL_RAIL_CONNECTION_DIRECTIONS) do
            local neighbour_rail = rail.get_connected_rail{rail_direction=direction, rail_connection_direction=condir}
            if neighbour_rail ~= nil then
                local front_rail, front_dir = neighbour_rail.get_rail_segment_end(defines.rail_direction.front)
                local back_rail, back_dir = neighbour_rail.get_rail_segment_end(defines.rail_direction.back)
                if is_neighbour_connected_by_front(rail, front_rail) == is_front then
                    front_rail, back_rail = back_rail, front_rail
                    front_dir, back_dir = back_dir, front_dir
                end
                table.insert(segments, {
                    frontmost_rail = front_rail,
                    backmost_rail = back_rail,
                    frontmost_dir = front_dir,
                    backmost_dir = back_dir
                })
            end
        end

        return segments
    end

    local function box_contains_point(box, point)
        return     point.x >= box.left_top[1]
               and point.x <= box.right_bottom[1]
               and point.y >= box.left_top[2]
               and point.y <= box.right_bottom[2]
    end

    local function get_neighbour_rails(rail, dir)
        local neighbour_rails = {}
        insert_if_not_nil(neighbour_rails, rail.get_connected_rail{rail_direction=dir, rail_connection_direction=defines.rail_connection_direction.left})
        insert_if_not_nil(neighbour_rails, rail.get_connected_rail{rail_direction=dir, rail_connection_direction=defines.rail_connection_direction.straight})
        insert_if_not_nil(neighbour_rails, rail.get_connected_rail{rail_direction=dir, rail_connection_direction=defines.rail_connection_direction.right})
        return neighbour_rails
    end

    local function get_rails_in_segment(segment)
        local rails = {}

        -- Check if the segment changed, because we do partial updates.
        -- If it did we cannot traverse it.
        do
            if not segment.frontmost_rail.valid then
                return rails
            end

            local rail = segment.frontmost_rail
            local infer_
            local frontmost_rail = nil
            local backmost_rail = nil
            local frontmost_dir = nil
            local backmost_dir = nil
            local frontmost_rail, frontmost_dir = rail.get_rail_segment_end(defines.rail_direction.front)
            local backmost_rail, backmost_dir = rail.get_rail_segment_end(defines.rail_direction.back)

            if frontmost_rail ~= segment.frontmost_rail then
                frontmost_rail, backmost_rail = backmost_rail, frontmost_rail
                frontmost_dir, backmost_dir = backmost_dir, frontmost_dir
            end

            if    frontmost_rail ~= segment.frontmost_rail
               or backmost_rail ~= segment.backmost_rail then
                return rails
            end
        end

        local curr_rail = segment.backmost_rail
        local curr_dir = nil
        if segment.backmost_dir == defines.rail_direction.back then
            curr_dir = defines.rail_direction.front
        else
            curr_dir = defines.rail_direction.back
        end
        while true do
            table.insert(rails, curr_rail)
            local next = get_neighbour_rails(curr_rail, curr_dir)
            if curr_rail == segment.frontmost_rail then
                break
            end
            if is_neighbour_connected_by_front(curr_rail, next[1]) then
                curr_dir = defines.rail_direction.back
            else
                curr_dir = defines.rail_direction.front
            end
            curr_rail = next[1]
        end
        return rails
    end

    local function is_segment_intersection_free(node)
        local overlapping_rails = node.backmost_rail.get_rail_segment_overlaps()
        local is_intersection_free = true
        if #overlapping_rails > 0 then
            local neighbours = {}
            for _, neighbour in ipairs(get_neighbour_rails(node.backmost_rail, node.backmost_dir)) do
                neighbours[make_entity_id(neighbour)] = true
            end
            for _, neighbour in ipairs(get_neighbour_rails(node.frontmost_rail, node.frontmost_dir)) do
                neighbours[make_entity_id(neighbour)] = true
            end
            for _, overlapping_rail in ipairs(overlapping_rails) do
                local is_directly_adjacent = false
                for _, enddir in ipairs(ALL_RAIL_DIRECTIONS) do
                    local rail, dir = overlapping_rail.get_rail_segment_end(enddir)
                    for _, condir in ipairs(ALL_RAIL_CONNECTION_DIRECTIONS) do
                        local other_neighbour = rail.get_connected_rail{rail_direction=dir, rail_connection_direction=condir}
                        if other_neighbour ~= nil and neighbours[make_entity_id(other_neighbour)] then
                            is_directly_adjacent = true
                            goto next_rail_label
                        end
                    end
                end
                if not is_directly_adjacent then
                    is_intersection_free = false
                    break
                end
                ::next_rail_label::
            end
        end
        return is_intersection_free
    end

    local function create_railway_segment_graph_dynamic(start_signals, area)
        local segment_graph = {}

        -- Poor man's priority queue
        local queues = {[-1]={}, [0]={}, [1]={}, [2]={}}
        local queues_ids = {0, 1, 2, -1}

        -- First we find rails that we can infer direction from
        for _, signal in ipairs(start_signals) do
            for _, rail in ipairs(signal.get_connected_rails()) do
                -- Here we check if the rail has a signal attached.
                -- We're not interested in whole segments right now, as a single
                -- rail with a signal is enough to grow the railway later.
                local segment_signals, traffic_direction = get_segment_signals_and_traffic_direction(rail)
                if traffic_direction == rail_traffic_direction.forward or traffic_direction == rail_traffic_direction.backward then
                    local frontmost_rail = nil
                    local backmost_rail = nil
                    local frontmost_dir = nil
                    local backmost_dir = nil
                    if traffic_direction == rail_traffic_direction.forward then
                        frontmost_rail, frontmost_dir = rail.get_rail_segment_end(defines.rail_direction.front)
                        backmost_rail, backmost_dir = rail.get_rail_segment_end(defines.rail_direction.back)
                    else --if traffic_direction == rail_traffic_direction.backward then
                        frontmost_rail, frontmost_dir = rail.get_rail_segment_end(defines.rail_direction.back)
                        backmost_rail, backmost_dir = rail.get_rail_segment_end(defines.rail_direction.front)
                    end

                    local id = make_entity_id(backmost_rail)
                    if segment_graph[id] == nil then
                        local begin_signal, end_signal = get_begin_end_signals(segment_signals)
                        local segment_length = backmost_rail.get_rail_segment_length()

                        local forward_distance_from_chain = nil
                        if end_signal == rail_signal_type.chain then
                            forward_distance_from_chain = 0
                        elseif begin_signal == rail_signal_type.chain then
                            forward_distance_from_chain = 1
                        elseif begin_signal == rail_signal_type.normal then
                            forward_distance_from_chain = 2 -- at least 2, but we may potentially need that block so we want to explore it fully
                        elseif end_signal == rail_signal_type.normal then
                            forward_distance_from_chain = 1
                        end

                        segment_graph[id] = {
                            frontmost_rail = frontmost_rail,
                            backmost_rail = backmost_rail,
                            frontmost_dir = frontmost_dir,
                            backmost_dir = backmost_dir,
                            begin_signal = begin_signal,
                            end_signal = end_signal,
                            next = {},
                            prev = {},
                            segment_length = segment_length,
                            is_inside_area = true,
                            forward_distance_from_chain = forward_distance_from_chain,
                            is_chain_uncertain = false,
                            growth_direction = graph_node_growth_direction.both
                        }

                        -- Add to queue to grow from later.
                        table.insert(queues[forward_distance_from_chain], id)
                    end
                end
            end
        end

        -- then we grow from them until we reach enough segments
        -- we grow until we hit forward_distance_from_chain>=2 and we're outside of the area
        -- that means we will catch all blocks that train on chains wait for
        while true do
            local id = nil
            for _, queue_id in ipairs(queues_ids) do
                local queue = queues[queue_id]
                if #queue > 0 then
                    id = table.remove(queue, #queue)
                    break
                end
            end

            if id == nil then
                break
            end

            local node = segment_graph[id]

            if (node.growth_direction == graph_node_growth_direction.forward or node.growth_direction == graph_node_growth_direction.both) then
                local next_segments = get_neighbour_segments(node.frontmost_rail, node.frontmost_dir, true)

                -- try to expand each neighbour
                for _, segment in ipairs(next_segments) do
                    local segment_id = make_entity_id(segment.backmost_rail)
                    local new_node = segment_graph[segment_id]
                    -- if already present in the graph then we don't care
                    if new_node == nil then
                        -- get signals, we're not interested in segment signals here
                        -- we just want to know if the rail constitutes a change in block
                        local segment_signals = get_segment_signals(segment.backmost_rail)
                        local begin_signal, end_signal = get_begin_end_signals(segment_signals)

                        -- make sure we have consistent signal information between neighbours
                        if begin_signal == rail_signal_type.none then
                            begin_signal = node.end_signal
                        elseif node.end_signal == rail_signal_type.none then
                            node.end_signal = begin_signal
                        end

                        -- we handle a transition from one block to another
                        -- this can only happen if either
                        --   1. the previous rail had an end_signal
                        --   2. this rail has a begin_signal
                        -- both cannot be true at the same time, because the game prevents such placement
                        local forward_distance_from_chain = node.forward_distance_from_chain
                        if end_signal == rail_signal_type.chain then
                            forward_distance_from_chain = 0
                        elseif begin_signal == rail_signal_type.chain then
                            forward_distance_from_chain = 1
                        elseif begin_signal ~= rail_signal_type.none then
                            forward_distance_from_chain = node.forward_distance_from_chain + 1
                        end

                        -- see if we actually want to expand there
                        if forward_distance_from_chain <= 2 then
                            local segment_length = segment.backmost_rail.get_rail_segment_length()
                            local is_inside_area =     box_contains_point(area, segment.backmost_rail.position)
                                                   and box_contains_point(area, segment.frontmost_rail.position)

                            local growth_direction = graph_node_growth_direction.both
                            if not is_inside_area then
                                -- If we're outside the range then it's enough if we just go forward from this node,
                                -- because we only need to find reachable blocks.
                                -- This limits the exploration a lot.
                                growth_direction = graph_node_growth_direction.forward
                            end

                            new_node = {
                                frontmost_rail = segment.frontmost_rail,
                                backmost_rail = segment.backmost_rail,
                                frontmost_dir = segment.frontmost_dir,
                                backmost_dir = segment.backmost_dir,
                                begin_signal = begin_signal,
                                end_signal = end_signal,
                                next = {},
                                prev = {},
                                segment_length = segment_length,
                                is_inside_area = is_inside_area,
                                forward_distance_from_chain = forward_distance_from_chain,
                                is_chain_uncertain = false,
                                growth_direction = growth_direction
                            }

                            segment_graph[segment_id] = new_node
                            table.insert(queues[forward_distance_from_chain], segment_id)
                            table.insert(node.next, segment_id)
                        end
                    else
                        -- If it's already there then just make sure everything is consitent
                        -- regarding signals on ends. This needs to be checked because
                        -- the rail can be reached from two sides.
                        if new_node.begin_signal == rail_signal_type.none then
                            new_node.begin_signal = node.end_signal
                        end
                        if node.end_signal == rail_signal_type.none then
                            node.end_signal = new_node.begin_signal
                        end
                        table.insert(node.next, segment_id)
                    end
                end
            end

            if (node.growth_direction == graph_node_growth_direction.backward or node.growth_direction == graph_node_growth_direction.both) then
                local prev_segments = get_neighbour_segments(node.backmost_rail, node.backmost_dir, false)

                -- now we have to do the same but in the other direction
                for _, segment in ipairs(prev_segments) do
                    local segment_id = make_entity_id(segment.backmost_rail)
                    local new_node = segment_graph[segment_id]
                    -- if present then we don't care
                    if new_node == nil then
                        -- get signals, we're not interested in segment signals
                        local segment_signals = get_segment_signals(segment.backmost_rail)
                        local begin_signal, end_signal = get_begin_end_signals(segment_signals)

                        if end_signal == rail_signal_type.none then
                            end_signal = node.begin_signal
                        elseif node.begin_signal == rail_signal_type.none then
                            node.begin_signal = end_signal
                        end

                        -- When going backward we don't really care about resetting
                        -- forward_distance_from_chain on blocks with chain signals because we're
                        -- only interested in the immediately preceding block the train would wait on.
                        local forward_distance_from_chain = node.forward_distance_from_chain
                        if begin_signal == rail_signal_type.chain then
                            forward_distance_from_chain = 2
                        elseif end_signal ~= rail_signal_type.none then
                            forward_distance_from_chain = node.forward_distance_from_chain - 1
                        end

                        -- see if we actually want to expand there
                        if forward_distance_from_chain >= -1 then
                            local segment_length = segment.backmost_rail.get_rail_segment_length()
                            local is_inside_area =     box_contains_point(area, segment.backmost_rail.position)
                                                   and box_contains_point(area, segment.frontmost_rail.position)

                            local growth_direction = graph_node_growth_direction.both
                            if not is_inside_area then
                                growth_direction = graph_node_growth_direction.backward
                            end

                            new_node = {
                                frontmost_rail = segment.frontmost_rail,
                                backmost_rail = segment.backmost_rail,
                                frontmost_dir = segment.frontmost_dir,
                                backmost_dir = segment.backmost_dir,
                                begin_signal = begin_signal,
                                end_signal = end_signal,
                                next = {},
                                prev = {},
                                segment_length = segment_length,
                                is_inside_area = is_inside_area,
                                forward_distance_from_chain = forward_distance_from_chain,
                                -- When we expand backwards some chains won't get full coverage
                                -- We want to mark those as uncertain so that they are not rendered later
                                is_chain_uncertain = not is_inside_area,
                                growth_direction = growth_direction
                            }

                            segment_graph[segment_id] = new_node
                            table.insert(queues[forward_distance_from_chain], segment_id)
                            table.insert(node.prev, segment_id)
                        end
                    else
                        if new_node.end_signal == rail_signal_type.none then
                            new_node.end_signal = node.begin_signal
                        end
                        if node.begin_signal == rail_signal_type.none then
                            node.begin_signal = new_node.end_signal
                        end
                        table.insert(node.prev, segment_id)
                    end
                end
            end
        end

        for id, node in pairs(segment_graph) do
            node.is_intersection_free = is_segment_intersection_free(node)
        end

        return segment_graph
    end

    local function find_safe_spaces_after_chain_signals(graph, start_segment_id)
        local visited = {[start_segment_id]=true}

        local node = graph[start_segment_id]
        if node.end_signal ~= rail_signal_type.chain then
            return {}
        end

        -- go through the initial chain signal
        local head = {}
        for _, next_id in ipairs(node.next) do
            visited[next_id] = true
            table.insert(head, {
                blocks = {{next_id}},
                last_segment_id = next_id,
                block_number_after_chain = 0
            })
        end

        while true do
            local new_head = {}
            local added_new_segments = false
            for _, h in ipairs(head) do
                local node = graph[h.last_segment_id]
                local expand = h.block_number_after_chain == 0 or (h.block_number_after_chain == 1 and node.end_signal == rail_signal_type.none)
                -- we must end up such that begin signal is a normal signal
                if expand and #node.next > 0 then
                    local is_next_block = node.begin_signal ~= rail_signal_type.none
                    local block_number_after_chain = h.block_number_after_chain
                    if node.end_signal == rail_signal_type.normal then
                        block_number_after_chain = block_number_after_chain + 1
                    end
                    for _, next_id in ipairs(node.next) do
                        if not visited[next_id] then
                            visited[next_id] = true
                            local new_blocks = deepcopy(h.blocks)
                            if is_next_block then
                                table.insert(new_blocks, {next_id})
                            else
                                table.insert(new_blocks[#new_blocks], next_id)
                            end
                            table.insert(new_head, {
                                blocks = new_blocks,
                                last_segment_id = next_id,
                                block_number_after_chain = block_number_after_chain
                            })
                        end
                    end
                    added_new_segments = true
                else
                    table.insert(new_head, h)
                end
            end

            if added_new_segments then
                head = new_head
            else
                break
            end
        end

        local result_spaces = {}
        for _, space in ipairs(head) do
            local final_block = space.blocks[#space.blocks]
            -- For the block to be fusable it must have exactly one output
            -- Otherwise we have a situation like at the start of a stacker for example,
            -- where something could block other outputs.
            if #head == 1 and #space.blocks > 1 then
                local candidate_block = space.blocks[#space.blocks - 1]
                local is_candidate_block_safe = true
                for _, segment_id in ipairs(candidate_block) do
                    local is_fusable = graph[segment_id].is_intersection_free
                    if not is_fusable then
                        is_candidate_block_safe = false
                        break
                    end
                end
                if is_candidate_block_safe then
                    final_block = table_concat(candidate_block, final_block)
                end
            end
            table.insert(result_spaces, final_block)
        end

        return result_spaces
    end

    -- NOTE: This function only considers connected rails. It does NOT handle rail intersections.
    local function expand_segment_to_block(graph, segment_id)
        local visited = {segment_id}
        local queue = {segment_id}
        local block = {}

        -- First expand nodes by flood fill
        while #queue > 0 do
            local node_id = table.remove(queue, #queue)
            local node = graph[node_id]
            block[node_id] = shallowcopy(node)
            if node.end_signal == rail_signal_type.none then
                -- We handle the case where we can go forward in the block
                for _, next_id in ipairs(node.next) do
                    if not visited[next_id] then
                        visited[next_id] = true
                        table.insert(queue, next_id)
                    end
                end
            else
                -- We handle the case where the signal is on the merge of multiple tracks.
                -- In this case the block is a union of segments that do not have a connection.
                -- The only thing conencting them is the rail AFTER the signal.
                -- So we just add all predecessors of a successors
                -- (they should be all the same so no need to check all).
                if #node.next > 0 then
                    for _, next_prev_id in ipairs(graph[node.next[1]].prev) do
                        if not visited[next_prev_id] then
                            visited[next_prev_id] = true
                            table.insert(queue, next_prev_id)
                        end
                    end
                end
            end

            if node.begin_signal == rail_signal_type.none then
                -- We handle the case where we can go forward in the block
                for _, prev_id in ipairs(node.prev) do
                    if not visited[prev_id] then
                        visited[prev_id] = true
                        table.insert(queue, prev_id)
                    end
                end
            else
                -- Same as in the alternative forward case.
                if #node.prev > 0 then
                    for _, prev_next_id in ipairs(graph[node.prev[1]].next) do
                        if not visited[prev_next_id] then
                            visited[prev_next_id] = true
                            table.insert(queue, prev_next_id)
                        end
                    end
                end
            end
        end

        -- and then prune edges that are no longer relevant
        for id, node in pairs(block) do
            local new_next = {}
            local new_prev = {}
            for _, next_id in ipairs(node.next) do
                if block[next_id] ~= nil then
                    table.insert(new_next, next_id)
                end
            end
            for _, prev_id in ipairs(node.prev) do
                if block[prev_id] ~= nil then
                    table.insert(new_prev, prev_id)
                end
            end
            node.next = new_next
            node.prev = new_prev
        end

        return block
    end

    -- Since blocks flood fill there can never be two different blocks
    -- sharing a rail. So we just need to check if any of the blocks
    -- contains at least one of the rails from other block.
    local function are_blocks_equal(a, b)
        for id, node in pairs(a) do
            if b[id] ~= nil then
                return true
            end
        end
        return false
    end

    local function block_a_contains_any_from_b(a, b)
        for id, node in pairs(a) do
            if b[id] ~= nil then
                return true
            end
        end
        return false
    end

    local function tiles_to_train_length(tiles)
        -- one additional tile because trains stop a tile short of a signal
        local train_lengths = 0
        tiles = tiles - 1 -- trains stop 1 tile short
        while true do
            if tiles >= 6 then
                train_lengths = train_lengths + 1
                tiles = tiles - 6
            end
            if tiles >= 7 then
                tiles = tiles - 1
            else
                break
            end
        end
        train_lengths = train_lengths + tiles / 7
        return train_lengths
    end

    local function label_segments(graph, train_length, collect_suggestions)
        local interesting_nodes = {}

        for id, node in pairs(graph) do
            if node.end_signal == rail_signal_type.chain then
                -- This one needs to be expanded fully
                local block = expand_segment_to_block(graph, id)
                -- These blocks will only be expanded forward
                local safe_spaces_after_chain = find_safe_spaces_after_chain_signals(graph, id)

                node.min_block_length_after_chain_signals = nil
                if not node.is_interesting and not node.is_chain_uncertain then
                    node.is_interesting = true
                    table.insert(interesting_nodes, node)
                end

                for _, safe_space in ipairs(safe_spaces_after_chain) do
                    -- We can just check for containment here, it's enough.
                    if block_a_contains_any_from_b(block, safe_space) then
                        -- before chain is the same block as after chain,
                        -- so the train will never go through there...
                        -- in this case we don't produce any other information
                        node.chain_selfwait = true
                        node.min_block_length_after_chain_signals = nil
                        break
                    end
                end

                -- Now check for blocks that are too small, but only after we know that
                -- the chain signal is not completely useless.
                if not node.chain_selfwait then
                    for _, safe_space in ipairs(safe_spaces_after_chain) do
                        local first_safe_segment = graph[safe_space[1]]

                        local size = 0
                        for _, segment_id in ipairs(safe_space) do
                            size = size + graph[segment_id].segment_length
                        end

                        if node.min_block_length_after_chain_signals == nil or size < node.min_block_length_after_chain_signals then
                            node.min_block_length_after_chain_signals = size
                        end

                        if first_safe_segment.block_length == nil or size < first_safe_segment.block_length then
                            first_safe_segment.block_length = size
                        end

                        if not first_safe_segment.is_interesting then
                            first_safe_segment.is_interesting = true
                            table.insert(interesting_nodes, first_safe_segment)
                        end

                        -- issue warnings
                        if tiles_to_train_length(size) < train_length then
                            first_safe_segment.block_after_chain_too_small = true
                            if first_safe_segment.too_small_forward_blocks == nil then
                                first_safe_segment.too_small_forward_blocks = {}
                            end
                            table.insert(first_safe_segment.too_small_forward_blocks, safe_space)
                        end
                    end
                end

                if not node.min_block_length_after_chain_signals and not node.chain_selfwait then
                    node.no_destination = true
                end
            end

            if collect_suggestions and node.begin_signal == rail_signal_type.normal then
                local block = expand_segment_to_block(graph, id)
                local is_intersection_free = true
                for _, segment in pairs(block) do
                    if not segment.is_intersection_free then
                        is_intersection_free = false
                        break
                    end
                end
                if not is_intersection_free then
                    node.suggestion_start_with_chain = true
                    if not node.is_interesting then
                        node.is_interesting = true
                        table.insert(interesting_nodes, node)
                    end
                end
            end
        end

        return interesting_nodes
    end

    local function get_segment_overlays(node, train_length)
        local overlays = {}

        if node.min_block_length_after_chain_signals then
            local text = "... -> " .. string.format("%.2f", tiles_to_train_length(node.min_block_length_after_chain_signals))
            local color = COLOR_GOOD
            if tiles_to_train_length(node.min_block_length_after_chain_signals) < train_length then
                color = COLOR_BAD
            end
            table.insert(overlays, {
                text = text,
                color = color,
                position = segment_overlay_position.front
            })
        elseif node.chain_selfwait then
            local text = "... -> same block!"
            local color = COLOR_BAD
            table.insert(overlays, {
                text = text,
                color = color,
                position = segment_overlay_position.front
            })
        elseif node.no_destination then
            local text = "no destination!"
            local color = COLOR_BAD
            table.insert(overlays, {
                text = text,
                color = color,
                position = segment_overlay_position.front
            })
        end

        if node.block_after_chain_too_small or node.block_length then
            local text = string.format("%.2f", tiles_to_train_length(node.block_length))
            local color = COLOR_GOOD
            local alert_message = nil
            if node.block_after_chain_too_small then
                color = COLOR_BAD
                alert_message = "Block too small"
            end
            if node.begin_signal == rail_signal_type.chain then
                text = text .. " (fused)"
            end
            table.insert(overlays, {
                text = text,
                color = color,
                position = segment_overlay_position.back,
                alert_message = alert_message
            })
        end

        if node.suggestion_start_with_chain then
            table.insert(overlays, {
                text = "CHAIN?",
                color = COLOR_SUGGESTION,
                position = segment_overlay_position.back
            })
        end

        return overlays
    end

    local function clear_renderings(player)
        local data = get_config(player)
        local old_renderings = data.renderings
        for _, r in ipairs(old_renderings) do
            rendering.destroy(r)
        end
        data.renderings = {}
    end

    local function fill_node_overlay_locations(node)
        local frontmost_rail = node.frontmost_rail
        if frontmost_rail.valid then
            local frontmost_rail_orient = nil
            local frontmost_rail_pos = frontmost_rail.position
            if frontmost_rail.type == "straight-rail" then
                local dir = frontmost_rail.direction
                local offset = STRAIGHT_RAIL_DIR_TO_OFFSET[dir]
                frontmost_rail_orient = STRAIGHT_RAIL_DIR_TO_ORIENT[dir]
                frontmost_rail_pos.x = frontmost_rail_pos.x + offset[1]
                frontmost_rail_pos.y = frontmost_rail_pos.y + offset[2]
            else
                frontmost_rail_orient = CURVED_RAIL_DIR_TO_ORIENT[frontmost_rail.direction]
            end

            if node.frontmost_dir == defines.rail_direction.back then
                frontmost_rail_orient = (frontmost_rail_orient + 0.5) % 1.0
            end

            node.frontmost_rail_pos = frontmost_rail_pos
            node.frontmost_rail_orient = frontmost_rail_orient
        end

        local backmost_rail = node.backmost_rail
        if backmost_rail.valid then
            local backmost_rail_orient = nil
            local backmost_rail_pos = backmost_rail.position
            if backmost_rail.type == "straight-rail" then
                local dir = backmost_rail.direction
                local offset = STRAIGHT_RAIL_DIR_TO_OFFSET[dir]
                backmost_rail_orient = STRAIGHT_RAIL_DIR_TO_ORIENT[dir]
                backmost_rail_pos.x = backmost_rail_pos.x + offset[1]
                backmost_rail_pos.y = backmost_rail_pos.y + offset[2]
            else
                backmost_rail_orient = CURVED_RAIL_DIR_TO_ORIENT[backmost_rail.direction]
            end

            if node.backmost_dir == defines.rail_direction.front then
                backmost_rail_orient = (backmost_rail_orient + 0.5) % 1.0
            end

            node.backmost_rail_pos = backmost_rail_pos
            node.backmost_rail_orient = backmost_rail_orient
        end
    end

    local function get_rail_polygon_vertices(rail)
        if rail.type == "straight-rail" then
            return STRAIGHT_RAIL_DIR_TO_POLYGON_VERTICES[rail.direction]
        else
            return CURVED_RAIL_DIR_TO_POLYGON_VERTICES[rail.direction]
        end
    end

    local function highlight_rail(player, rail, ttl, renderings)
        if not rail.valid then
            return
        end

        local vertices = get_rail_polygon_vertices(rail)

        local rendering_id = rendering.draw_polygon{
            color = {0.4, 0, 0, 0.4},
            vertices = vertices,
            target = rail,
            players = {player},
            surface = rail.surface,
            time_to_live = ttl
        }

        if ttl == nil then
            table.insert(renderings, rendering_id)
        end
    end

    local function highlight_segment(player, segment, ttl, renderings)
        for _, rail in ipairs(get_rails_in_segment(segment)) do
            highlight_rail(player, rail, ttl, renderings)
        end
    end
    
    local function update(player, type, range, ttl)
        local data = get_config(player)
        local train_length = data.train_length

        if type == partial_update_type.create_graph or type == partial_update_type.all then
            -- This needs to be formed in one tick sadly, can't smear it.
            -- Otherwise we could end up with an inconsistent railway graph due to changes between ticks.
            local signals = nil
            local segment_graph = nil
            if range ~= nil then
                local area = get_area_around_the_player(player, range)
                signals = get_signals_in_area(player.surface, area)
                segment_graph = create_railway_segment_graph_dynamic(signals, area)
            else
                -- Never query surface with a very large area, because there are issues in the engine.
                signals = get_signals_in_area(player.surface, nil)
                segment_graph = create_railway_segment_graph_dynamic(signals, get_area_around_the_player(player, 9999999))
            end
            data.partial_update_data.segment_graph = segment_graph
        end

        if type == partial_update_type.label_graph_and_render or type == partial_update_type.all then
            local highlighted_segments_ids = {}
            local segment_graph = data.partial_update_data.segment_graph
            if segment_graph ~= nil then
                clear_renderings(player)

                local interesting_nodes = label_segments(segment_graph, train_length, data.suggestions_enabled)
                for _, node in ipairs(interesting_nodes) do
                    local overlays = get_segment_overlays(node, train_length)
                    for _, overlay in ipairs(overlays) do
                        local color = overlay.color
                        if color == COLOR_BAD or not data.only_show_problems then
                            local target = nil
                            local orientation = nil
                            fill_node_overlay_locations(node)
                            if overlay.position == segment_overlay_position.front and node.frontmost_rail_pos ~= nil then
                                target = node.frontmost_rail_pos
                                orientation = node.frontmost_rail_orient
                            elseif node.backmost_rail_pos ~= nil then
                                target = node.backmost_rail_pos
                                orientation = node.backmost_rail_orient
                            end

                            if target ~= nil then
                                local rendering_id = rendering.draw_text{
                                    color = color,
                                    text = overlay.text,
                                    target = target,
                                    scale = 1.5,
                                    orientation = orientation,
                                    players = {player},
                                    alignment = "center",
                                    vertical_alignment = "middle",
                                    surface = player.surface,
                                    time_to_live = ttl
                                }

                                if data.highlight_rails and node.too_small_forward_blocks then
                                    for _, fb in ipairs(node.too_small_forward_blocks) do
                                        for _, segment_id in ipairs(fb) do
                                            if not highlighted_segments_ids[segment_id] then
                                                highlighted_segments_ids[segment_id] = true
                                                highlight_segment(player, segment_graph[segment_id], ttl, data.renderings)
                                            end
                                        end
                                    end
                                end

                                if data.show_as_alerts and overlay.alert_message ~= nil then
                                    player.add_custom_alert(
                                        node.backmost_rail,
                                        {type="item", name="rail-chain-signal"},
                                        overlay.alert_message,
                                        true
                                    )
                                end

                                if ttl == nil then
                                    table.insert(data.renderings, rendering_id)
                                end
                            end
                        end
                    end
                end

                data.partial_update_data.segment_graph = nil
            end
        end
    end

    script.on_event(defines.events.on_tick, function(event)
        local tick = event.tick
        for _, player in pairs(game.players) do
            local type = get_partial_update_type(player, tick)
            local data = get_config(player)
            if type ~= partial_update_type.none then
                update(player, type, data.initial_rail_scan_range, data.update_period + 1)
            end
        end
    end)

    --------- END OF LOGIC

    --------- EVENTS

    local function disable_realtime_updates(player)
        local data = global.railway_signalling_overseer_data[player.index]
        local realtime_update_checkbox = get_config_gui_element(player, "railway_signalling_overseer_enable_checkbox")
        realtime_update_checkbox.state = false
        data.enabled = false
    end

    script.on_event(defines.events.on_gui_click, function(event)
        local name = event.element.name
        if name == "railway_signalling_overseer_toggle_config_window_button" then
            local player = game.players[event.player_index]
            toggle_config_window(player)
        elseif name == "railway_signalling_overseer_run_single_update_button" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            local range = data.initial_rail_scan_range
            disable_realtime_updates(player)
            update(player, partial_update_type.all, range, nil)
        elseif name == "railway_signalling_overseer_clear_overlays_button" then
            local player = game.players[event.player_index]
            clear_renderings(player)
        elseif name == "railway_signalling_overseer_run_single_update_whole_map_button" then
            local player = game.players[event.player_index]
            disable_realtime_updates(player)
            update(player, partial_update_type.all, nil, nil)
        end
    end)

    script.on_event(defines.events.on_gui_checked_state_changed, function(event)
        local name = event.element.name
        if name == "railway_signalling_overseer_enable_checkbox" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            data.enabled = event.element.state
        elseif name == "railway_signalling_overseer_only_show_problems_checkbox" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            data.only_show_problems = event.element.state
        elseif name == "railway_signalling_overseer_show_as_alerts_checkbox" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            data.show_as_alerts = event.element.state
        elseif name == "railway_signalling_overseer_highlight_rails_checkbox" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            data.highlight_rails = event.element.state
        elseif name == "railway_signalling_overseer_enable_suggestions_checkbox" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            data.suggestions_enabled = event.element.state
        end
    end)

    script.on_event(defines.events.on_gui_value_changed, function(event)
        local name = event.element.name
        if name == "railway_signalling_overseer_update_period_slider" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            local new_value = UPDATE_PERIOD_ALLOWED_VALUES[event.element.slider_value]
            data.update_period = new_value

            local label = get_config_gui_element(player, "railway_signalling_overseer_update_period_label")
            label.caption = "Update period (ticks): " .. tostring(new_value)
        elseif name == "railway_signalling_overseer_train_length_slider" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            local new_value = event.element.slider_value
            data.train_length = new_value

            local label = get_config_gui_element(player, "railway_signalling_overseer_train_length_label")
            label.caption = "Train length (wagons): " .. tostring(new_value)
        elseif name == "railway_signalling_overseer_initial_scan_range_slider" then
            local player = game.players[event.player_index]
            local data = global.railway_signalling_overseer_data[player.index]
            local new_value = event.element.slider_value
            data.initial_rail_scan_range = new_value

            local label = get_config_gui_element(player, "railway_signalling_overseer_initial_scan_range_label")
            label.caption = "Initial scan range (tiles): " .. tostring(new_value)
        end
    end)

    script.on_init(function()
        reinitialize()
    end)

    script.on_configuration_changed(function(event)
        reinitialize()
    end)

    script.on_event(defines.events.on_player_created, function(event)
        reinitialize()
    end)

    --------- END OF EVENTS
end
