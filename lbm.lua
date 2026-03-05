-- ia_fakery/lbm.lua
local MODNAME = minetest.get_current_modname()
local log = ia_util.get_logger(MODNAME)

ia_fakery.light_nodes = ia_fakery.light_nodes or {}

-- Shared failure logic for both LBM and ABM
local function evaluate_light_failure(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node or not ia_fakery.light_nodes[node.name] then return end
    
    local light_level = minetest.get_node_light(pos) or 0
   
    -- High-stress failure: Explosion if it's dark
    if light_level <= 3 then
        log(1, "Fake light failure in dark area at " .. minetest.pos_to_string(pos))
        ia_fakery.api.explode(pos, 1) 
    else
        -- Normal failure: Just catch fire
        log(2, "Fake light short-circuit at " .. minetest.pos_to_string(pos))
        minetest.set_node(pos, {name = "fire:basic_flame"})
    end
end

-- 1. THE LBM: Handles "Dead on Arrival" when you enter an area
minetest.register_lbm({
    name = MODNAME .. ":light_malfunction_load",
    nodenames = {"group:fake_light"},
    run_at_every_load = true,
    action = function(pos, node)
        -- 5% chance to be broken immediately upon loading the area
        if math.random() < 0.05 then
            minetest.after(math.random(1, 5), function()
                evaluate_light_failure(pos)
            end)
        end
    end,
})

-- 2. THE ABM: Handles the "Sudden Pop" while you are in the room
minetest.register_abm({
    label = "Fake Light Random Failure",
    nodenames = {"group:fake_light"},
    interval = 30, -- Check every 30 seconds
    chance = 100,  -- 1 in 100 chance every 30 seconds (~50 minutes average lifespan)
    action = function(pos, node)
        -- Assert to ensure we are only hitting nodes in our registry
        if ia_fakery.light_nodes[node.name] then
            evaluate_light_failure(pos)
        end
    end,
})
