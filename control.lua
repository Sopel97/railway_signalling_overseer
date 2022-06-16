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

    local ALL_RAIL_DIRECTIONS = {
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
            only_show_problems = old_data.only_show_problems or false,
            renderings = old_data.renderings or {},
            initial_rail_scan_range = old_data.initial_rail_scan_range or DEFAULT_RAIL_SCAN_RANGE,
            show_as_alerts = old_data.show_as_alerts or false,
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
                caption = "Enable realtime updates",
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
                caption = "Analize WHOLE MAP",
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

    local function get_rails_in_area(surface, area)
        return surface.find_entities_filtered{
            area=area,
            type={"curved-rail", "straight-rail"}
        }
    end

    local function owns_signal(rail, signal)
        if signal == nil then
            return false
        end

        local connected_rails = {}
        if signal.type == "train-stop" then
            table.insert(connected_rails, signal.connected_rail)
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

    local function make_entity_id(entity)
        return entity.type .. "$" .. entity.position.x .. "$" .. entity.position.y .. "$" .. entity.direction
    end

    local function infer_rail_traffic_direction_from_signals(signals)
        local forward = (signals.back_in ~= rail_signal_type.none or signals.front_out ~= rail_signal_type.none)
        local backward = (signals.back_out ~= rail_signal_type.none or signals.front_in ~= rail_signal_type.none)

        if forward and backward then
            return rail_traffic_direction.universal
        elseif forward then
            return rail_traffic_direction.forward
        elseif backward then
            return rail_traffic_direction.backward
        else
            return rail_traffic_direction.indeterminate
        end
    end

    local function insert_if_not_nil(tbl, v)
        if v ~= nil then
            table.insert(tbl, v)
        end
    end

    local function get_rail_neighbours(rail)
        local front_entities = {}
        insert_if_not_nil(front_entities, rail.get_connected_rail{rail_direction=defines.rail_direction.front, rail_connection_direction=defines.rail_connection_direction.left})
        insert_if_not_nil(front_entities, rail.get_connected_rail{rail_direction=defines.rail_direction.front, rail_connection_direction=defines.rail_connection_direction.straight})
        insert_if_not_nil(front_entities, rail.get_connected_rail{rail_direction=defines.rail_direction.front, rail_connection_direction=defines.rail_connection_direction.right})

        local back_entities = {}
        insert_if_not_nil(back_entities, rail.get_connected_rail{rail_direction=defines.rail_direction.back, rail_connection_direction=defines.rail_connection_direction.left})
        insert_if_not_nil(back_entities, rail.get_connected_rail{rail_direction=defines.rail_direction.back, rail_connection_direction=defines.rail_connection_direction.straight})
        insert_if_not_nil(back_entities, rail.get_connected_rail{rail_direction=defines.rail_direction.back, rail_connection_direction=defines.rail_connection_direction.right})

        return back_entities, front_entities
    end

    local function get_rail_neighbours_ids(rail)
        local back_entities, front_entities = get_rail_neighbours(rail)

        local front = {}
        for _, e in ipairs(front_entities) do
            insert_if_not_nil(front, make_entity_id(e))
        end

        local back = {}
        for _, e in ipairs(back_entities) do
            insert_if_not_nil(back, make_entity_id(e))
        end

        return back, front
    end

    local function get_rail_signal_type(signal, rail)
        if signal == nil or (rail and not owns_signal(rail, signal)) then
            return rail_signal_type.none
        elseif signal.type == "rail-signal" then
            return rail_signal_type.normal
        elseif signal.type == "rail-chain-signal" then
            return rail_signal_type.chain
        else
            return rail_signal_type.none
        end
    end

    local function get_rail_signals(rail)
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

        local rail_signals = {
            front_in = get_rail_signal_type(front_in_signal, rail),
            front_out = get_rail_signal_type(front_out_signal, rail),
            back_in = get_rail_signal_type(back_in_signal, rail),
            back_out = get_rail_signal_type(back_out_signal, rail)
        }

        return segment_signals, rail_signals
    end

    local function has_any_rail_signals(signals)
        return    signals.front_in ~= rail_signal_type.none
               or signals.front_out ~= rail_signal_type.none
               or signals.back_in ~= rail_signal_type.none
               or signals.back_out ~= rail_signal_type.none
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
        local rail_id = make_entity_id(rail)
        for _, dir in ipairs(ALL_RAIL_DIRECTIONS) do
            local e = neighbour.get_connected_rail{rail_direction=defines.rail_direction.front, rail_connection_direction=dir}
            if e ~= nil and make_entity_id(e) == rail_id then
                return true
            end
        end
        return false
    end

    local function box_contains_point(box, point)
        return     point.x >= box.left_top[1]
               and point.x <= box.right_bottom[1]
               and point.y >= box.left_top[2]
               and point.y <= box.right_bottom[2]
    end

    local function create_railway_segment_graph_dynamic(start_rails, area)
        local rail_graph = {}

        -- Poor man's priority queue
        local queues = {[-1]={}, [0]={}, [1]={}, [2]={}}
        local queues_ids = {0, 1, 2, -1}

        -- First we find rails that we can infer direction from
        for _, rail in ipairs(start_rails) do
            local segment_signals, rail_signals = get_rail_signals(rail)

            -- Here we check if the rail has a signal attached.
            -- We're not interested in whole segments right now, as a single
            -- rail with a signal is enough to grow the railway later.
            if has_any_rail_signals(rail_signals) then
                local id = make_entity_id(rail)
                local begin_signal, end_signal = get_begin_end_signals(rail_signals)

                local prev, next = get_rail_neighbours_ids(rail)

                local traffic_direction = infer_rail_traffic_direction_from_signals(segment_signals)
                if traffic_direction == rail_traffic_direction.indeterminate or traffic_direction == rail_traffic_direction.universal then
                    -- We cannot use these as a base, becuase they don't carry any information about the traffic direction.
                else
                    if traffic_direction == rail_traffic_direction.backward then
                        prev, next = next, prev
                    end

                    local segment_length = rail.get_rail_segment_length()

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

                    rail_graph[id] = {
                        entity = rail,
                        segment_signals = segment_signals,
                        begin_signal = begin_signal,
                        end_signal = end_signal,
                        rail_signals = rail_signals,
                        segment_length = segment_length,
                        next = next,
                        prev = prev,
                        traffic_direction = traffic_direction,
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

            local node = rail_graph[id]

            -- get neighbour rail entities
            local prev, next = get_rail_neighbours(node.entity)
            if node.traffic_direction == rail_traffic_direction.backward then
                prev, next = next, prev
            end

            if (node.growth_direction == graph_node_growth_direction.forward or node.growth_direction == graph_node_growth_direction.both) then
                -- try to expand each neighbour
                for _, rail in ipairs(next) do
                    local rail_id = make_entity_id(rail)
                    local new_node = rail_graph[rail_id]
                    -- if already present in the graph then we don't care
                    if new_node == nil then
                        -- get signals, we're not interested in segment signals here
                        -- we just want to know if the rail constitutes a change in block
                        local segment_signals, rail_signals = get_rail_signals(rail)
                        local begin_signal, end_signal = get_begin_end_signals(rail_signals)

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

                        local is_inside_area = box_contains_point(area, rail.position)

                        -- see if we actually want to expand there
                        if forward_distance_from_chain <= 2 then
                            local segment_length = rail.get_rail_segment_length()
                            local prev, next = get_rail_neighbours_ids(rail)
                            local traffic_direction = nil

                            -- find the direction of traffic for this particular rail
                            -- and correct the order of neighbours if necessary
                            if is_neighbour_connected_by_front(node.entity, rail) then
                                traffic_direction = rail_traffic_direction.backward
                                next, prev = prev, next
                            else
                                traffic_direction = rail_traffic_direction.forward
                            end

                            local growth_direction = graph_node_growth_direction.both
                            if not is_inside_area then
                                -- If we're outside the range then it's enough if we just go forward from this node,
                                -- because we only need to find reachable blocks.
                                -- This limits the exploration a lot.
                                growth_direction = graph_node_growth_direction.forward
                            end

                            new_node = {
                                entity = rail,
                                segment_signals = segment_signals,
                                begin_signal = begin_signal,
                                end_signal = end_signal,
                                rail_signals = rail_signals,
                                segment_length = segment_length,
                                next = next,
                                prev = prev,
                                traffic_direction = traffic_direction,
                                is_inside_area = is_inside_area,
                                forward_distance_from_chain = forward_distance_from_chain,
                                is_chain_uncertain = false,
                                growth_direction = growth_direction
                            }

                            rail_graph[rail_id] = new_node
                            table.insert(queues[forward_distance_from_chain], rail_id)
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
                    end
                end
            end

            if (node.growth_direction == graph_node_growth_direction.backward or node.growth_direction == graph_node_growth_direction.both) then
                -- now we have to do the same but in the other direction
                for _, rail in ipairs(prev) do
                    local rail_id = make_entity_id(rail)
                    local new_node = rail_graph[rail_id]
                    -- if present then we don't care
                    if new_node == nil then
                        -- get signals, we're not interested in segment signals
                        local segment_signals, rail_signals = get_rail_signals(rail)
                        local begin_signal, end_signal = get_begin_end_signals(rail_signals)

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

                        local is_inside_area = box_contains_point(area, rail.position)

                        -- see if we actually want to expand there
                        if forward_distance_from_chain >= -1 then
                            local segment_length = rail.get_rail_segment_length()
                            local prev, next = get_rail_neighbours_ids(rail)
                            local traffic_direction = nil

                            if is_neighbour_connected_by_front(node.entity, rail) then
                                traffic_direction = rail_traffic_direction.forward
                            else
                                traffic_direction = rail_traffic_direction.backward
                                next, prev = prev, next
                            end

                            local growth_direction = graph_node_growth_direction.both
                            if not is_inside_area then
                                growth_direction = graph_node_growth_direction.backward
                            end

                            new_node = {
                                entity = rail,
                                segment_signals = segment_signals,
                                begin_signal = begin_signal,
                                end_signal = end_signal,
                                rail_signals = rail_signals,
                                segment_length = segment_length,
                                next = next,
                                prev = prev,
                                traffic_direction = traffic_direction,
                                is_inside_area = is_inside_area,
                                forward_distance_from_chain = forward_distance_from_chain,
                                -- When we expand backwards some chains won't get full coverage
                                -- We want to mark those as uncertain so that they are not rendered later
                                is_chain_uncertain = not is_inside_area,
                                growth_direction = growth_direction
                            }

                            rail_graph[rail_id] = new_node
                            table.insert(queues[forward_distance_from_chain], rail_id)
                        end
                    else
                        if new_node.end_signal == rail_signal_type.none then
                            new_node.end_signal = node.begin_signal
                        end
                        if node.begin_signal == rail_signal_type.none then
                            node.begin_signal = new_node.end_signal
                        end
                    end
                end
            end
        end

        -- Remove all references to neighbours who didn't make it into the graph.
        -- This is because we want to make the graph self-contained, and the
        -- previous steps should have expanded just enough for this graph to
        -- make complete sense after removing these neighbour references.
        for id, node in pairs(rail_graph) do
            local new_next = {}
            local new_prev = {}
            for _, next_id in ipairs(node.next) do
                if rail_graph[next_id] ~= nil then
                    table.insert(new_next, next_id)
                end
            end
            for _, prev_id in ipairs(node.prev) do
                if rail_graph[prev_id] ~= nil then
                    table.insert(new_prev, prev_id)
                end
            end
            node.next = new_next
            node.prev = new_prev
        end

        -- Now we want to create a rail segment graph
        -- First we assign indices to frontmost and backmost rails
        -- in each segment in the original graph.
        -- Later we will never care about rails that lie in the middle of a segment.
        local segment_graph = {}
        local visited_rails = {}
        local next_segment_index = 1
        for id, node in pairs(rail_graph) do
            if not visited_rails[id] and (node.traffic_direction == rail_traffic_direction.forward or node.traffic_direction == rail_traffic_direction.backward) then
                local frontmost_id = nil
                local backmost_id = nil

                if node.traffic_direction == rail_traffic_direction.forward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                else --if node.traffic_direction == rail_traffic_direction.backward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                end

                -- If everything was done correctly in the earlier steps then we
                -- do NOT need to check if frontmost_id and backmost_id are in the rail graph.
                if not visited_rails[frontmost_id] and not visited_rails[backmost_id] then
                    visited_rails[id] = true
                    visited_rails[frontmost_id] = true
                    visited_rails[backmost_id] = true

                    local frontmost = rail_graph[frontmost_id]
                    local backmost = rail_graph[backmost_id]

                    -- TODO: In some networks with two-way segments backmost/frontmost can be nil.
                    --       It needs to be investigated why this exactly happens.
                    --       Not indexing these segments can have some impact on the correctness/completeness
                    --       of the results, but since two-way segments are not officially
                    --       supported this is an acceptable solution.
                    if frontmost ~= nil and backmost ~= nil then
                        frontmost.segment_index = next_segment_index
                        backmost.segment_index = next_segment_index

                        next_segment_index = next_segment_index + 1
                    end
                end
            end
        end

        -- Now create segment graph based on previously set indices
        for id, node in pairs(rail_graph) do
            local segment_index = node.segment_index
            if segment_index and not segment_graph[segment_index] then
                local frontmost_id = nil
                local backmost_id = nil

                if node.traffic_direction == rail_traffic_direction.forward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                else --if node.traffic_direction == rail_traffic_direction.backward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                end

                local frontmost = rail_graph[frontmost_id]
                local backmost = rail_graph[backmost_id]

                local next_segments_indices = {}
                for _, next_id in ipairs(frontmost.next) do
                    table.insert(next_segments_indices, rail_graph[next_id].segment_index)
                end
                local prev_segments_indices = {}
                for _, prev_id in ipairs(backmost.prev) do
                    table.insert(prev_segments_indices, rail_graph[prev_id].segment_index)
                end

                local frontmost_rail_orient = nil
                local frontmost_rail_pos = frontmost.entity.position
                if frontmost.entity.type == "straight-rail" then
                    local dir = frontmost.entity.direction
                    local offset = STRAIGHT_RAIL_DIR_TO_OFFSET[dir]
                    frontmost_rail_orient = STRAIGHT_RAIL_DIR_TO_ORIENT[dir]
                    frontmost_rail_pos.x = frontmost_rail_pos.x + offset[1]
                    frontmost_rail_pos.y = frontmost_rail_pos.y + offset[2]
                else
                    frontmost_rail_orient = CURVED_RAIL_DIR_TO_ORIENT[frontmost.entity.direction]
                end

                local backmost_rail_orient = nil
                local backmost_rail_pos = backmost.entity.position
                if backmost.entity.type == "straight-rail" then
                    local dir = backmost.entity.direction
                    local offset = STRAIGHT_RAIL_DIR_TO_OFFSET[dir]
                    backmost_rail_orient = STRAIGHT_RAIL_DIR_TO_ORIENT[dir]
                    backmost_rail_pos.x = backmost_rail_pos.x + offset[1]
                    backmost_rail_pos.y = backmost_rail_pos.y + offset[2]
                else
                    backmost_rail_orient = CURVED_RAIL_DIR_TO_ORIENT[backmost.entity.direction]
                end

                if frontmost.traffic_direction == rail_traffic_direction.backward then
                    frontmost_rail_orient = (frontmost_rail_orient + 0.5) % 1.0
                end
                if backmost.traffic_direction == rail_traffic_direction.backward then
                    backmost_rail_orient = (backmost_rail_orient + 0.5) % 1.0
                end

                segment_graph[frontmost.segment_index] = {
                    begin_signal = backmost.begin_signal,
                    end_signal = frontmost.end_signal,
                    segment_signals = frontmost.segment_signals,
                    frontmost_rail_pos = frontmost_rail_pos,
                    backmost_rail_pos = backmost_rail_pos,
                    frontmost_rail_orient = frontmost_rail_orient,
                    backmost_rail_orient = backmost_rail_orient,
                    is_chain_uncertain = frontmost.is_chain_uncertain,
                    next = next_segments_indices,
                    prev = prev_segments_indices,
                    segment_length = frontmost.segment_length
                }
            end
        end

        return segment_graph
    end

    -- OLD ROUTINE
    -- REQUIRES A COMPLETE SET OF RAILS AND IS NOT EASY TO MAKE IT DYNAMIC
    local function create_railway_segment_graph(rails)
        local rail_graph = {}

        -- first populate with info that doesn't require the graph structure
        -- we do not know the direction of travel for each rail yet
        for _, rail in ipairs(rails) do
            local id = make_entity_id(rail)
            local segment_signals, rail_signals = get_rail_signals(rail)
            local prev, next = get_rail_neighbours_ids(rail)

            -- TODO: this value is incorrect for diagonal rails because trains are
            -- different length there.... we need to fix it later.
            -- Well, ackshually it is correct, but the issue stems from the fact
            -- that we assume fixed length wagons, which is not true and this is
            -- the only place we can account for that.
            local segment_length = rail.get_rail_segment_length()
            local traffic_direction = infer_rail_traffic_direction_from_signals(segment_signals)

            if traffic_direction == rail_traffic_direction.backward then
                prev, next = next, prev
            end

            local begin_signal, end_signal = get_begin_end_signals(segment_signals)

            rail_graph[id] = {
                entity = rail,
                segment_signals = segment_signals,
                begin_signal = begin_signal,
                end_signal = end_signal,
                rail_signals = rail_signals,
                segment_length = segment_length,
                next = next,
                prev = prev,
                traffic_direction = traffic_direction,
                is_traffic_direction_authority = has_any_rail_signals(rail_signals)
            }
        end

        -- recursively fill missing information about signals and traffic directions
        local queue = {}
        local visited = {}
        for id, node in pairs(rail_graph) do
            if node.traffic_direction ~= rail_traffic_direction.indeterminate then
                table.insert(queue, id)
            end
        end
        while #queue > 0 do
            local id = table.remove(queue, #queue)
            if not visited[id] then
                local node = rail_graph[id]
                visited[id] = true

                for _, next_id in ipairs(node.next) do
                    local next = rail_graph[next_id]
                    if next.begin_signal == rail_signal_type.none then
                        next.begin_signal = node.end_signal
                    end
                    if next.traffic_direction == rail_traffic_direction.indeterminate then
                        if is_neighbour_connected_by_front(node.entity, next.entity) then
                            next.traffic_direction = rail_traffic_direction.backward
                            next.next, next.prev = next.prev, next.next
                        else
                            next.traffic_direction = rail_traffic_direction.forward
                        end
                    end
                    table.insert(queue, next_id)
                end

                for _, prev_id in ipairs(node.prev) do
                    local prev = rail_graph[prev_id]
                    if prev.end_signal == rail_signal_type.none then
                        prev.end_signal = node.begin_signal
                    end
                    if prev.traffic_direction == rail_traffic_direction.indeterminate then
                        if is_neighbour_connected_by_front(node.entity, prev.entity) then
                            prev.traffic_direction = rail_traffic_direction.forward
                        else
                            prev.traffic_direction = rail_traffic_direction.backward
                            prev.next, prev.prev = prev.prev, prev.next
                        end
                    end
                    table.insert(queue, prev_id)
                end
            end
        end

        local segment_graph = {}
        local visited_rails = {}
        -- now assign segment indices
        local next_segment_index = 1
        for id, node in pairs(rail_graph) do
            if node.traffic_direction ~= rail_traffic_direction.indeterminate and not visited_rails[id] then
                visited_rails[id] = true

                local frontmost_id = nil
                local backmost_id = nil

                if node.traffic_direction == rail_traffic_direction.forward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                else --if node.traffic_direction == rail_traffic_direction.backward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                end

                if frontmost_id == id or backmost_id == id or not visited_rails[frontmost_id] and not visited_rails[backmost_id] then
                    visited_rails[frontmost_id] = true
                    visited_rails[backmost_id] = true

                    local frontmost = rail_graph[frontmost_id]
                    local backmost = rail_graph[backmost_id]

                    frontmost.segment_index = next_segment_index
                    backmost.segment_index = next_segment_index

                    next_segment_index = next_segment_index + 1
                end
            end
        end

        -- now create segment graph
        local visited_segments = {}
        for id, node in pairs(rail_graph) do
            local segment_index = node.segment_index
            if segment_index and not visited_segments[segment_index] then
                visited_segments[segment_index] = true

                local frontmost_id = nil
                local backmost_id = nil

                if node.traffic_direction == rail_traffic_direction.forward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                else --if node.traffic_direction == rail_traffic_direction.backward then
                    frontmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.back))
                    backmost_id = make_entity_id(node.entity.get_rail_segment_end(defines.rail_direction.front))
                end

                local frontmost = rail_graph[frontmost_id]
                local backmost = rail_graph[backmost_id]

                local next_segments_indices = {}
                for _, next_id in ipairs(frontmost.next) do
                    table.insert(next_segments_indices, rail_graph[next_id].segment_index)
                end
                local prev_segments_indices = {}
                for _, prev_id in ipairs(backmost.prev) do
                    table.insert(prev_segments_indices, rail_graph[prev_id].segment_index)
                end

                segment_graph[frontmost.segment_index] = {
                    begin_signal = backmost.begin_signal,
                    end_signal = frontmost.end_signal,
                    frontmost_rail_pos = frontmost.entity.position,
                    backmost_rail_pos = backmost.entity.position,
                    frontmost_rail_orient = frontmost.entity.orientation,
                    backmost_rail_orient = backmost.entity.orientation,
                    next = next_segments_indices,
                    prev = prev_segments_indices,
                    segment_length = frontmost.segment_length
                }
            end
        end

        return segment_graph
    end

    local function find_segments_after_chain_signals(graph, segment_id)
        local visited = {[segment_id]=true}

        local node = graph[segment_id]
        if node.end_signal ~= rail_signal_type.chain then
            return {}
        end

        -- go through the initial chain signal
        local head = {}
        for _, next_id in ipairs(node.next) do
            visited[next_id] = true
            table.insert(head, next_id)
        end

        while true do
            local new_head = {}
            local added_new_segments = false
            for _, s_id in ipairs(head) do
                local node = graph[s_id]
                -- we must end up such that begin signal is a normal signal
                if node.begin_signal ~= rail_signal_type.normal then
                    for _, next_id in ipairs(node.next) do
                        if not visited[next_id] then
                            visited[next_id] = true
                            table.insert(new_head, next_id)
                        end
                    end
                    added_new_segments = true
                else
                    table.insert(new_head, s_id)
                end
            end

            if added_new_segments then
                head = new_head
            else
                return head
            end
        end
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

    local function expand_segment_to_block_forward(graph, segment_id)
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

    local function expand_segments_to_blocks(graph, segment_ids)
        local blocks = {}
        for _, s_id in ipairs(segment_ids) do
            table.insert(blocks, expand_segment_to_block(graph, s_id))
        end
        return blocks
    end

    local function expand_segments_to_blocks_forward(graph, segment_ids)
        local blocks = {}
        for _, s_id in ipairs(segment_ids) do
            table.insert(blocks, expand_segment_to_block_forward(graph, s_id))
        end
        return blocks
    end

    local function get_smallest_segment_size(graph, segment_ids)
        if #segment_ids == 0 then
            return 0
        end

        local smallest = nil
        for _, s_id in ipairs(segment_ids) do
            local node = graph[s_id]
            if smallest == nil or node.segment_length < smallest then
                smallest = node.segment_length
            end
        end
        return smallest
    end

    local function get_block_size_from_segment(block, start_segment_id)
        -- use a DP algorithm that goes recursively into the block
        -- and leaves the temporary computation results in the nodes itself
        local node = block[start_segment_id]
        if node.min_distance_to_sink ~= nil then
            -- We use -1 as a special value designating "on the stack"
            if node.min_distance_to_sink < 0 then
                return 0
            end
            return node.min_distance_to_sink
        end

        node.min_distance_to_sink = -1
        -- We use a local variable to prevent order from changing the results
        local min_dist = -1
        for _, next_id in ipairs(node.next) do
            local dist = get_block_size_from_segment(block, next_id) + node.segment_length
            if min_dist == -1 or dist < min_dist then
                min_dist = dist
            end
        end
        node.min_distance_to_sink = min_dist
        if node.min_distance_to_sink == -1 then
            node.min_distance_to_sink = node.segment_length
        end

        return node.min_distance_to_sink
    end

    local function find_blocks_after_chain_signals(graph, id)
        local segments_after_chains = find_segments_after_chain_signals(graph, id)
        return expand_segments_to_blocks_forward(graph, segments_after_chains), segments_after_chains
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

    local function node_ends_with_chain_signal(graph, node)
        local begin_signal, end_signal = get_begin_end_signals(node.segment_signals)
        if end_signal == rail_signal_type.chain then
            return true
        end

        for _, next_id in ipairs(node.next) do
            local next_node = graph[next_id]

            local begin_signal, end_signal = get_begin_end_signals(next_node.segment_signals)
            if begin_signal == rail_signal_type.chain then
                return true
            end
        end

        return false
    end

    local function label_segments(graph, train_length)
        local interesting_nodes = {}

        for id, node in pairs(graph) do
            if node_ends_with_chain_signal(graph, node) then
                -- This one needs to be expanded fully
                local block = expand_segment_to_block(graph, id)
                -- These blocks will only be expanded forward
                local blocks_after_chains, segments_after_chains = find_blocks_after_chain_signals(graph, id)

                node.min_block_length_after_chain_signals = nil
                if not node.is_interesting and not node.is_chain_uncertain then
                    node.is_interesting = true
                    table.insert(interesting_nodes, node)
                end

                for i, block_after_chain in ipairs(blocks_after_chains) do
                    -- We can just check for containment here, it's enough.
                    if block_a_contains_any_from_b(block, block_after_chain) then
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
                    for i, block_after_chain in ipairs(blocks_after_chains) do
                        local start_segment_id = segments_after_chains[i]
                        local node_after_chain = graph[start_segment_id]
                        local size = get_block_size_from_segment(block_after_chain, start_segment_id)
                        if node.min_block_length_after_chain_signals == nil or size < node.min_block_length_after_chain_signals then
                            node.min_block_length_after_chain_signals = size
                        end

                        node_after_chain.block_length = size
                        if not node_after_chain.is_interesting then
                            node_after_chain.is_interesting = true
                            table.insert(interesting_nodes, node_after_chain)
                        end

                        -- issue warnings
                        if tiles_to_train_length(size) < train_length then
                            node_after_chain.block_after_chain_too_small = true
                        end
                    end
                end

                if not node.min_block_length_after_chain_signals and not node.chain_selfwait then
                    node.no_destination = true
                end
            end
        end

        return interesting_nodes
    end

    local function make_node_text(node, train_length)
        local color = COLOR_GOOD
        local text = nil

        if node.min_block_length_after_chain_signals then
            text = "... -> " .. string.format("%.2f", tiles_to_train_length(node.min_block_length_after_chain_signals))
            if tiles_to_train_length(node.min_block_length_after_chain_signals) < train_length then
                color = COLOR_BAD
            end
        elseif node.chain_selfwait then
            text = "... -> same block!"
            color = COLOR_BAD
        elseif node.block_after_chain_too_small then
            text = string.format("%.2f", tiles_to_train_length(node.block_length))
            color = COLOR_BAD
        elseif node.no_destination then
            text = "no destination!"
            color = COLOR_BAD
        elseif node.block_length then
            text = string.format("%.2f", tiles_to_train_length(node.block_length))
        end

        return text, color
    end

    local function clear_renderings(player)
        local data = get_config(player)
        local old_renderings = data.renderings
        for _, r in ipairs(old_renderings) do
            rendering.destroy(r)
        end
        data.renderings = {}
    end


    local function update(player, type, range, ttl)
        local data = get_config(player)
        local train_length = data.train_length

        if type == partial_update_type.create_graph or type == partial_update_type.all then
            -- This needs to be formed in one tick sadly, can't smear it.
            -- Otherwise we could end up with an inconsistent railway graph due to changes between ticks.
            local rails = nil
            local segment_graph = nil
            if range ~= nil then
                local area = get_area_around_the_player(player, range)
                rails = get_rails_in_area(player.surface, area)
                segment_graph = create_railway_segment_graph_dynamic(rails, area)
            else
                -- Never query surface with a very large area, because there are issues in the engine.
                rails = get_rails_in_area(player.surface, nil)
                segment_graph = create_railway_segment_graph_dynamic(rails, get_area_around_the_player(player, 9999999))
            end
            data.partial_update_data.segment_graph = segment_graph
        end

        if type == partial_update_type.label_graph_and_render or type == partial_update_type.all then
            local segment_graph = data.partial_update_data.segment_graph
            if segment_graph ~= nil then
                clear_renderings(player)

                local interesting_nodes = label_segments(segment_graph, train_length)
                for _, node in ipairs(interesting_nodes) do
                    local text, color = make_node_text(node, train_length)
                    if color == COLOR_BAD or not data.only_show_problems then
                        local target = nil
                        local orientation = 0
                        if node.min_block_length_after_chain_signals or node.chain_selfwait or node.no_destination then
                            target = node.frontmost_rail_pos
                            orientation = node.frontmost_rail_orient
                        else
                            target = node.backmost_rail_pos
                            orientation = node.backmost_rail_orient
                        end

                        local rendering_id = rendering.draw_text{
                            color = color,
                            text = text,
                            target = target,
                            scale = 1.5,
                            orientation = orientation,
                            alignment = "center",
                            vertical_alignment = "middle",
                            surface = player.surface,
                            time_to_live = ttl
                        }

                        if data.show_as_alerts and node.block_after_chain_too_small then
                            player.add_custom_alert(
                                node.backmost_entity,
                                {type="item", name="rail-chain-signal"},
                                "Block too small",
                                true
                            )
                        end

                        if ttl == nil then
                            table.insert(data.renderings, rendering_id)
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

    script.on_event(defines.events.on_gui_click, function(event)
        local name = event.element.name
        if name == "railway_signalling_overseer_toggle_config_window_button" then
            local player = game.players[event.player_index]
            toggle_config_window(player)
        elseif name == "railway_signalling_overseer_run_single_update_button" then
            local player = game.players[event.player_index]
            local range = data.initial_rail_scan_range
            update(player, partial_update_type.all, range, nil)
        elseif name == "railway_signalling_overseer_clear_overlays_button" then
            local player = game.players[event.player_index]
            clear_renderings(player)
        elseif name == "railway_signalling_overseer_run_single_update_whole_map_button" then
            local player = game.players[event.player_index]
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
