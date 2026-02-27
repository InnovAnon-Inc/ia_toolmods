-- ia_toolmods/init.lua
-- must add:
-- - mese-enhanced items/nodes
-- - poop-enhanced items
-- - poopy-mese-enhanced items
-- - fake-mese items/nodes
-- - fake-poopy items
-- - fake-poopy-mese items

-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_axe_mese -> :fakery:enhanced_pooper_default_axe_mese
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_axe_diamond -> :fakery:enhanced_pooper_default_axe_diamond
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_pick_stone -> :fakery:enhanced_pooper_default_pick_stone
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_axe_stone -> :fakery:enhanced_pooper_default_axe_stone
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_pick_mese -> :fakery:enhanced_pooper_default_pick_mese
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_pick_steel -> :fakery:enhanced_pooper_default_pick_steel
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_shovel_steel -> :fakery:enhanced_pooper_default_shovel_steel
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_farming_hoe_bronze -> :fakery:enhanced_pooper_farming_hoe_bronze
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_pick_bronze -> :fakery:enhanced_pooper_default_pick_bronze
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_axe_bronze -> :fakery:enhanced_pooper_default_axe_bronze
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_sword_mese -> :fakery:enhanced_pooper_default_sword_mese
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_default_shovel_wood -> :fakery:enhanced_pooper_default_shovel_wood
-- 2026-02-27 13:07:32: WARNING[ServerStart]: Not registering alias, item with same name is already defined: fakery:enhanced_pooper_farming_hoe_diamond -> :fakery:enhanced_pooper_farming_hoe_diamond

local modname = minetest.get_current_modname() or "ia_toolmods"

ia_toolmods = {
    variants = {
        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced", mod = "enhanced" },
        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper",   mod = "pooper"   },
        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake",     mod = "fakery"   }
    },
    substitutions = {
        ["default:diamond"]      = "fakery:diamond",
        ["default:mese_crystal"] = "fakery:mese",
    }
}

-- 1. UTILITIES --

-- Helper: Generates name strings.
-- technical_name: used for minetest.register_* (with leading colon)
-- internal_name: the name the engine actually uses (mod:item)
local function get_variant_names(name, variant_key)
    local v = ia_toolmods.variants[variant_key]
    -- Handle names with or without leading colons
    local clean_name = name:match("^:(.+)") or name
    local m_name, i_name = clean_name:match("([^:]+):([^:]+)")
    
    if not m_name or not i_name then
        m_name = "unknown"
        i_name = clean_name:gsub(":", "_")
    end

    local internal_name = v.mod .. ":" .. m_name .. "_" .. i_name
    local technical_name = ":" .. internal_name
    local alias_name = clean_name .. v.suffix
    
    return technical_name, internal_name, alias_name
end

-- Helper: Applies visual changes and common group settings.
local function apply_visuals(def, color, prefix)
    local new_def = table.copy(def)
    if prefix and new_def.description then
        new_def.description = prefix .. new_def.description
    end
    if color then
        local overlay = "^[colorize:" .. color .. ":40"
        if new_def.inventory_image then
            new_def.inventory_image = new_def.inventory_image .. overlay
        end
        if new_def.wield_image then
            new_def.wield_image = new_def.wield_image .. overlay
        end
    end
    
    new_def.groups = table.copy(new_def.groups or {})
    return new_def
end

-- 2. ENHANCEMENT LOGIC --

function ia_toolmods.register_enhanced_tool(name, def)
    local v_name, i_name, alias = get_variant_names(name, "enhanced")
    -- Prevent double registration
    if minetest.registered_tools[i_name] then return end

    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
    
    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
            if group.times then
                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
            end
        end
    end

    minetest.register_tool(v_name, e_def)
    minetest.register_alias(alias, i_name)
    
    minetest.register_craft({
        type = "shapeless",
        output = i_name,
        recipe = {name, "default:mese_crystal"},
    })
end

function ia_toolmods.register_poopy_tool(name, def)
    local v_name, i_name, alias = get_variant_names(name, "poopy")
    -- Prevent double registration
    if minetest.registered_tools[i_name] then return end

    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")

    p_def.on_use = function(itemstack, user, pointed_thing)
        if pointed_thing and pointed_thing.type == "object" then
            local target = pointed_thing.ref
            if target and target:is_player() then
                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
                itemstack:set_name(name)
                return itemstack
            end
        end
        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
    end

    minetest.register_tool(v_name, p_def)
    minetest.register_alias(alias, i_name)
    
    minetest.register_craft({
        type = "shapeless",
        output = i_name,
        recipe = {name, "pooper:poop_turd"},
    })
