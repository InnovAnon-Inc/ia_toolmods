-- ia_toolmods/init.lua
-- Handles creation of Enhanced, Poopy, and Fake item variants.
-- Logic combined and deduplicated from iaenhance, pooper, and iafakery.
-- core.get_all_craft_recipes(query item): returns a table or nil
--   returns indexed table with all registered recipes for query item (node) or nil if no recipe was found.
--   recipe entry table:
--     method: 'normal' or 'cooking' or 'fuel'
--     width: 0-3, 0 means shapeless recipe
--     items: indexed [1-9] table with recipe items
--     output: string with item name and quantity


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

-- NEW HELPER: Specifically handles registration of the Fake variant object.
-- This ensures that if the source is a node, the fake is registered as a node.
local function register_fake_variant(name, original_def)
    local v_name, i_name, alias = get_variant_names(name, "fake")
    
    -- FIXED: Check both items and nodes to prevent double registration
    if minetest.registered_items[i_name] or minetest.registered_nodes[i_name] then 
        return i_name 
    end

    local f_def = apply_visuals(original_def, nil, "Fake ")
    f_def.tool_capabilities = nil -- Fakes have no functionality
    
    -- FIXED: Check drawtype or if it was retrieved from registered_nodes to decide registration type
    if original_def.drawtype or minetest.registered_nodes[name] then
        minetest.register_node(v_name, f_def)
    else
        minetest.register_craftitem(v_name, f_def)
    end
    minetest.register_alias(alias, i_name)
    
    -- Update substitutions map so downstream recipes can find this fake
    ia_toolmods.substitutions[name] = i_name
    return i_name
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

-- 3. FAKE RECIPE INJECTION --

local function inject_fake_crafts(recipe)
    -- Assertions to ensure valid input state
    assert(recipe ~= nil, "inject_fake_crafts: recipe is nil")
    assert(type(recipe) == "table", "inject_fake_crafts: recipe must be a table")

    --if not recipe.output or not recipe.recipe then
    if not recipe.output or not recipe.items then
	    --minetest.log('inject_fake_crafts() empty: '..recipe.output)
	    return
    end
    minetest.log('inject_fake_crafts() not empty: '..recipe.output)

    local changed = false
    
    -- Recursive helper to handle nested tables in shaped recipes
    -- and perform substitutions based on ia_toolmods.substitutions.
    local function substitute_recursive(r)
        if type(r) == "string" then
            -- Check for exact match in substitutions
            if ia_toolmods.substitutions[r] then
                changed = true
                return ia_toolmods.substitutions[r]
            end
            return r
        elseif type(r) == "table" then
            local new_table = {}
            for k, v in pairs(r) do
                new_table[k] = substitute_recursive(v)
            end
            return new_table
        end
        return r
    end

    -- Process the recipe for substitutions
    --local sub_recipe = substitute_recursive(recipe.recipe)
    local sub_recipe = substitute_recursive(recipe.items)
    
    -- If substitutions were made, register the fake variant
    if changed then
        local output_stack = ItemStack(recipe.output)
        local output_name = output_stack:get_name()
        
        -- Prevent infinite recursion by ignoring items already in the fakery mod
        if output_name:match("^fakery:") then return end

        local v_name, i_name, alias = get_variant_names(output_name, "fake")
        if not v_name then
            minetest.log('no v_name for '..output_name)
            return
        end

        -- FIXED: Check both registered_items and registered_nodes to find the original def
        if not minetest.registered_items[i_name] and not minetest.registered_nodes[i_name] then
            local original_def = minetest.registered_nodes[output_name] or minetest.registered_items[output_name]
            if original_def then
                -- CHANGE: Using the new helper to correctly register nodes/items
                register_fake_variant(output_name, original_def)
            end
        end

        -- Create and register the new craft with substituted materials
        --local fake_craft = table.copy(recipe)
        local fake_craft = {}
        fake_craft.recipe = sub_recipe
        output_stack:set_name(i_name)
        fake_craft.output = output_stack:to_string()

	if recipe.type ~= "normal" then
		fake_craft.type = recipe.type
	end
	assert(minetest.registered_nodes[output_name] or minetest.registered_items[output_name])
	minetest.log('fake_craft.recipe: '..tostring(fake_craft.recipe)..'    |    '..tostring(recipe.items))
	minetest.log('fake_craft.output: '..fake_craft.output          ..'    |    '..recipe.output)
	minetest.log('fake_craft.type  : '..tostring(fake_craft.type)  ..'    |    '..tostring(recipe.type))
        
        -- Ensure the output name is valid before registration
        assert(v_name ~= "", "inject_fake_crafts: generated variant name is empty")
        minetest.register_craft(fake_craft)
    elseif not recipe.output:match("^fakery:") and not recipe.output:match("^pooper:") then
        minetest.log('no change for '..recipe.output)
    end
end

-- 4. BOOTSTRAP --

function ia_toolmods.init()
    minetest.log("action", "[ia_toolmods] Iterating tools and recipes for legacy variants...")
    
    -- 1. Register Hook for any dynamic crafts
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

        for name, def in pairs(current_tools) do
            local mod_part = name:match("([^:]+):")
            -- Register Enhanced version if it's not already enhanced or fake
            if mod_part ~= "enhanced" and mod_part ~= "fakery" then
                ia_toolmods.register_enhanced_tool(name, def)
            end
            -- Register Poopy version if it's not already poopy or fake
            if mod_part ~= "pooper" and mod_part ~= "fakery" then
                ia_toolmods.register_poopy_tool(name, def)
            end
        end
    end

    process_all_tools() -- Pass 1: Base -> Enhanced/Poopy
    process_all_tools() -- Pass 2: Enhanced/Poopy -> Mixed variants

    -- 3. Retroactive Fake Recipe Injection (Multi-pass for downstream dependencies)
    local function process_all_recipes()
        -- Combine items and nodes for iteration
        local all_items = {}
        for name, _ in pairs(minetest.registered_items) do all_items[name] = true end
        for name, _ in pairs(minetest.registered_nodes) do all_items[name] = true end

        for name, _ in pairs(all_items) do
            if name ~= "" then
                local recipes = minetest.get_all_craft_recipes(name)
                if recipes then
                    for _, recipe in ipairs(recipes) do
--minetest.log('process_all_recipes() name: '..name)
                        inject_fake_crafts(recipe)
                    end
                end
            end
        end
    end

    -- We run 3 passes to handle depth: 
    -- 1. Base materials -> Sub-components (e.g. mese_crystal -> mese)
    -- 2. Sub-components -> Final products (e.g. mese -> meselamp)
    -- 3. Final products -> Complex tools/nodes (buffer pass)
    process_all_recipes() 
    process_all_recipes()
    process_all_recipes()
    
    minetest.log("action", "[ia_toolmods] Logic deployment finished.")
end

minetest.register_on_mods_loaded(ia_toolmods.init)
