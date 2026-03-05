-- ia_fakery/init.lua
-- FIXME fake lights shouldn't work (reliably) ... gotta check the light source property ?
-- FIXME fake nodes/items should (risk) explode or catch fire, especially if they have fake mese
-- FIXME fake nodes/items should not on_use properly; risk of just not working; risk of breaking; risk of injuring user; especially if they have fake diamond
-- FIXME fake nodes/items should (risk) injuring the user / nearby players/mobs
-- TODO any other properties or fields we wanna override with intentional "jankiness" ?
-- TODO use ia_crapht
-- TODO durability decay

assert(minetest.get_modpath('ia_util'))
assert(ia_util ~= nil)
local modname                    = minetest.get_current_modname() or "ia_fakery"
local storage                    = minetest.get_mod_storage()
ia_fakery                        = {
    substitutions = {
        ["default:diamond"]      = "fakery:diamond",
        ["default:mese_crystal"] = "fakery:mese",
    },
    processed_items = {} 
}
local modpath, S                 = ia_util.loadmod(modname)
local log                        = ia_util.get_logger(modname)
local assert                     = ia_util.get_assert(modname)


-- ia_fakery/init.lua
--local modname = minetest.get_current_modname()

-- 1. UTILITIES
local function get_fake_name(name)
    local clean_name = name:match("^:(.+)") or name
    local m_name, i_name = clean_name:match("([^:]+):([^:]+)")
    if not m_name then m_name = "unknown"; i_name = clean_name end
    return "fakery:" .. m_name .. "_" .. i_name
end