end

-- 3. FAKERY LOGIC --

local function get_substituted_recipes(recipe_table)
    local found_sub = false
    local new_recipe = table.copy(recipe_table)
    for i, item in ipairs(new_recipe) do
        if type(item) == "table" then
            local sub_item, sub_found = get_substituted_recipes(item)
            new_recipe[i] = sub_item
            if sub_found then found_sub = true end
        elseif type(item) == "string" then
            -- Check for substitutions
            for orig, sub in pairs(ia_toolmods.substitutions) do
                if item == orig then
                    new_recipe[i] = sub
                    found_sub = true
                end
            end
        end
    end
    return new_recipe, found_sub
end

local oop_count = 0
local wee_count = 0
local wee       = {}
local function inject_fake_crafts(recipe)
    if not recipe.output or recipe.type == "fuel" then return end
    
    local output_stack = ItemStack(recipe.output)
    local output_name = output_stack:get_name()
    
    -- Avoid recursion on fake items themselves
    if output_name:match("^fakery:") then return end

    minetest.log('ia_toolmods.inject_fake_crafts() output     : '..recipe.output)
    minetest.log('ia_toolmods.inject_fake_crafts() output_name: '..output_name)
    minetest.log('ia_toolmods.inject_fake_crafts() type       : '..recipe.type)
    minetest.log('ia_toolmods.inject_fake_crafts() method     : '..tostring(recipe.method)) -- can be nil
    minetest.log('ia_toolmods.inject_fake_crafts() width      : '..tostring(recipe.width)) -- can be nil
    --local recipe_data = recipe.recipe
    local recipe_data = recipe.recipe or recipe.items
    assert(output_name ~= "")
    assert(recipe_data ~= nil)
    assert(recipe.type == "normal" or recipe.type == "shapeless" or recipe.type == "cooking")
    local sub_recipe, found = get_substituted_recipes(recipe_data)
    if not found then
        minetest.log('no substitutions')
        return
    end
        local v_name, i_name, alias = get_variant_names(output_name, "fake")
        
        -- Register the fake item if it doesn't exist
        if not minetest.registered_items[i_name] then
            local original_def = minetest.registered_items[output_name]
            if original_def then
                local f_def = apply_visuals(original_def, nil, "Fake ")
                -- Fake tools can't dig
                f_def.tool_capabilities = nil
                -- Register as craftitem (default) unless it's a node
                if original_def.drawtype then
                    minetest.register_node(v_name, f_def)
                else
                    minetest.register_craftitem(v_name, f_def)
                end
                minetest.register_alias(alias, i_name)
            end
        end

--        local fake_craft = table.copy(recipe)
--        fake_craft.recipe = sub_recipe
        output_stack:set_name(i_name)
--        fake_craft.output = output_stack:to_string()
--	assert(fake_craft.type == "normal" or fake_craft.type == "shapeless" or fake_craft.type == "cooking")
--	if fake_craft.type == "normal" then -- FIXME
--            --fake_craft.type = "shaped"
--            fake_craft.type = nil
--	end
        local fake_craft = {}
	fake_craft    .recipe = sub_recipe
	fake_craft    .output = output_stack:to_string()
	if recipe.type ~= "normal" then
            fake_craft.type   = recipe.type
	elseif recipe.width then
            fake_craft.type   = "shaped"
	else
            fake_craft.type   = nil
	end
        --fake_craft    .type   = (recipe.type ~= "normal" and recipe.type) or (recipe.width and recipe.width > 0 and "shaped" or "shapeless")
	for k,v in pairs(fake_craft.recipe) do
	    minetest.log('k: '..k)
	    minetest.log('v: '..v)
	end
	minetest.log('ia_toolmods.inject_fake_crafts() fake_craft.recipe: '..tostring(fake_craft.recipe))
	minetest.log('ia_toolmods.inject_fake_crafts() fake_craft.output: '..tostring(fake_craft.output))
	minetest.log('ia_toolmods.inject_fake_crafts() fake_craft.type  : '..tostring(fake_craft.type))
	minetest.log('wee: '..wee_count)
	for k,v in ipairs(wee) do
		minetest.log('wee: '..v)
	end
        minetest.register_craft(fake_craft)

	wee_count = wee_count + 1
	table.insert(wee, output_name)
