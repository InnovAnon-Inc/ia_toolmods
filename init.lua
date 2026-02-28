-- ia_toolmods/init.lua
-- Handles creation of Enhanced, Poopy, and Fake item variants.
-- Logic combined and deduplicated from iaenhance, pooper, and iafakery.
--
-- core.get_all_craft_recipes(query item): returns a table or nil
--   returns indexed table with all registered recipes for query item (node) or nil if no recipe was found.
--   recipe entry table:
--     method: 'normal' or 'cooking' or 'fuel'
--     width: 0-3, 0 means shapeless recipe
--     items: indexed [1-9] table with recipe items
--     output: string with item name and quantity
--
-- FIXME don't need enhanced-poopy + poopy-enhanced unless they have different behaviors

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

local function dump_recipe_table(t, level)
    level = level or 0
    local indent = string.rep("  ", level)
    if type(t) ~= "table" then return tostring(t) end

    local pieces = {"{\n"}
    for k, v in pairs(t) do
        local key = type(k) == "number" and "[" .. k .. "]" or k
        if type(v) == "table" then
            table.insert(pieces, indent .. "  " .. key .. " = " .. dump_recipe_table(v, level + 1) .. ",\n")
        else
            local val = type(v) == "string" and '"' .. v .. '"' or tostring(v)
            table.insert(pieces, indent .. "  " .. key .. " = " .. val .. ",\n")
        end
    end
    table.insert(pieces, indent .. "}")
    return table.concat(pieces)
end

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

-- 3. FAKE RECIPE INJECTION --

local function inject_fake_crafts(recipe)
    assert(recipe ~= nil, "inject_fake_crafts: recipe is nil")
    assert(type(recipe) == "table", "inject_fake_crafts: recipe must be a table")

    local items = recipe.items or recipe.recipe
    if not recipe.output or not items then return end

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
            for k, v in pairs(r) do new_table[k] = substitute_recursive(v) end
            return new_table
        end
        return r
    end

    local sub_items = substitute_recursive(items)

    if changed then
        local output_stack = ItemStack(recipe.output)
        local output_name = output_stack:get_name()
        if output_name:match("^fakery:") then return end

        local v_name, i_name, alias = get_variant_names(output_name, "fake")
        local original_def = minetest.registered_items[output_name] or minetest.registered_nodes[output_name]
        if not original_def then return end

        -- CHANGE: Call local register_fake_variant correctly
        if not minetest.registered_items[i_name] and not minetest.registered_nodes[i_name] then
            register_fake_variant(output_name, original_def)
        end

        local fake_craft = {}
        output_stack:set_name(i_name)
        fake_craft.output = output_stack:to_string()

        -- Mapping logic
        local r_type = recipe.type or recipe.method
        if r_type and r_type ~= "normal" then fake_craft.type = r_type end
        fake_craft.method = recipe.method

        -- CHANGE: Handle grid shapes for Width 0, 1, and >1
        local width = recipe.width or 0
        if width > 1 then
            fake_craft.width = width
            local grid = {}
            local current_row = {}
            local max_idx = 0
            for k in pairs(sub_items) do if type(k) == "number" and k > max_idx then max_idx = k end end
            local total_size = math.ceil(max_idx / width) * width
            for i = 1, total_size do
                table.insert(current_row, sub_items[i] or "")
                if i % width == 0 then
                    table.insert(grid, current_row)
                    current_row = {}
                end
            end
            fake_craft.recipe = grid
        elseif width == 1 then
            fake_craft.width = 1
            local grid = {}
            local max_idx = 0
            for k in pairs(sub_items) do if type(k) == "number" and k > max_idx then max_idx = k end end
            for i = 1, max_idx do table.insert(grid, { sub_items[i] or "" }) end
            fake_craft.recipe = grid
        else
            -- Shapeless
            local flat = {}
            local max_idx = 0
            for k in pairs(sub_items) do if type(k) == "number" and k > max_idx then max_idx = k end end
            for i = 1, max_idx do
                local item = sub_items[i]
                if item and item ~= "" then table.insert(flat, item) end
            end
            fake_craft.recipe = flat
            fake_craft.type = "shapeless"
        end

        --minetest.log('action', '[ia_toolmods] Injecting fake craft for: ' .. fake_craft.output)
        minetest.register_craft(fake_craft)
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
