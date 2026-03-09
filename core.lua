-- ia_counterfeit/core.lua
-- NOTE make sure we allow "substitutions": to make a fake item that requires some number of mese crystals and/or diamonds, we just need any one of them to be fake
-- ia_counterfeit/core.lua
local MODNAME = minetest.get_current_modname()
local log = ia_util.get_logger(MODNAME)

local function get_fake_name(name)
    local clean_name = name:match("^:(.+)") or name
    local m_name, i_name = clean_name:match("([^:]+):([^:]+)")
    if not m_name then m_name = "unknown"; i_name = clean_name end
    return "fakery:" .. m_name .. "_" .. i_name -- NOTE we can call it MODNAME .. to avoid needing the :fakery: below
end

local function ensure_fake_variant_fakery_check(name)
	if name == 'fakery:mese'     then return true end
	if name == 'fakery:diamond'  then return true end
	if name == 'fakery:obsidian' then return true end
	if name == 'fakery:gold'     then return true end
--	if name == 'fakery:mithril'  then -- TODO I need those specific item names
--		assert(minetest.get_modpath('moreores'))
--		return true
--	end
--	if name == 'fakery:cloud'    then
--		assert(minetest.get_modpath('cloud_items'))
--		return true
--	end
--	if name == 'fakery:lava'     then
--		assert(minetest.get_modpath('lavastuff'))
--		return true
--	end
--	if name == 'fakery:op'       then
--		assert(minetest.get_modpath('overpowered'))
--		return true
--	end
	if name == 'fakery:uranium'  then
		assert(minetest.get_modpath('technic_worldgen'))
		return true
	end
	if name == 'fakery:table'    then return false end
	if name == 'fakery:table_lv' then return false end
	return false
end