end
------local function inject_fake_crafts(recipe)
------    -- Assertions to catch malformed inputs early
------    assert(recipe and type(recipe) == "table", "inject_fake_crafts: recipe must be a table")
------    if not recipe.recipe or not recipe.output then return end
------    
------    local function substitute(item)
------        if type(item) == "table" then
------            local res = {}
------            for k, v in pairs(item) do res[k] = substitute(v) end
------            return res
------        elseif type(item) == "string" then
------            return ia_toolmods.substitutions[item] or item
------        end
------        return item
------    end
------
------    local sub_recipe = substitute(recipe.recipe)
------    
------    -- Only proceed if substitutions actually changed the recipe
------    if dump(sub_recipe) ~= dump(recipe.recipe) then
------        local output_stack = ItemStack(recipe.output)
------        local output_name = output_stack:get_name()
------        
------        -- Prevent faking items that are already part of the fakery mod
------        -- Added check for the "fakery" mod prefix to prevent recursive naming
------        local current_mod = output_name:match("([^:]+)")
------        if current_mod == "fakery" then return end
------
------        -- FIX: Handle existing prefixes correctly to avoid "fakery:mod:item" (double colon)
------        -- We use get_variant_names which is designed to handle mod/item separation safely.
------        local v_name_raw, alias = get_variant_names(output_name, "fake")
------        
------        -- Use the ":" prefix to bypass the "modname prefix required" validation error
------        -- ensuring the engine treats this as a global registration for the specific mod prefix.
------        local v_name = ":" .. v_name_raw
------        
------        -- If the fake item doesn't exist yet, register it
------        if not minetest.registered_items[v_name] then
------            local original_def = minetest.registered_items[output_name]
------            if original_def then
------                local f_def = apply_visuals(original_def, nil, "Fake ")
------                f_def.tool_capabilities = nil -- Fakes have no stats
------                minetest.register_craftitem(v_name, f_def)
------                minetest.register_alias(alias, v_name)
------            else
------                -- Log skip if the base item definition is missing
------                return 
------            end
------        end
------
------        -- Register the new fake craft
------        local fake_craft = {
------            output = v_name .. " " .. output_stack:get_count(),
------            recipe = sub_recipe,
------            -- Ensure we preserve the original craft type (e.g., "shapeless")
------            type = recipe.type or (recipe.width and recipe.width > 0 and "normal" or nil),
------            width = recipe.width
------        }
------        
------        minetest.register_craft(fake_craft)
------    end
------end
------ 3. FAKE RECIPE INJECTION --
----
----local function inject_fake_crafts(recipe)
----    -- Assertions to ensure valid input state
----    assert(recipe ~= nil, "inject_fake_crafts: recipe is nil")
----    assert(type(recipe) == "table", "inject_fake_crafts: recipe must be a table")
----
----    if not recipe.output or not recipe.recipe then return end
----
----    local changed = false
----    
----    -- Recursive helper to handle nested tables in shaped recipes
----    -- and perform substitutions for diamonds/mese.
----    local function substitute_recursive(r)
----        if type(r) == "string" then
----            -- Check for exact match or group match
----            if ia_toolmods.substitutions[r] then
----                changed = true
----                return ia_toolmods.substitutions[r]
----            end
----            return r
----        elseif type(r) == "table" then
----            local new_table = {}
----            for k, v in pairs(r) do
----                new_table[k] = substitute_recursive(v)
----            end
----            return new_table
----        end
----        return r
----    end
----
----    -- Process the recipe for substitutions
----    local sub_recipe = substitute_recursive(recipe.recipe)
----    
----    -- If substitutions were made, register the fake variant
----    if changed then
----        local output_stack = ItemStack(recipe.output)
----        local output_name = output_stack:get_name()
----        
----        -- Prevent infinite recursion by ignoring items already in the fakery mod
----        if output_name:match("^fakery:") then return end
----
----        local v_name, alias = get_variant_names(output_name, "fake")
----        if not v_name then return end
----
----        -- Register the fake item definition if it doesn't exist yet
----        if not minetest.registered_items[v_name] then
----            local original_def = minetest.registered_items[output_name]
----            if original_def then
----                local f_def = apply_visuals(original_def, nil, "Fake ")
----                f_def.tool_capabilities = nil -- Fakes have no functionality
----                minetest.register_craftitem(v_name, f_def)
----                minetest.register_alias(alias, v_name)
----            end
----        end
----
----        -- Create and register the new craft with substituted materials
----        local fake_craft = table.copy(recipe)
----        fake_craft.recipe = sub_recipe
----        output_stack:set_name(v_name)
----        fake_craft.output = output_stack:to_string()
----        
----        -- Ensure the output name is valid before registration
----        assert(v_name ~= "", "inject_fake_crafts: generated variant name is empty")
----        minetest.register_craft(fake_craft)
----    end
----end
---- 3. FAKE RECIPE INJECTION --
--
--local function inject_fake_crafts(recipe)
--	-- NOTE default:mese_crystal ==> fakery:mese
--	-- NOTE default:diamond      ==> fakery:diamond
--	-- NOTE default:mese         ==> our fake mese block (which must be created by inject_fake_crafts)... so once we create our fake mese block node & recipe, we've gotta modify all downstream items/nodes/recipes ?
--	-- NOTE if manually creating, e.g., fakery:mese_block, be sure to manually create ALL fake nodes for ALL mods, including ones that we don't know about.
--	
--    -- Assertions to ensure valid input state
--    assert(recipe ~= nil, "inject_fake_crafts: recipe is nil")
--    assert(type(recipe) == "table", "inject_fake_crafts: recipe must be a table")
--
--    if not recipe.output or not recipe.recipe then return end
--
--    -- Expand substitutions to include blocks and groups
--    local subs = ia_toolmods.substitutions
--    subs["default:mese"] = "fakery:mese"
--    subs["group:mese"]   = "fakery:mese"
--
--    local changed = false
--    
--    -- Recursive helper to handle nested tables (shaped recipes) 
--    -- and perform substitutions for diamonds/mese/groups.
--    local function substitute_recursive(r)
--        if type(r) == "string" then
--            -- Check for exact match or group match in our substitution table
--            if subs[r] then
--                changed = true
--                return subs[r]
--            end
--            return r
--        elseif type(r) == "table" then
--            local new_table = {}
--            for k, v in pairs(r) do
--                new_table[k] = substitute_recursive(v)
--            end
--            return new_table
--        end
--        return r
--    end
--
--    -- Process the recipe for substitutions
--    local sub_recipe = substitute_recursive(recipe.recipe)
--    
--    -- If substitutions were made, register the fake variant
--    if changed then
--        local output_stack = ItemStack(recipe.output)
--        local output_name = output_stack:get_name()
--        
--        -- Prevent infinite recursion: ignore items already in the fakery mod
--        if output_name:match("^fakery:") then return end
--
--        -- Get names for the 'fake' version. 
--        -- If output_name is 'enhanced:default_pick_diamond', 
--        -- v_name will be 'fakery:enhanced_default_pick_diamond'
--        local v_name, alias = get_variant_names(output_name, "fake")
--        if not v_name then return end
--
--        -- Register the fake item definition if it doesn't exist yet
--        if not minetest.registered_items[v_name] then
--            local original_def = minetest.registered_items[output_name]
--            if original_def then
--                -- Apply 'Fake ' prefix to the description
--                local f_def = apply_visuals(original_def, nil, "Fake ")
--                -- Fakes are purely cosmetic; they shouldn't function as tools
--                f_def.tool_capabilities = nil 
--                
--                -- Register as a craftitem or node based on the original type
--                if original_def.drawtype or original_def.walkable ~= nil then
--                    minetest.register_node(v_name, f_def)
--                else
--                    minetest.register_craftitem(v_name, f_def)
--                end
--                
--                -- Register the suffix alias (e.g., default:pick_diamond_fake)
--                if alias and alias ~= v_name then
--                    minetest.register_alias(alias, v_name)
--                end
--            end
--        end
--
--        -- Create and register the new craft with substituted materials
--        local fake_craft = table.copy(recipe)
--        fake_craft.recipe = sub_recipe
--        
--        -- Update the output to the fake version
--        output_stack:set_name(v_name)
--        fake_craft.output = output_stack:to_string()
--        
--        -- Final safety check on the name
--        assert(v_name ~= "", "inject_fake_crafts: generated variant name is empty")
--        minetest.register_craft(fake_craft)
--    end
--end
--local function inject_fake_crafts(recipe)
--    if not recipe or not recipe.output or not recipe.recipe then
--	    minetest.log('error')
--	    return
--    end
--
--    local subs = ia_toolmods.substitutions
--    local changed = false
--    
--    -- Helper to recursively replace ingredients with their fake counterparts
--    local function substitute_recursive(r)
--        if type(r) == "string" then
--            if subs[r] then
--                changed = true
--                return subs[r]
--            end
--            return r
--        elseif type(r) == "table" then
--            local new_table = {}
--            for k, v in pairs(r) do
--                new_table[k] = substitute_recursive(v)
--            end
--            return new_table
--        end
--        return r
--    end
--
--    local sub_recipe = substitute_recursive(recipe.recipe)
--    
--    if changed then
--        local output_stack = ItemStack(recipe.output)
--        local output_name = output_stack:get_name()
--        
--        -- Prevent loops: skip if output is already in a variant mod
--        local clean_out = output_name:sub(1,1) == ":" and output_name:sub(2) or output_name
--        local out_mod = clean_out:match("([^:]+):")
--        if out_mod == "fakery" or out_mod == "enhanced" or out_mod == "pooper" then return end
--
--        local v_name, alias = get_variant_names(output_name, "fake")
--        if not v_name then return end
--
--        -- Create the "Fake" variant if it doesn't exist
--        if not minetest.registered_items[v_name:sub(2)] then
--            local original_def = minetest.registered_items[output_name]
--            if original_def then
--                local f_def = apply_visuals(original_def, nil, "Fake ")
--                f_def.tool_capabilities = nil -- Fakes have no functionality
--                
--                -- Register as node if the original was a node, otherwise craftitem
--                if original_def.drawtype or original_def.walkable ~= nil then
--                    minetest.register_node(v_name, f_def)
--                else
--                    minetest.register_craftitem(v_name, f_def)
--                end
--                
--                if alias and ":"..alias ~= v_name then
--                    minetest.register_alias(alias, v_name)
--                end
--            end
--        end
--
--        -- Register the faked recipe
--        local fake_craft = table.copy(recipe)
--        fake_craft.recipe = sub_recipe
--        output_stack:set_name(v_name)
--        fake_craft.output = output_stack:to_string()
--        
--        minetest.register_craft(fake_craft)
--    end
--end

