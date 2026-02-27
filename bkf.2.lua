-- ia_toolmods/init.lua

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

-- [Helper] Centralized naming logic
local function get_variant_names(name, variant_key)
    assert(name and type(name) == "string", "get_variant_names: name must be a string")
    
    local v = ia_toolmods.variants[variant_key]
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

-- [Helper] Applies visual overlays and prefixes
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
    --new_def.groups.not_in_creative_inventory = 1
    new_def.groups.not_in_creative_inventory = 0
    return new_def
end

-- [Feature] Register Enhanced variants
function ia_toolmods.register_enhanced_tool(name, def)
    local v_name, i_name, alias = get_variant_names(name, "enhanced")
    if not i_name or minetest.registered_tools[i_name] then return end

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

-- [Feature] Register Poopy variants
function ia_toolmods.register_poopy_tool(name, def)
    local v_name, i_name, alias = get_variant_names(name, "poopy")
    if not i_name or minetest.registered_tools[i_name] then return end

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

-- [Feature] Register Fake variants
function ia_toolmods.register_fake_tool(name, def)
    local v_name, i_name, alias = get_variant_names(name, "fake")
    if not i_name or minetest.registered_items[i_name] then return end

    local f_def = apply_visuals(def, nil, "Fake ")
    f_def.tool_capabilities = nil
    
    -- If the original was a node, we need to ensure it has an inventory_image
    -- for the craftitem registration to look right, otherwise fallback to tile
    if not f_def.inventory_image and f_def.tiles then
        f_def.inventory_image = f_def.tiles[1]
    end

    minetest.register_craftitem(v_name, f_def)
    minetest.register_alias(alias, i_name)
end

-- [Refactor] Safe recipe injection
local function inject_fake_crafts(recipe)
    if not recipe or not recipe.output or type(recipe.output) ~= "string" then return end

    local output_name = recipe.output:match("^(%S+)")
    if not output_name then return end
    
    local output_suffix = recipe.output:match("^%S+(.*)$") or ""
    
    -- CHANGE: Allow faking of enhanced/pooper variants, only skip items already in fakery
    local mod_prefix = output_name:match("([^:]+)")
    if mod_prefix == "fakery" then
	    minetest.log('skip '..output_name)
	    return
    end

    local _, fake_output, _ = get_variant_names(output_name, "fake")
    if not fake_output or fake_output == output_name then
	    minetest.log('no variant names for '..output_name)
	    return
    end

    if not recipe.recipe or type(recipe.recipe) ~= "table" then
	    minetest.log('no recipe for '..output_name)
	    return
    end

    local new_recipe_data = table.copy(recipe.recipe)
    local found_sub = false

    local function sub_list(l)
        if not l or type(l) ~= "table" then return end
        for i, v in pairs(l) do
            if type(v) == "table" then
                sub_list(v)
            elseif type(v) == "string" then
                if ia_toolmods.substitutions[v] then
                    l[i] = ia_toolmods.substitutions[v]
                    found_sub = true
                end
            end
        end
    end

    sub_list(new_recipe_data)

    if found_sub then
	    minetest.log('found sub '..output_name)
        -- Ensure the fake item is registered (works for nodes/items now)
        if not minetest.registered_items[fake_output] then
            local original_def = minetest.registered_items[output_name]
            if original_def then
                ia_toolmods.register_fake_tool(output_name, original_def)
            end
        end

        assert(minetest.registered_items[fake_output])
        --if minetest.registered_items[fake_output] then
            minetest.register_craft({
                type = recipe.type,
                output = fake_output .. output_suffix,
                recipe = new_recipe_data,
                replacements = recipe.replacements
            })
        --end
    else
	    minetest.log('no sub for '..output_name)
    end
end

-- [Main]
minetest.register_on_mods_loaded(function()
    minetest.log("action", "[ia_toolmods] Starting variant registration...")

    local initial_items = {}
    for name, def in pairs(minetest.registered_items) do
        initial_items[name] = def
    end

    -- Pass 1: Base tools -> Enhanced/Poopy
    for name, def in pairs(initial_items) do
        local mod_part = name:match("([^:]+):")
        if def.tool_capabilities or name:find(":pick_") or name:find(":axe_") then
            if mod_part ~= "enhanced" and mod_part ~= "fakery" then
                ia_toolmods.register_enhanced_tool(name, def)
            end
            if mod_part ~= "pooper" and mod_part ~= "fakery" then
                ia_toolmods.register_poopy_tool(name, def)
            end
        end
    end

    -- Pass 2: Mixed variants (Enhanced <-> Poopy)
    for name, def in pairs(minetest.registered_items) do
        if not initial_items[name] then
            local mod_part = name:match("([^:]+):")
            if mod_part == "enhanced" then
                ia_toolmods.register_poopy_tool(name, def)
            elseif mod_part == "pooper" then
                ia_toolmods.register_enhanced_tool(name, def)
            end
        end
    end

    -- Pass 3: Craft Injection (The true source of Fakes)
    -- This handles everything: nodes (Mese Lamp), items (Diamond Block), etc.
    for name, _ in pairs(minetest.registered_items) do
        if name and name ~= "" then
            local recipes = minetest.get_all_craft_recipes(name)
            if recipes then
                for _, recipe in ipairs(recipes) do
                    inject_fake_crafts(recipe)
                end
            end
        end
    end
    
    minetest.log("action", "[ia_toolmods] Registration complete.")
end)