function ia_counterfeit.ensure_fake_variant(name) -- TODO the sloc count is fatter than your mom
    if ia_counterfeit.substitutions[name] then return ia_counterfeit.substitutions[name] end
    --if name:find("^fakery:") or ia_counterfeit.processed_items[name] then return nil end
    if ensure_fake_variant_fakery_check(name) or ia_counterfeit.processed_items[name] then return nil end
    ia_counterfeit.processed_items[name] = true

    local recipes = minetest.get_all_craft_recipes(name)
    if not recipes then return nil end

    local fake_name = get_fake_name(name)

    for _, recipe in ipairs(recipes) do
        local method = recipe.method or "normal"
        local items = recipe.items or recipe.recipe
        
        -- ASSERT: Catch missing recipe data early
        assert(items, "Recipe items missing for " .. name .. " (method: " .. method .. ")")

        local new_recipe_items = {}
        local recipe_changed = false
        local used_mese     = false
        local used_diamond  = false
	
	local used_obsidian = false
	local used_gold     = false
	local used_mithril  = false
	local used_cloud    = false
	local used_lava     = false
	local used_op       = false
	local used_uranium  = false

        -- NORMALIZE: Cooking/Fuel uses a string, Normal/Shapeless uses a table
        local items_to_process = (type(items) == "table") and items or {items}

        for i, ingredient in pairs(items_to_process) do -- TODO MUST handle all combinations of fake & real ingredients
            if type(ingredient) == "string" and ingredient ~= "" then
                -- Track specific enshittification triggers
                if ingredient == "default:mese_crystal"   or ingredient == "fakery:mese"     then used_mese     = true end
                if ingredient == "default:diamond"        or ingredient == "fakery:diamond"  then used_diamond  = true end
		if ingredient == "default:obsidian_shard" or ingredient == "fakery:obsidian" then used_obsidian = true end
		if ingredient == "default:gold_ingot"     or ingredient == "fakery:gold"     then used_gold     = true end
		--if ingredient == ...                      or ingredient == "fakery:mithril"  then used_mithril  = true end -- TODO I need those specific item names
		--if ingredient == ...                      or ingredient == "fakery:cloud"    then used_cloud    = true end
		--if ingredient == ...                      or ingredient == "fakery:lava"     then used_lava     = true end
		--if ingredient == ...                      or ingredient == "fakery:op"       then used_op       = true end
		--if ingredient == "technic:uranium_lump"   or ingredient == "fakery:uranium"  then used_uranium  = true end

                local f_ing = ia_counterfeit.ensure_fake_variant(ingredient)
                if f_ing then
                    new_recipe_items[i] = f_ing
                    recipe_changed = true
                else
                    new_recipe_items[i] = ingredient
                end
            else
                new_recipe_items[i] = ingredient or ""
            end
        end

        if recipe_changed then
            -- 1. Ensure Item Definition exists
            if not minetest.registered_items[fake_name] then
                local original_def = minetest.registered_items[name]
                if original_def then
                    local def = table.copy(original_def)
                    local spec = def._fakery or {}
                    
                    -- A. Handle Light Source Grouping
                    local is_light = (def.light_source and def.light_source > 0)
                    if is_light then
                        def.groups = def.groups or {}
                        def.groups.fake_light = 1
                        ia_counterfeit.light_nodes[fake_name] = true
                    end

                    -- B. Apply App-Specific Overrides
                    if spec.on_rightclick then
                        local old_rc = def.on_rightclick
                        def.on_rightclick = function(pos, node, clicker, itemstack, pt)
                            local res = spec.on_rightclick(pos, node, clicker, itemstack)
                            if res then return res end 
                            return old_rc and old_rc(pos, node, clicker, itemstack, pt) or itemstack
                        end
                    end

                    if spec.on_use then
                        local old_use = def.on_use
                        def.on_use = function(itemstack, user, pt)
                            local res = spec.on_use(itemstack, user)
                            if res then return res end 
                            return old_use and old_use(itemstack, user, pt) or itemstack
                        end
                    end

                    -- C. Apply Standard Enshittification
                    def = ia_counterfeit.apply_standard_enshittification(def, name, used_mese, used_diamond)

                    -- D. Registration
                    log(3, "Registering fake variant: " .. fake_name)
                    if def.drawtype or minetest.registered_nodes[name] then
                        minetest.register_node(":" .. fake_name, def)
                    else
                        minetest.register_craftitem(":" .. fake_name, def)
                    end
                end
            end

            -- 2. Reconstruct Craft
            local craft_def = { 
                output = fake_name .. " " .. ItemStack(recipe.output):get_count(),
                type = (method ~= "normal") and method or nil
            }

            if method == "normal" and recipe.width > 0 then
                -- Shaped Grid
                local grid = {}
                for y = 0, math.floor((#new_recipe_items - 1) / recipe.width) do
                    local row = {}
                    for x = 1, recipe.width do table.insert(row, new_recipe_items[y * recipe.width + x] or "") end
                    table.insert(grid, row)
                end
                craft_def.recipe = grid
            else
                -- Shapeless or Cooking/Fuel
                -- Cooking/Fuel expects a string recipe, not a table
                local is_cookfuel = (method == "cooking" or method == "fuel")
                craft_def.recipe = is_cookfuel and new_recipe_items[1] or new_recipe_items
                if not is_cookfuel then craft_def.type = "shapeless" end
            end
            
            -- FINAL ASSERTION: Ensure we aren't sending nil recipes to the engine
            assert(craft_def.recipe, "Failed to reconstruct " .. method .. " recipe for " .. fake_name)
            
            minetest.register_craft(craft_def)
            ia_counterfeit.substitutions[name] = fake_name
        end
    end
    return ia_counterfeit.substitutions[name]
end
---- ia_counterfeit/core.lua
-- FIXME improper group handling? e.g., can make a fake pickaxe with three meses and no sticks. there should be two group sticks
--local MODNAME = minetest.get_current_modname()
--local log = ia_util.get_logger(MODNAME)
--
---- Helper to get the registered fake name for an item
--local function get_fake_name(name)
--    local clean_name = name:match("^:(.+)") or name
--    local m_name, i_name = clean_name:match("([^:]+):([^:]+)")
--    if not m_name then m_name = "unknown"; i_name = clean_name end
--    return "fakery:" .. m_name .. "_" .. i_name
--end
--
---- Checks if an item is a known "base" fake item from the fakery mod
--local function is_base_fake(name)
--    local base_fakes = {
--        ['fakery:mese'] = true, ['fakery:diamond'] = true, 
--        ['fakery:obsidian'] = true, ['fakery:gold'] = true,
--        ['fakery:mithril'] = true, ['fakery:cloud'] = true,
--        ['fakery:lava'] = true, ['fakery:op'] = true,
--        ['fakery:uranium'] = true
--    }
--    return base_fakes[name] or false
--end
--
---- Recursive helper to generate all possible ingredient combinations
--local function get_recipe_combinations(items_to_process)
--    local results = {{}}
--    
--    for _, ingredient in ipairs(items_to_process) do
--        local next_step = {}
--        if type(ingredient) ~= "string" or ingredient == "" then
--            for _, combo in ipairs(results) do
--                local new_combo = table.copy(combo)
--                table.insert(new_combo, ingredient or "")
--                table.insert(next_step, new_combo)
--            end
--        else
--            -- Check for a fake variant
--            local f_ing = ia_counterfeit.ensure_fake_variant(ingredient)
--            for _, combo in ipairs(results) do
--                -- Option 1: Use the original (real) ingredient
--                local combo_real = table.copy(combo)
--                table.insert(combo_real, ingredient)
--                table.insert(next_step, combo_real)
--
--                -- Option 2: Use the fake variant (if it exists)
--                if f_ing then
--                    local combo_fake = table.copy(combo)
--                    table.insert(combo_fake, f_ing)
--                    table.insert(next_step, combo_fake)
--                end
--            end
--        end
--        results = next_step
--    end
--    return results
--end
--
--function ia_counterfeit.ensure_fake_variant(name)
--    if ia_counterfeit.substitutions[name] then return ia_counterfeit.substitutions[name] end
--    if is_base_fake(name) or ia_counterfeit.processed_items[name] then return nil end
--    
--    ia_counterfeit.processed_items[name] = true
--    local recipes = minetest.get_all_craft_recipes(name)
--    if not recipes then return nil end
--
--    local fake_name = get_fake_name(name)
--
--    for _, recipe in ipairs(recipes) do
--        local method = recipe.method or "normal"
--        local items = recipe.items or recipe.recipe
--        assert(items, "Recipe items missing for " .. name)
--
--        local items_to_process = (type(items) == "table") and items or {items}
--        local all_combinations = get_recipe_combinations(items_to_process)
--
--        for _, combo_items in ipairs(all_combinations) do
--            local has_fake = false
--            local used_mese, used_diamond = false, false
--
--            -- Evaluate this specific combination
--            for _, ing in ipairs(combo_items) do
--                if type(ing) == "string" then
--                    if ing:find("^fakery:") then has_fake = true end
--                    if ing == "default:mese_crystal" or ing == "fakery:mese" then used_mese = true end
--                    if ing == "default:diamond" or ing == "fakery:diamond" then used_diamond = true end
--                end
--            end
--
--            -- Only register a recipe if it actually uses a counterfeit ingredient
--            if has_fake then
--                -- 1. Ensure Item Definition exists
--                if not minetest.registered_items[fake_name] then
--                    local original_def = minetest.registered_items[name]
--                    if original_def then
--                        local def = table.copy(original_def)
--                        def = ia_counterfeit.apply_standard_enshittification(def, name, used_mese, used_diamond)
--                        
--                        log(3, "Registering fake variant: " .. fake_name)
--                        if def.drawtype or minetest.registered_nodes[name] then
--                            minetest.register_node(":" .. fake_name, def)
--                        else
--                            minetest.register_craftitem(":" .. fake_name, def)
--                        end
--                    end
--                end
--
--                -- 2. Register the specific combination
--                local craft_def = {
--                    output = fake_name .. " " .. ItemStack(recipe.output):get_count(),
--                    type = (method ~= "normal") and method or (method == "normal" and recipe.width == 0 and "shapeless" or nil)
--                }
--
--                if method == "normal" and recipe.width > 0 then
--                    local grid = {}
--                    for y = 0, math.floor((#combo_items - 1) / recipe.width) do
--                        local row = {}
--                        for x = 1, recipe.width do table.insert(row, combo_items[y * recipe.width + x] or "") end
--                        table.insert(grid, row)
--                    end
--                    craft_def.recipe = grid
--                else
--                    craft_def.recipe = (method == "cooking" or method == "fuel") and combo_items[1] or combo_items
--                end
--
--                minetest.register_craft(craft_def)
--                ia_counterfeit.substitutions[name] = fake_name
--            end
--        end
--    end
--    return ia_counterfeit.substitutions[name]
--end