-- 4. BOOTSTRAP --

function ia_toolmods.init()
    minetest.log("action", "[ia_toolmods] Iterating tools and recipes for legacy variants...")
    
    -- 1. Register Hook for any dynamic crafts (e.g. registered in on_mods_loaded by other mods)
    local old_register_craft = minetest.register_craft
    minetest.register_craft = function(recipe)
        old_register_craft(recipe)
        inject_fake_crafts(recipe)
    end

    -- 2. Process Tools (Multiple passes to allow Enhanced Poopy tools)
    local function process_all_tools()
        local current_tools = {}
        for name, def in pairs(minetest.registered_tools) do
            current_tools[name] = def
        end

	-- FIXME we have poopy-enhanced and enhanced-poopy, but we should probably only have one
        for name, def in pairs(current_tools) do
            local mod_part = name:match("([^:]+):")
            -- Register Enhanced version if it's not already enhanced
            if mod_part ~= "enhanced" then
                ia_toolmods.register_enhanced_tool(name, def)
            end
            -- Register Poopy version if it's not already poopy
            if mod_part ~= "pooper" then
                ia_toolmods.register_poopy_tool(name, def)
            end
        end
    end

    process_all_tools() -- Pass 1: Base -> Enhanced/Poopy
    process_all_tools() -- Pass 2: Enhanced/Poopy -> Mixed variants

    -- 3. Retroactive Fake Recipe Injection
    -- We iterate every registered item and check for its recipes
    for name, _ in pairs(minetest.registered_items) do
        --minetest.log(            'ia_toolmods.init() name    : '..name)
        if name ~= "" then
            local recipes = minetest.get_all_craft_recipes(name)
            if recipes then
                --minetest.log(    'ia_toolmods.init() #recipes: '..#recipes)
                for _, recipe in ipairs(recipes) do
                    --minetest.log('ia_toolmods.init() _       : '..tostring(_))
                    --minetest.log('ia_toolmods.init() recipe  : '..tostring(recipe))
                    inject_fake_crafts(recipe)
                end
            elseif name == "enhanced" or name == "pooper" or name == "fakery" then
                minetest.log('ia_toolmods.init() no recipes for '..name)
            end
        end
    end
    
    minetest.log("action", "[ia_toolmods] Logic deployment finished.")
end

minetest.register_on_mods_loaded(ia_toolmods.init)