---- 2. CORE REGISTRY
----assert(minetest.get_modpath('ia_util'))
----local log = ia_util.get_logger(modname)
--
----ia_fakery = {
----    substitutions = {
----        ["default:diamond"]      = "fakery:diamond",
----        ["default:mese_crystal"] = "fakery:mese",
----    },
----    processed_items = {} 
----}
--
---- 3. THE RECURSIVE BUILDER
--local function ensure_fake_variant(name)
--    if ia_fakery.substitutions[name] then
--        return ia_fakery.substitutions[name]
--    end
--    if name:find("^fakery:") then return nil end
--
--    if ia_fakery.processed_items[name] then
--        return nil
--    end
--    ia_fakery.processed_items[name] = true
--
--    local recipes = minetest.get_all_craft_recipes(name)
--    if not recipes then return nil end
--
--    local fake_name = get_fake_name(name)
--
--    for _, recipe in ipairs(recipes) do
--        local method = recipe.method or "normal"
--        local items = recipe.items or recipe.recipe
--        local new_recipe_items = {}
--        local recipe_changed = false
--
--        -- Scan ingredients
--        for i, ingredient in pairs(items) do
--            if type(ingredient) == "string" and ingredient ~= "" then
--                local f_ing = ensure_fake_variant(ingredient)
--                if f_ing then
--                    new_recipe_items[i] = f_ing
--                    recipe_changed = true
--                else
--                    new_recipe_items[i] = ingredient
--                end
--            else
--                new_recipe_items[i] = ingredient or ""
--            end
--        end
--
--        if recipe_changed then
--            -- Ensure definition exists
--            if not minetest.registered_items[fake_name] then
--                local original_def = minetest.registered_items[name]
--                if original_def then
--                    local def = table.copy(original_def)
--                    def.description = "Fake " .. (def.description or name)
--                    def.tool_capabilities = nil
--                    if def.light_source then def.light_source = 0 end
--                    
--                    if def.drawtype or minetest.registered_nodes[name] then
--                        minetest.register_node(":" .. fake_name, def)
--                    else
--                        minetest.register_craftitem(":" .. fake_name, def)
--                    end
--                end
--            end
--
--            -- RECONSTRUCT GRID (Handling the API asymmetry)
--            local craft_def = {
--                output = fake_name .. " " .. ItemStack(recipe.output):get_count(),
--            }
--
--            if recipe.width > 0 then
--                -- Shaped: Convert flat array [1,2,3,4,5,6] to {{1,2,3},{4,5,6}}
--                local grid = {}
--                for y = 0, math.floor((#new_recipe_items - 1) / recipe.width) do
--                    local row = {}
--                    for x = 1, recipe.width do
--                        table.insert(row, new_recipe_items[y * recipe.width + x] or "")
--                    end
--                    table.insert(grid, row)
--                end
--                craft_def.recipe = grid
--                craft_def.type = (method ~= "normal") and method or nil
--            else
--                -- Shapeless
--                craft_def.type = "shapeless"
--                craft_def.recipe = new_recipe_items
--            end
--
--            -- Final assertion to catch issues before passing to engine
--            assert(craft_def.recipe ~= nil, "Recipe construction failed for " .. name)
--            
--            minetest.register_craft(craft_def)
--            ia_fakery.substitutions[name] = fake_name
--        end
--    end
--
--    return ia_fakery.substitutions[name]
--end
--
---- 4. BOOTSTRAP
--function ia_fakery.init()
--    log(3, "Deep-navigating tree with grid reconstruction...")
--    
--    local all_items = {}
--    for name, _ in pairs(minetest.registered_items) do 
--        table.insert(all_items, name) 
--    end
--    
--    for _, name in ipairs(all_items) do
--        ensure_fake_variant(name)
--    end
--    
--    log(3, "Fakery Tree Navigation Complete.")
--end
--
--minetest.register_on_mods_loaded(ia_fakery.init)
-- ia_fakery/init.lua

-- Utility to apply "jank" to fake items
-- ia_fakery/init.lua (Updated Enshittification Logic)

-- TODO we might detect whether a player is using a fake compressor or a fake airtank in a compressor, and blow it tf up
-- TODO our magic books that generate really useful reports... obv those have gotta f their data before generating the report. decision makers love bad intel. to handle this, we can actually add a _fakery field to the def in those gutenberg book mods, and consume it here. that is: application-specific enshittification, as well as a default fallback. in this case... we can probably just f the text displayed by any book as a naive default fallback.

local function apply_enshittification(def, name, used_mese, used_diamond)
	-- NOTE would be pretty funny if we can make it a little... "sticky"... like a lode stone... so it has a chance to ... just refuse to be dropped.... or switched from the hand. not a permanent thing. maybe ya gotta try dropping it a few times.

    -- 1. Worse Than Wood Tool Capabilities
    -- Wood is usually 2.0s, we'll go for 5.0s to 10.0s "swing lag"
    if def.tool_capabilities or name:find("tool") or name:find("pick") then
        def.tool_capabilities = {
            full_punch_interval = 8.0, -- Frustratingly slow
            max_drop_level = 0,
            groupcaps = {
                crumbly = {times={[1]=60, [2]=40, [3]=20}, uses=5, maxlevel=1},
                cracky   = {times={[1]=60, [2]=40, [3]=20}, uses=5, maxlevel=1},
                snappy   = {times={[1]=60, [2]=40, [3]=20}, uses=5, maxlevel=1},
            },
            damage_groups = {fleshy=1},
        }
    end

    -- 2. The "Segfault" Branch (Random Failure)
    -- Instead of returning the intended value/action, we just... don't.
    local old_on_rightclick = def.on_rightclick
    def.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        if math.random() < 0.15 then
            log(2, "Interaction 'segfault' at " .. minetest.pos_to_string(pos))
	    -- TODO maybe do nothing, maybe break, maybe injure the player, maybe break and injure the player
	    -- TODO if made with mese, then explosions and fire are cool, too
            -- We return the itemstack unchanged and do nothing. 
            -- The player clicks, the animation plays, but the UI/Action never triggers.
            return itemstack 
        end
        if old_on_rightclick then 
            return old_on_rightclick(pos, node, clicker, itemstack, pointed_thing) 
        end
    end

    -- 3. The "Structural Instability" (Diamond)
    if used_diamond then
        local old_on_use = def.on_use
        def.on_use = function(itemstack, user, pointed_thing)
	    -- TODO maybe do nothing, maybe break, maybe injure the player, maybe break and injure the player
	    -- TODO if made with mese, then explosions and fire are cool, too
            -- 10% chance to injure player and break tool
            if math.random() < 0.10 then
                if user then
                    user:set_hp(user:get_hp() - 1)
                    -- Use the standard break sound, no farts.
                    minetest.sound_play("default_tool_breaks", {pos = user:get_pos(), gain = 0.5})
                end
                itemstack:take_item()
                return itemstack
            end
            if old_on_use then return old_on_use(itemstack, user, pointed_thing) end
        end
    end

    -- 4. The "Short Circuit" (Mese)
    if used_mese then
        local old_on_punch = def.on_punch
	    -- TODO maybe do nothing, maybe break, maybe injure the player, maybe break and injure the player
	    -- TODO if made with mese, then explosions and fire are cool, too
        def.on_punch = function(pos, node, puncher, pointed_thing)
            -- 5% chance to set the node (and player) on fire
            if math.random() < 0.05 then
                minetest.set_node(pos, {name = "fire:basic_flame"})
                return 
            end
            if old_on_punch then return old_on_punch(pos, node, puncher, pointed_thing) end
        end
    end

    -- Subtle visual hint in the description
    --def.description = def.description .. "\n" .. minetest.colorize("#555555", "Serial No: " .. math.random(1000, 9999) .. "-ERR") -- NOTE sneaky
    
    return def
end

-- Updated Recursive Builder
local function ensure_fake_variant(name)
    if ia_fakery.substitutions[name] then return ia_fakery.substitutions[name] end
    if name:find("^fakery:") or ia_fakery.processed_items[name] then return nil end
    ia_fakery.processed_items[name] = true

    local recipes = minetest.get_all_craft_recipes(name)
    if not recipes then return nil end

    local fake_name = "fakery:" .. name:gsub(":", "_")

    for _, recipe in ipairs(recipes) do
        local items = recipe.items or recipe.recipe
        local new_recipe_items = {}
        local recipe_changed = false
        local used_mese = false
        local used_diamond = false

	-- TODO make sure we allow "substitutions": to make a fake item that requires some number of mese crystals and/or diamonds, we just need any one of them to be fake
        for i, ingredient in pairs(items) do
            if type(ingredient) == "string" and ingredient ~= "" then
                -- Track ingredient types for specific enshittification
                if ingredient == "default:mese_crystal" or ingredient == "fakery:mese" then used_mese = true end
                if ingredient == "default:diamond" or ingredient == "fakery:diamond" then used_diamond = true end

                local f_ing = ensure_fake_variant(ingredient)
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

	-- NOTE it's funnier to be unreliable than to reliably not work at all
        if recipe_changed then
            if not minetest.registered_items[fake_name] then
                local original_def = minetest.registered_items[name]
                if original_def then
                    local def = table.copy(original_def)
                    --def.description = "Fake " .. (def.description or name) -- NOTE sneaky
                    
                    -- APPLY JANK
                    def = apply_enshittification(def, name, used_mese, used_diamond)
                    
                    -- Strip useful properties
                    def.tool_capabilities = nil
                    def.light_source = 0 -- Fake lights don't work -- TODO can we make these more dynamic? i.e., the light source does work. sometimes it flickers. sometimes (especially when it's the only light source in a very dark place), it just goes out completely. even funnier if it starts working again when the surrounding area is bright again.

                    if def.drawtype or minetest.registered_nodes[name] then
                        minetest.register_node(":" .. fake_name, def)
                    else
                        minetest.register_craftitem(":" .. fake_name, def)
                    end
                end
            end

            -- [Recipe Grid Reconstruction Logic Preserved From Previous Step]
            local craft_def = {
                output = fake_name .. " " .. ItemStack(recipe.output):get_count(),
            }
            if recipe.width > 0 then
                local grid = {}
                for y = 0, math.floor((#new_recipe_items - 1) / recipe.width) do
                    local row = {}
                    for x = 1, recipe.width do table.insert(row, new_recipe_items[y * recipe.width + x] or "") end
                    table.insert(grid, row)
                end
                craft_def.recipe = grid
            else
                craft_def.type = "shapeless"
                craft_def.recipe = new_recipe_items
            end
            minetest.register_craft(craft_def)
            ia_fakery.substitutions[name] = fake_name
        end
    end
    return ia_fakery.substitutions[name]
end

-- Bootstrap
minetest.register_on_mods_loaded(function()
    for name, _ in pairs(minetest.registered_items) do
        ensure_fake_variant(name)
    end
end)
