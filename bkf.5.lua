-- ia_toolmods/init.lua
-- Handles creation of Enhanced, Poopy, and Fake item variants.
-- Logic combined and deduplicated from iaenhance, pooper, and iafakery.

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

-- CHANGE: Recursive table dumper for deep inspection of recipe tables.
local function dump_recipe_table(t, indent)
    indent = indent or ""
    if type(t) ~= "table" then return tostring(t) end
    local res = ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            res = res .. indent .. k .. ":\n" .. dump_recipe_table(v, indent .. "  ")
        else
            res = res .. indent .. k .. ": " .. tostring(v) .. " (" .. type(v) .. ")\n"
        end
    end
    return res
end

-- Helper: Generates name strings.
local function get_variant_names(name, variant_key)
    local v = ia_toolmods.variants[variant_key]
    assert(v, "get_variant_names: Invalid variant key: " .. tostring(variant_key))
    
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

-- Handles registration of the Fake variant object.
local function register_fake_variant(name, original_def)
    local v_name, i_name, alias = get_variant_names(name, "fake")
    
    if minetest.registered_items[i_name] or minetest.registered_nodes[i_name] then 
        return i_name 
    end

    local f_def = apply_visuals(original_def, nil, "Fake ")
    f_def.tool_capabilities = nil 
    
    if original_def.drawtype or minetest.registered_nodes[name] then
        minetest.register_node(v_name, f_def)
    else
        minetest.register_craftitem(v_name, f_def)
    end
    minetest.register_alias(alias, i_name)
    
    ia_toolmods.substitutions[name] = i_name
    return i_name
end

-- 2. ENHANCEMENT LOGIC --

function ia_toolmods.register_enhanced_tool(name, def)
    local v_name, i_name, alias = get_variant_names(name, "enhanced")
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
    assert(type(recipe) == "table", "inject_fake_crafts: recipe must be a table")

    -- Engine uses .items for existing recipes; registration uses .recipe
    local craft_items = recipe.items or recipe.recipe
    if not recipe.output or not craft_items then return end

    local changed = false
    
    local function substitute_recursive(r)
        if type(r) == "string" then
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

    local sub_items = substitute_recursive(craft_items)
    
    if changed then
        local output_stack = ItemStack(recipe.output)
        local output_name = output_stack:get_name()
        
        -- Avoid recursing into our own variants
        if output_name:match("^fakery:") then return end

        local v_name, i_name, alias = get_variant_names(output_name, "fake")

        -- Ensure original exists before registering fake
        local original_def = minetest.registered_nodes[output_name] or minetest.registered_items[output_name]
        if not original_def then
            minetest.log("warning", "[ia_toolmods] Cannot find original def for " .. output_name)
            return
        end

        if not minetest.registered_items[i_name] and not minetest.registered_nodes[i_name] then
            register_fake_variant(output_name, original_def)
        end

        -- Prepare the new craft
        local fake_craft = {}
        fake_craft.recipe = sub_items
        output_stack:set_name(i_name)
        fake_craft.output = output_stack:to_string()
        
        -- Handle method vs type
        local r_type = recipe.type or recipe.method
        if r_type and r_type ~= "normal" then
            fake_craft.type = r_type
        end
        
        if recipe.width and recipe.width > 0 then
            fake_craft.width = recipe.width
        end

        -- CHANGE: Intense logging before the call that crashes
        minetest.log("action", "[ia_toolmods] REGISTERING FAKE CRAFT")
        minetest.log("action", "  Output string: '" .. tostring(fake_craft.output) .. "'")
        minetest.log("action", "  Target name: '" .. i_name .. "'")
        minetest.log("action", "  Recipe Type: " .. tostring(fake_craft.type or "normal"))
        minetest.log("action", "  Full Table Dump:\n" .. dump_recipe_table(fake_craft, "    "))

        -- Assertion check for the output string format
        assert(fake_craft.output:match("^fakery:"), "Malformed output string: " .. fake_craft.output)

        --minetest.register_craft(fake_craft)
    end
end

-- 4. BOOTSTRAP --

function ia_toolmods.init()
    minetest.log("action", "[ia_toolmods] Iterating tools and recipes for legacy variants...")
    
    local old_register_craft = minetest.register_craft
    minetest.register_craft = function(recipe)
        old_register_craft(recipe)
        inject_fake_crafts(recipe)
    end

    local function process_all_tools()
        local current_tools = {}
        for name, def in pairs(minetest.registered_tools) do
            current_tools[name] = def
        end

        for name, def in pairs(current_tools) do
            local mod_part = name:match("([^:]+):")
            if mod_part ~= "enhanced" and mod_part ~= "fakery" then
                ia_toolmods.register_enhanced_tool(name, def)
            end
            if mod_part ~= "pooper" and mod_part ~= "fakery" then
                ia_toolmods.register_poopy_tool(name, def)
            end
        end
    end

    process_all_tools()
    process_all_tools()

    local function process_all_recipes()
        local all_items = {}
        for name, _ in pairs(minetest.registered_items) do all_items[name] = true end
        for name, _ in pairs(minetest.registered_nodes) do all_items[name] = true end

        for name, _ in pairs(all_items) do
            if name ~= "" then
                local recipes = minetest.get_all_craft_recipes(name)
                if recipes then
                    for _, recipe in ipairs(recipes) do
                        inject_fake_crafts(recipe)
                    end
                end
            end
        end
    end

    process_all_recipes() 
    process_all_recipes()
    process_all_recipes()
    
    minetest.log("action", "[ia_toolmods] Logic deployment finished.")
end

minetest.register_on_mods_loaded(ia_toolmods.init)
