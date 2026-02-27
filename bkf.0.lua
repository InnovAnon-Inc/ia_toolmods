-- ia_toolmods/init.lua
-------------------- Handles creation of Enhanced, Poopy, and Fake item variants.
-------------------- Logic combined and deduplicated from iaenhance, pooper, and iafakery.
------------------
------------------ia_toolmods = {
------------------    variants = {
------------------        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced", mod = "enhanced" },
------------------        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper",   mod = "pooper"   },
------------------        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake",     mod = "fakery"   }
------------------    },
------------------    substitutions = {
------------------        ["default:diamond"]      = "fakery:diamond",
------------------        ["default:mese_crystal"] = "fakery:mese",
------------------    }
------------------}
------------------
-------------------- 1. UTILITIES --
------------------
------------------local function get_variant_names(name, variant_key)
------------------    local modname, itemname = name:match("([^:]+):([^:]+)")
------------------    local v = ia_toolmods.variants[variant_key]
------------------    return v.mod .. ":" .. modname .. "_" .. itemname, name .. v.suffix
------------------end
------------------
------------------local function apply_visuals(def, color, prefix)
------------------    local new_def = table.copy(def)
------------------    if prefix and new_def.description then
------------------        new_def.description = prefix .. new_def.description
------------------    end
------------------    if color then
------------------        local overlay = "^[colorize:" .. color .. ":40"
------------------        if new_def.inventory_image then
------------------            new_def.inventory_image = new_def.inventory_image .. overlay
------------------        end
------------------        if new_def.wield_image then
------------------            new_def.wield_image = new_def.wield_image .. overlay
------------------        end
------------------    end
------------------    -- Hide from creative to prevent clutter
------------------    new_def.groups = new_def.groups or {}
------------------    new_def.groups.not_in_creative_inventory = 1
------------------    return new_def
------------------end
------------------
-------------------- 2. ENHANCEMENT LOGIC (Mese/Poop) --
------------------
------------------function ia_toolmods.register_enhanced_tool(name, def)
------------------    local v_name, alias = get_variant_names(name, "enhanced")
------------------    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
------------------    
------------------    -- Performance boost (20%)
------------------    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
------------------        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
------------------            if group.times then
------------------                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
------------------            end
------------------        end
------------------    end
------------------
------------------    minetest.register_tool(v_name, e_def)
------------------    minetest.register_alias(alias, v_name)
------------------    minetest.register_craft({
------------------        type = "shapeless",
------------------        output = v_name,
------------------        recipe = {name, "default:mese_crystal"},
------------------    })
------------------end
------------------
------------------function ia_toolmods.register_poopy_tool(name, def)
------------------    local v_name, alias = get_variant_names(name, "poopy")
------------------    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
------------------
------------------    -- Special "Poison" effect on use
------------------    p_def.on_use = function(itemstack, user, pointed_thing)
------------------        if pointed_thing.type == "object" then
------------------            local target = pointed_thing.ref
------------------            if target and target:is_player() then
------------------                -- Force feed the target poop
------------------                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
------------------                -- Tool reverts to normal after "discharging" its payload
------------------                itemstack:set_name(name)
------------------                return itemstack
------------------            end
------------------        end
------------------        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
------------------    end
------------------
------------------    minetest.register_tool(v_name, p_def)
------------------    minetest.register_alias(alias, v_name)
------------------    minetest.register_craft({
------------------        type = "shapeless",
------------------        output = v_name,
------------------        recipe = {name, "pooper:poop_turd"},
------------------    })
------------------end
------------------
-------------------- 3. FAKERY LOGIC (Recursive Recipe Injection) --
------------------
-------------------- Recursively swaps recipe ingredients based on ia_toolmods.substitutions
------------------local function get_substituted_recipes(recipe_table)
------------------    local found_sub = false
------------------    local new_recipe = table.copy(recipe_table)
------------------
------------------    for i, row in ipairs(new_recipe) do
------------------        if type(row) == "table" then
------------------            local sub_row, sub_found = get_substituted_recipes(row)
------------------            new_recipe[i] = sub_row
------------------            if sub_found then found_sub = true end
------------------        elseif type(row) == "string" then
------------------            if ia_toolmods.substitutions[row] then
------------------                new_recipe[i] = ia_toolmods.substitutions[row]
------------------                found_sub = true
------------------            end
------------------        end
------------------    end
------------------    return new_recipe, found_sub
------------------end
------------------
------------------local function inject_fake_crafts(recipe)
------------------    if not recipe.output or recipe.type == "fuel" then return end
------------------    
------------------    local output_stack = ItemStack(recipe.output)
------------------    local output_name = output_stack:get_name()
------------------    
------------------    -- Don't fake things already in the fakery/enhanced/pooper mods
------------------    local mod = output_name:match("([^:]+)")
------------------    if mod == "fakery" or mod == "enhanced" or mod == "pooper" then return end
------------------
------------------    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
------------------    if found then
------------------        local fake_name = output_name .. "_fake"
------------------        
------------------        -- If the fake version isn't registered yet, create it
------------------        if not minetest.registered_items[fake_name] then
------------------            local original_def = minetest.registered_items[output_name]
------------------            if original_def then
------------------                local f_def = apply_visuals(original_def, nil, "Fake ")
------------------                -- Fake items might look real but have no tool capabilities or group functionality
------------------                f_def.tool_capabilities = nil 
------------------                minetest.register_craftitem(fake_name, f_def)
------------------            end
------------------        end
------------------
------------------        -- Register the fake version of the craft
------------------        local fake_craft = table.copy(recipe)
------------------        fake_craft.recipe = sub_recipe
------------------        output_stack:set_name(fake_name)
------------------        fake_craft.output = output_stack:to_string()
------------------        minetest.register_craft(fake_craft)
------------------    end
------------------end
------------------
-------------------- 4. BOOTSTRAP --
------------------
------------------function ia_toolmods.init()
------------------    -- Wrap register_craft to catch new recipes defined by other mods
------------------    local old_register_craft = minetest.register_craft
------------------    minetest.register_craft = function(recipe)
------------------        old_register_craft(recipe)
------------------        inject_fake_crafts(recipe)
------------------    end
------------------
------------------    -- Process existing tools
------------------    for name, def in pairs(minetest.registered_tools) do
------------------        local mod = name:match("([^:]+)")
------------------        if mod ~= "enhanced" and mod ~= "pooper" and mod ~= "fakery" then
------------------            ia_toolmods.register_enhanced_tool(name, def)
------------------            ia_toolmods.register_poopy_tool(name, def)
------------------        end
------------------    end
------------------end
------------------
-------------------- Run after all mods have loaded to ensure we catch everything
------------------minetest.register_on_mods_loaded(ia_toolmods.init)
------------------
------------------print("[IA Meta] Logic initialized with Unified Registry.")
------------------ ia_toolmods/init.lua
------------------ Handles creation of Enhanced, Poopy, and Fake item variants.
------------------ Logic combined and deduplicated.
----------------
----------------local modname = minetest.get_current_modname()
----------------local modpath = minetest.get_modpath(modname)
----------------local S       = minetest.get_translator(modname)
----------------
----------------ia_toolmods = {
----------------    variants = {
----------------        --enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced" },
----------------        --poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper"   },
----------------        --fake     = { prefix = nil,         color = nil,       suffix = "_fake"     }
----------------        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "enhanced" },
----------------        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "pooper"   },
----------------        fake     = { prefix = nil,         color = nil,       suffix = "fake"     }
----------------    },
----------------    substitutions = {
----------------        ["default:diamond"]      = "fakery:diamond",
----------------        ["default:mese_crystal"] = "fakery:mese",
----------------    }
----------------}
----------------
------------------ 1. UTILITIES --
----------------
------------------ Helper: Generates a valid modname:itemname string for our variants.
------------------ Luanti requires all names to start with our mod's name.
----------------local function get_variant_names(name, variant_key)
----------------	minetest.log('ia_toolmods.get_variant_names(name='..name..', key='..variant_key..')')
----------------    local v = ia_toolmods.variants[variant_key]
----------------    -- Convert "default:pick_iron" to "ia_toolmods:default_pick_iron_enhanced"
----------------    local clean_name = name:gsub(":", "_")
----------------    --local new_name = name .. v.suffix
----------------    --local new_name = variant_key .. ':' .. clean_name .. v.suffix
----------------    --local new_name = ":" .. modname .. ":" .. clean_name .. v.suffix
----------------    --local new_name = modname .. ":v_" .. clean_name .. v.suffix
----------------    local new_name = ":" .. modname .. ":" .. v.suffix .. "_" .. clean_name
----------------    local alias = name .. v.suffix -- Keep the old style as an alias for compatibility
----------------    
----------------    return new_name, alias
----------------end
----------------
------------------ Helper: Applies visual changes and common group settings.
----------------local function apply_visuals(def, color, prefix)
----------------	minetest.log('ia_toolmods.apply_visuals(color='..color..', prefix='..prefix..')')
----------------    local new_def = table.copy(def)
----------------    if prefix and new_def.description then
----------------        new_def.description = prefix .. new_def.description
----------------    end
----------------    if color then
----------------        local overlay = "^[colorize:" .. color .. ":40"
----------------        if new_def.inventory_image then
----------------            new_def.inventory_image = new_def.inventory_image .. overlay
----------------        end
----------------        if new_def.wield_image then
----------------            new_def.wield_image = new_def.wield_image .. overlay
----------------        end
----------------    end
----------------    -- Prevent creative inventory clutter
----------------    new_def.groups = table.copy(new_def.groups or {})
----------------    new_def.groups.not_in_creative_inventory = 1
----------------    return new_def
----------------end
----------------
------------------ 2. ENHANCEMENT LOGIC --
----------------
----------------function ia_toolmods.register_enhanced_tool(name, def)
----------------	minetest.log('ia_toolmods.register_enhanced_tool(name='..name..')')
----------------    local v_name, alias = get_variant_names(name, "enhanced")
----------------    minetest.log('ia_toolmods.register_enhanced_tool() v_name: '..v_name)
----------------    minetest.log('ia_toolmods.register_enhanced_tool() alias : '..alias)
----------------    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
----------------    
----------------    -- Performance boost (20% faster digging)
----------------    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
----------------        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
----------------            if group.times then
----------------                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
----------------            end
----------------        end
----------------    end
----------------
----------------    minetest.register_tool(v_name, e_def)
----------------    minetest.register_alias(alias, v_name)
----------------    minetest.register_craft({
----------------        type = "shapeless",
----------------        output = v_name,
----------------        recipe = {name, "default:mese_crystal"},
----------------    })
----------------end
----------------
----------------function ia_toolmods.register_poopy_tool(name, def)
----------------	minetest.log('ia_toolmods.register_poopy_tool(name='..name..')')
----------------    local v_name, alias = get_variant_names(name, "poopy")
----------------    minetest.log('ia_toolmods.register_poopy_tool() v_name: '..v_name)
----------------    minetest.log('ia_toolmods.register_poopy_tool() alias : '..alias)
----------------    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
----------------
----------------    -- Effect: Feed target poop on use
----------------    p_def.on_use = function(itemstack, user, pointed_thing)
----------------        if pointed_thing and pointed_thing.type == "object" then
----------------            local target = pointed_thing.ref
----------------            if target and target:is_player() then
----------------                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
----------------                -- Tool cleans itself and reverts to normal
----------------                itemstack:set_name(name)
----------------                return itemstack
----------------            end
----------------        end
----------------        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
----------------    end
----------------
----------------    minetest.register_tool(v_name, p_def)
----------------    minetest.register_alias(alias, v_name)
----------------    minetest.register_craft({
----------------        type = "shapeless",
----------------        output = v_name,
----------------        recipe = {name, "pooper:poop_turd"},
----------------    })
----------------end
----------------
------------------ 3. FAKERY LOGIC --
----------------
------------------ Helper: Recursively swaps ingredients in recipes
----------------local function get_substituted_recipes(recipe_table)
----------------	minetest.log('ia_toolmods.get_substituted_recipes()')
----------------    local found_sub = false
----------------    local new_recipe = table.copy(recipe_table)
----------------
----------------    for i, item in ipairs(new_recipe) do
----------------        if type(item) == "table" then
----------------            local sub_item, sub_found = get_substituted_recipes(item)
----------------            new_recipe[i] = sub_item
----------------            if sub_found then found_sub = true end
----------------        elseif type(item) == "string" then
----------------            if ia_toolmods.substitutions[item] then
----------------                new_recipe[i] = ia_toolmods.substitutions[item]
----------------                found_sub = true
----------------            end
----------------        end
----------------    end
----------------    return new_recipe, found_sub
----------------end
----------------
----------------local function inject_fake_crafts(recipe) -- NOTE make sure that fake items can be used in craft recipes so we trick players into screwing up their end game items
----------------	minetest.log('ia_toolmods.inject_fake_crafts()')
----------------    if not recipe.output or recipe.type == "fuel" then return end
----------------    
----------------    local output_stack = ItemStack(recipe.output)
----------------    local output_name = output_stack:get_name()
----------------   
----------------    -- TODO create fake :ia_toolmods:enhanced_ tools
----------------    -- Safety: Don't process our own generated items
----------------    if output_name:match("^ia_toolmods:") then return end
----------------
----------------    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
----------------    if not found then
----------------        return
----------------    end
----------------    local v_name, alias = get_variant_names(output_name, "fake")
----------------    
----------------    -- Register the fake item if missing
----------------    if not minetest.registered_items[v_name] then
----------------        local original_def = minetest.registered_items[output_name]
----------------        if original_def then
----------------            local f_def = apply_visuals(original_def, nil, "Fake ")
----------------            f_def.tool_capabilities = nil -- Fakes don't work -- TODO or maybe they injure the user. might wanna parametrize this
----------------            minetest.register_craftitem(v_name, f_def)
----------------            minetest.register_alias(alias, v_name)
----------------        end
----------------    end
----------------
----------------    -- Register the "tainted" craft
----------------    local fake_craft = table.copy(recipe)
----------------    fake_craft.recipe = sub_recipe
----------------    output_stack:set_name(v_name)
----------------    fake_craft.output = output_stack:to_string()
----------------    minetest.register_craft(fake_craft)
----------------end
----------------
------------------ 4. BOOTSTRAP --
----------------
----------------function ia_toolmods.init()
----------------	minetest.log('ia_toolmods.init()')
----------------    -- Hook register_craft to catch downstream items
----------------    local old_register_craft = minetest.register_craft
----------------    minetest.register_craft = function(recipe)
----------------        old_register_craft(recipe)
----------------        inject_fake_crafts(recipe)
----------------    end
----------------
----------------    -- Initial pass over existing tools
----------------    for name, def in pairs(minetest.registered_tools) do
----------------        -- Ensure we don't wrap our own items or already wrapped items
----------------        if not name:match("^ia_toolmods:") then -- ':ia_toolmods' ?
----------------            ia_toolmods.register_enhanced_tool(name, def)
----------------            ia_toolmods.register_poopy_tool(name, def)
----------------        end
----------------    end
----------------end
----------------
------------------ Load after all mods to capture every tool and recipe
----------------minetest.register_on_mods_loaded(ia_toolmods.init)
----------------
----------------print("[IA Toolmods] Logic loaded and namespace corrected.")
---------------- ia_toolmods/init.lua
---------------- Handles creation of Enhanced, Poopy, and Fake item variants.
---------------- Logic combined and deduplicated.
--------------
--------------local modname = minetest.get_current_modname()
--------------local modpath = minetest.get_modpath(modname)
--------------local S       = minetest.get_translator(modname)
--------------
--------------ia_toolmods = {
--------------    variants = {
--------------        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced" },
--------------        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper"   },
--------------        fake     = { prefix = nil,         color = nil,       suffix = "_fake"     }
--------------    },
--------------    substitutions = {
--------------        ["default:diamond"]      = "fakery:diamond",
--------------        ["default:mese_crystal"] = "fakery:mese",
--------------    }
--------------}
--------------
---------------- 1. UTILITIES --
--------------
---------------- Helper: Generates a valid modname:itemname string for our variants.
--------------local function get_variant_names(name, variant_key)
--------------    local v = ia_toolmods.variants[variant_key]
--------------    -- Convert "default:pick_iron" to "default_pick_iron"
--------------    local clean_name = name:gsub(":", "_")
--------------    
--------------    -- CHANGE: Using ":" prefix for the technical name.
--------------    -- This is the Luanti "override" syntax. It bypasses the modname prefix check.
--------------    -- This is required because we are registering items inside on_mods_loaded, 
--------------    -- where the engine's internal 'current mod' context may be lost or restricted.
--------------    local new_name = ":" .. modname .. ":" .. clean_name .. v.suffix
--------------    
--------------    -- For the alias, we don't need the colon override.
--------------    local alias = name .. v.suffix
--------------    
--------------    return new_name, alias
--------------end
--------------
---------------- Helper: Applies visual changes and common group settings.
--------------local function apply_visuals(def, color, prefix)
--------------    local new_def = table.copy(def)
--------------    if prefix and new_def.description then
--------------        new_def.description = prefix .. new_def.description
--------------    end
--------------    if color then
--------------        local overlay = "^[colorize:" .. color .. ":40"
--------------        if new_def.inventory_image then
--------------            new_def.inventory_image = new_def.inventory_image .. overlay
--------------        end
--------------        if new_def.wield_image then
--------------            new_def.wield_image = new_def.wield_image .. overlay
--------------        end
--------------    end
--------------    -- Prevent creative inventory clutter
--------------    new_def.groups = table.copy(new_def.groups or {})
--------------    new_def.groups.not_in_creative_inventory = 1
--------------    return new_def
--------------end
--------------
---------------- 2. ENHANCEMENT LOGIC --
--------------
--------------function ia_toolmods.register_enhanced_tool(name, def)
--------------    local v_name, alias = get_variant_names(name, "enhanced")
--------------    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
--------------    
--------------    -- Performance boost (20% faster digging)
--------------    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
--------------        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
--------------            if group.times then
--------------                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
--------------            end
--------------        end
--------------    end
--------------
--------------    minetest.register_tool(v_name, e_def)
--------------    minetest.register_alias(alias, v_name)
--------------    minetest.register_craft({
--------------        type = "shapeless",
--------------        output = v_name,
--------------        recipe = {name, "default:mese_crystal"},
--------------    })
--------------end
--------------
--------------function ia_toolmods.register_poopy_tool(name, def)
--------------    local v_name, alias = get_variant_names(name, "poopy")
--------------    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
--------------
--------------    -- Effect: Feed target poop on use
--------------    p_def.on_use = function(itemstack, user, pointed_thing)
--------------        if pointed_thing and pointed_thing.type == "object" then
--------------            local target = pointed_thing.ref
--------------            if target and target:is_player() then
--------------                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
--------------                -- Tool cleans itself and reverts to normal
--------------                itemstack:set_name(name)
--------------                return itemstack
--------------            end
--------------        end
--------------        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
--------------    end
--------------
--------------    minetest.register_tool(v_name, p_def)
--------------    minetest.register_alias(alias, v_name)
--------------    minetest.register_craft({
--------------        type = "shapeless",
--------------        output = v_name,
--------------        recipe = {name, "pooper:poop_turd"},
--------------    })
--------------end
--------------
---------------- 3. FAKERY LOGIC --
--------------
---------------- Helper: Recursively swaps ingredients in recipes
--------------local function get_substituted_recipes(recipe_table)
--------------    local found_sub = false
--------------    local new_recipe = table.copy(recipe_table)
--------------
--------------    for i, item in ipairs(new_recipe) do
--------------        if type(item) == "table" then
--------------            local sub_item, sub_found = get_substituted_recipes(item)
--------------            new_recipe[i] = sub_item
--------------            if sub_found then found_sub = true end
--------------        elseif type(item) == "string" then
--------------            if ia_toolmods.substitutions[item] then
--------------                new_recipe[i] = ia_toolmods.substitutions[item]
--------------                found_sub = true
--------------            end
--------------        end
--------------    end
--------------    return new_recipe, found_sub
--------------end
--------------
--------------local function inject_fake_crafts(recipe)
--------------    if not recipe.output or recipe.type == "fuel" then return end
--------------    
--------------    local output_stack = ItemStack(recipe.output)
--------------    local output_name = output_stack:get_name()
--------------    
--------------    -- Safety: Don't process our own generated items (matching against modname)
--------------    if output_name:match("^" .. modname .. ":") then return end
--------------
--------------    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
--------------    if found then
--------------        local v_name, alias = get_variant_names(output_name, "fake")
--------------        
--------------        -- Register the fake item if missing
--------------        if not minetest.registered_items[v_name] then
--------------            local original_def = minetest.registered_items[output_name]
--------------            if original_def then
--------------                local f_def = apply_visuals(original_def, nil, "Fake ")
--------------                f_def.tool_capabilities = nil -- Fakes don't work
--------------                minetest.register_craftitem(v_name, f_def)
--------------                minetest.register_alias(alias, v_name)
--------------            end
--------------        end
--------------
--------------        -- Register the "tainted" craft
--------------        local fake_craft = table.copy(recipe)
--------------        fake_craft.recipe = sub_recipe
--------------        output_stack:set_name(v_name)
--------------        fake_craft.output = output_stack:to_string()
--------------        minetest.register_craft(fake_craft)
--------------    end
--------------end
--------------
---------------- 4. BOOTSTRAP --
--------------
--------------function ia_toolmods.init()
--------------    -- Hook register_craft to catch downstream items
--------------    local old_register_craft = minetest.register_craft
--------------    minetest.register_craft = function(recipe)
--------------        old_register_craft(recipe)
--------------        inject_fake_crafts(recipe)
--------------    end
--------------
--------------    -- Initial pass over existing tools
--------------    for name, def in pairs(minetest.registered_tools) do
--------------        -- Ensure we don't wrap our own items or already wrapped items
--------------        if not name:match("^" .. modname .. ":") and not name:match("^:") then
--------------            ia_toolmods.register_enhanced_tool(name, def)
--------------            ia_toolmods.register_poopy_tool(name, def)
--------------        end
--------------    end
--------------end
--------------
---------------- Load after all mods to capture every tool and recipe
--------------minetest.register_on_mods_loaded(ia_toolmods.init)
--------------
--------------print("[IA Toolmods] Logic loaded with colon-prefix overrides.")
-------------- ia_toolmods/init.lua
-------------- Handles creation of Enhanced, Poopy, and Fake item variants.
------------
------------local modname = minetest.get_current_modname() or "ia_toolmods"
------------
------------ia_toolmods = {
------------    variants = {
------------        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced" },
------------        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper"   },
------------        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake"     } -- FIXME prefix would be a dead give away ?
------------    },
------------    substitutions = {
------------        ["default:diamond"]      = "fakery:diamond",
------------        ["default:mese_crystal"] = "fakery:mese",
------------    }
------------}
------------
-------------- 1. UTILITIES --
------------
-------------- Helper: Generates a valid modname:itemname string for our variants.
------------local function get_variant_names(name, variant_key)
------------    local v = ia_toolmods.variants[variant_key]
------------    -- Convert "default:pick_iron" to "default_pick_iron"
------------    local clean_name = name:gsub(":", "_")
------------    
------------    -- Using the ":" prefix to bypass modname validation in on_mods_loaded.
------------    -- IMPORTANT: This technical name MUST be used consistently for crafts and aliases.
------------    local technical_name = ":" .. modname .. ":" .. clean_name .. v.suffix
------------    local alias_name = name .. v.suffix
------------    
------------    return technical_name, alias_name
------------end
------------
-------------- Helper: Applies visual changes and common group settings.
------------local function apply_visuals(def, color, prefix)
------------    local new_def = table.copy(def)
------------    if prefix and new_def.description then
------------        new_def.description = prefix .. new_def.description
------------    end
------------    if color then
------------        local overlay = "^[colorize:" .. color .. ":40"
------------        if new_def.inventory_image then
------------            new_def.inventory_image = new_def.inventory_image .. overlay
------------        end
------------        if new_def.wield_image then
------------            new_def.wield_image = new_def.wield_image .. overlay
------------        end
------------    end
------------    -- Prevent creative inventory clutter
------------    new_def.groups = table.copy(new_def.groups or {})
------------    new_def.groups.not_in_creative_inventory = 1
------------    return new_def
------------end
------------
-------------- 2. ENHANCEMENT LOGIC --
------------
------------function ia_toolmods.register_enhanced_tool(name, def)
------------    local v_name, alias = get_variant_names(name, "enhanced")
------------    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
------------    
------------    -- Performance boost (20% faster digging)
------------    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
------------        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
------------            if group.times then
------------                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
------------            end
------------        end
------------    end
------------
------------    minetest.log("action", "[ia_toolmods] Registering: " .. v_name)
------------    minetest.register_tool(v_name, e_def)
------------    minetest.register_alias(alias, v_name)
------------    
------------    minetest.register_craft({
------------        type = "shapeless",
------------        output = v_name, -- Must match technical name exactly
------------        recipe = {name, "default:mese_crystal"},
------------    })
------------end
------------
------------function ia_toolmods.register_poopy_tool(name, def)
------------    local v_name, alias = get_variant_names(name, "poopy")
------------    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
------------
------------    p_def.on_use = function(itemstack, user, pointed_thing)
------------        if pointed_thing and pointed_thing.type == "object" then
------------            local target = pointed_thing.ref
------------            if target and target:is_player() then
------------                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
------------                itemstack:set_name(name)
------------                return itemstack
------------            end
------------        end
------------        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
------------    end
------------
------------    minetest.log("action", "[ia_toolmods] Registering: " .. v_name)
------------    minetest.register_tool(v_name, p_def)
------------    minetest.register_alias(alias, v_name)
------------    
------------    minetest.register_craft({
------------        type = "shapeless",
------------        output = v_name, -- Must match technical name exactly
------------        recipe = {name, "pooper:poop_turd"},
------------    })
------------end
------------
-------------- 3. FAKERY LOGIC --
------------
------------local function get_substituted_recipes(recipe_table)
------------    local found_sub = false
------------    local new_recipe = table.copy(recipe_table)
------------    for i, item in ipairs(new_recipe) do
------------        if type(item) == "table" then
------------            local sub_item, sub_found = get_substituted_recipes(item)
------------            new_recipe[i] = sub_item
------------            if sub_found then found_sub = true end
------------        elseif type(item) == "string" then
------------            if ia_toolmods.substitutions[item] then
------------                new_recipe[i] = ia_toolmods.substitutions[item]
------------                found_sub = true
------------            end
------------        end
------------    end
------------    return new_recipe, found_sub
------------end
------------
------------local function inject_fake_crafts(recipe)
------------    if not recipe.output or recipe.type == "fuel" then return end
------------    
------------    local output_stack = ItemStack(recipe.output)
------------    local output_name = output_stack:get_name()
------------    
------------    if output_name:match("^" .. modname .. ":") or output_name:match("^:") then return end -- FIXME fake enhanced tools
------------
------------    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
------------    if found then
------------        local v_name, alias = get_variant_names(output_name, "fake")
------------        
------------        if not minetest.registered_items[v_name] then
------------            local original_def = minetest.registered_items[output_name]
------------            if original_def then
------------                local f_def = apply_visuals(original_def, nil, "Fake ")
------------                f_def.tool_capabilities = nil
------------                minetest.register_craftitem(v_name, f_def)
------------                minetest.register_alias(alias, v_name)
------------            end
------------        end
------------
------------        local fake_craft = table.copy(recipe)
------------        fake_craft.recipe = sub_recipe
------------        output_stack:set_name(v_name)
------------        fake_craft.output = output_stack:to_string()
------------        minetest.register_craft(fake_craft)
------------    end
------------end
------------
-------------- 4. BOOTSTRAP --
------------
------------function ia_toolmods.init()
------------    minetest.log("action", "[ia_toolmods] Starting late-initialization...")
------------    
------------    local old_register_craft = minetest.register_craft
------------    minetest.register_craft = function(recipe)
------------        old_register_craft(recipe)
------------        inject_fake_crafts(recipe)
------------    end
------------
------------    for name, def in pairs(minetest.registered_tools) do
------------        -- Skip our own mod items and items using the override prefix
------------        if not name:match("^" .. modname .. ":") and not name:match("^:") then
------------            ia_toolmods.register_enhanced_tool(name, def)
------------            ia_toolmods.register_poopy_tool(name, def)
------------        end
------------    end
------------    minetest.log("action", "[ia_toolmods] Initialization complete.")
------------end
------------
------------minetest.register_on_mods_loaded(ia_toolmods.init)
------------ ia_toolmods/init.lua
------------ Handles creation of Enhanced, Poopy, and Fake item variants.
----------
----------local modname = minetest.get_current_modname() or "ia_toolmods"
----------
----------ia_toolmods = {
----------    variants = {
----------        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced" },
----------        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper"   },
----------        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake"     } -- FIXME HOVER TEXT MUST NOT LEAK DATA
----------    },
----------    substitutions = {
----------        ["default:diamond"]      = "fakery:diamond",
----------        ["default:mese_crystal"] = "fakery:mese",
----------    }
----------}
----------
------------ 1. UTILITIES --
----------
------------ Helper: Generates a valid modname:itemname string for our variants.
----------local function get_variant_names(name, variant_key)
----------    local v = ia_toolmods.variants[variant_key]
----------    -- Convert "default:pick_iron" to "default_pick_iron"
----------    local clean_name = name:gsub(":", "_")
----------    
----------    -- Removed the ":" prefix to ensure items are correctly indexed by the engine and UI.
----------    -- Standard naming: "ia_toolmods:default_pick_iron_enhanced"
----------    local technical_name = modname .. ":" .. clean_name .. v.suffix
----------    local alias_name = name .. v.suffix
----------    
----------    return technical_name, alias_name
----------end
----------
------------ Helper: Applies visual changes and common group settings.
----------local function apply_visuals(def, color, prefix)
----------    local new_def = table.copy(def)
----------    if prefix and new_def.description then
----------        new_def.description = prefix .. new_def.description
----------    end
----------    if color then
----------        local overlay = "^[colorize:" .. color .. ":40"
----------        if new_def.inventory_image then
----------            new_def.inventory_image = new_def.inventory_image .. overlay
----------        end
----------        if new_def.wield_image then
----------            new_def.wield_image = new_def.wield_image .. overlay
----------        end
----------    end
----------    -- Prevent creative inventory clutter
----------    new_def.groups = table.copy(new_def.groups or {})
----------    new_def.groups.not_in_creative_inventory = 1
----------    return new_def
----------end
----------
------------ 2. ENHANCEMENT LOGIC --
----------
----------function ia_toolmods.register_enhanced_tool(name, def)
----------    local v_name, alias = get_variant_names(name, "enhanced")
----------    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
----------    
----------    -- Performance boost (20% faster digging)
----------    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
----------        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
----------            if group.times then
----------                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
----------            end
----------        end
----------    end
----------
----------    minetest.log("action", "[ia_toolmods] Registering Enhanced: " .. v_name)
----------    minetest.register_tool(v_name, e_def)
----------    minetest.register_alias(alias, v_name)
----------    
----------    minetest.register_craft({
----------        type = "shapeless",
----------        output = v_name,
----------        recipe = {name, "default:mese_crystal"},
----------    })
----------end
----------
----------function ia_toolmods.register_poopy_tool(name, def)
----------    local v_name, alias = get_variant_names(name, "poopy")
----------    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
----------
----------    p_def.on_use = function(itemstack, user, pointed_thing)
----------        if pointed_thing and pointed_thing.type == "object" then
----------            local target = pointed_thing.ref
----------            if target and target:is_player() then
----------                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
----------                itemstack:set_name(name)
----------                return itemstack
----------            end
----------        end
----------        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
----------    end
----------
----------    minetest.log("action", "[ia_toolmods] Registering Poopy: " .. v_name)
----------    minetest.register_tool(v_name, p_def)
----------    minetest.register_alias(alias, v_name)
----------    
----------    minetest.register_craft({
----------        type = "shapeless",
----------        output = v_name,
----------        recipe = {name, "pooper:poop_turd"},
----------    })
----------end
----------
------------ 3. FAKERY LOGIC --
----------
----------local function get_substituted_recipes(recipe_table)
----------    local found_sub = false
----------    local new_recipe = table.copy(recipe_table)
----------    for i, item in ipairs(new_recipe) do
----------        if type(item) == "table" then
----------            local sub_item, sub_found = get_substituted_recipes(item)
----------            new_recipe[i] = sub_item
----------            if sub_found then found_sub = true end
----------        elseif type(item) == "string" then
----------            if ia_toolmods.substitutions[item] then
----------                new_recipe[i] = ia_toolmods.substitutions[item]
----------                found_sub = true
----------            end
----------        end
----------    end
----------    return new_recipe, found_sub
----------end
----------
----------local function inject_fake_crafts(recipe)
----------    if not recipe.output or recipe.type == "fuel" then return end
----------    
----------    local output_stack = ItemStack(recipe.output)
----------    local output_name = output_stack:get_name()
----------    
----------    -- Filter out our own mod items
----------    if output_name:match("^" .. modname .. ":") then return end -- FIXME MUST SUPPORT FAKE ENHANCED TOOLS
----------
----------    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
----------    if found then
----------        local v_name, alias = get_variant_names(output_name, "fake")
----------        
----------        if not minetest.registered_items[v_name] then
----------            local original_def = minetest.registered_items[output_name]
----------            if original_def then
----------                local f_def = apply_visuals(original_def, nil, "Fake ")
----------                f_def.tool_capabilities = nil
----------                minetest.register_craftitem(v_name, f_def)
----------                minetest.register_alias(alias, v_name)
----------            end
----------        end
----------
----------        local fake_craft = table.copy(recipe)
----------        fake_craft.recipe = sub_recipe
----------        output_stack:set_name(v_name)
----------        fake_craft.output = output_stack:to_string()
----------        minetest.register_craft(fake_craft)
----------    end
----------end
----------
------------ 4. BOOTSTRAP --
----------
----------function ia_toolmods.init()
----------    minetest.log("action", "[ia_toolmods] Iterating registered tools for variants...")
----------    
----------    -- Hook register_craft to catch any crafts registered during or after this phase
----------    local old_register_craft = minetest.register_craft
----------    minetest.register_craft = function(recipe)
----------        old_register_craft(recipe)
----------        inject_fake_crafts(recipe)
----------    end
----------
----------    for name, def in pairs(minetest.registered_tools) do
----------        -- Ensure we only modify items from other mods
----------        if not name:match("^" .. modname .. ":") then
----------            ia_toolmods.register_enhanced_tool(name, def)
----------            ia_toolmods.register_poopy_tool(name, def)
----------        end
----------    end
----------    minetest.log("action", "[ia_toolmods] Initialization complete.")
----------end
----------
------------ We use register_on_mods_loaded to ensure all other mods have defined their tools
------------ but we must ensure the names match the modname correctly for visibility.
----------minetest.register_on_mods_loaded(ia_toolmods.init)
---------- ia_toolmods/init.lua
---------- Handles creation of Enhanced, Poopy, and Fake item variants.
---------- Logic combined and deduplicated from iaenhance, pooper, and iafakery.
--------
--------ia_toolmods = {
--------    variants = {
--------        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced", mod = "enhanced" },
--------        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper",   mod = "pooper"   },
--------        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake",     mod = "fakery"   }
--------    },
--------    substitutions = {
--------        ["default:diamond"]      = "fakery:diamond",
--------        ["default:mese_crystal"] = "fakery:mese",
--------    }
--------}
--------
---------- 1. UTILITIES --
--------
---------- Helper: Generates a valid modname:itemname string for our variants.
---------- Uses the legacy namespaces (enhanced:, pooper:, fakery:) to maintain compatibility.
--------local function get_variant_names(name, variant_key)
--------    local v = ia_toolmods.variants[variant_key]
--------    local m_name, i_name = name:match("([^:]+):([^:]+)")
--------    
--------    -- If we can't parse the name, fallback to a safe string
--------    if not m_name or not i_name then
--------        m_name = "unknown"
--------        i_name = name:gsub(":", "_")
--------    end
--------
--------    -- We use the ":" override prefix to register into the legacy namespaces
--------    -- even if this mod is named ia_toolmods.
--------    local technical_name = ":" .. v.mod .. ":" .. m_name .. "_" .. i_name
--------    local alias_name = name .. v.suffix
--------    
--------    return technical_name, alias_name
--------end
--------
---------- Helper: Applies visual changes and common group settings.
--------local function apply_visuals(def, color, prefix)
--------    local new_def = table.copy(def)
--------    if prefix and new_def.description then
--------        new_def.description = prefix .. new_def.description
--------    end
--------    if color then
--------        local overlay = "^[colorize:" .. color .. ":40"
--------        if new_def.inventory_image then
--------            new_def.inventory_image = new_def.inventory_image .. overlay
--------        end
--------        if new_def.wield_image then
--------            new_def.wield_image = new_def.wield_image .. overlay
--------        end
--------    end
--------    -- Prevent creative inventory clutter
--------    new_def.groups = table.copy(new_def.groups or {})
--------    new_def.groups.not_in_creative_inventory = 1
--------    return new_def
--------end
--------
---------- 2. ENHANCEMENT LOGIC --
--------
--------function ia_toolmods.register_enhanced_tool(name, def)
--------    local v_name, alias = get_variant_names(name, "enhanced")
--------    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
--------    
--------    -- Performance boost (20% faster digging)
--------    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
--------        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
--------            if group.times then
--------                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
--------            end
--------        end
--------    end
--------
--------    minetest.log("action", "[ia_toolmods] Registering Legacy Enhanced: " .. v_name)
--------    minetest.register_tool(v_name, e_def)
--------    minetest.register_alias(alias, v_name)
--------    
--------    minetest.register_craft({
--------        type = "shapeless",
--------        output = v_name,
--------        recipe = {name, "default:mese_crystal"},
--------    })
--------end
--------
--------function ia_toolmods.register_poopy_tool(name, def)
--------    local v_name, alias = get_variant_names(name, "poopy")
--------    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
--------
--------    p_def.on_use = function(itemstack, user, pointed_thing)
--------        if pointed_thing and pointed_thing.type == "object" then
--------            local target = pointed_thing.ref
--------            if target and target:is_player() then
--------                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
--------                itemstack:set_name(name)
--------                return itemstack
--------            end
--------        end
--------        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
--------    end
--------
--------    minetest.log("action", "[ia_toolmods] Registering Legacy Poopy: " .. v_name)
--------    minetest.register_tool(v_name, p_def)
--------    minetest.register_alias(alias, v_name)
--------    
--------    minetest.register_craft({
--------        type = "shapeless",
--------        output = v_name,
--------        recipe = {name, "pooper:poop_turd"},
--------    })
--------end
--------
---------- 3. FAKERY LOGIC --
--------
--------local function get_substituted_recipes(recipe_table)
--------    local found_sub = false
--------    local new_recipe = table.copy(recipe_table)
--------    for i, item in ipairs(new_recipe) do
--------        if type(item) == "table" then
--------            local sub_item, sub_found = get_substituted_recipes(item)
--------            new_recipe[i] = sub_item
--------            if sub_found then found_sub = true end
--------        elseif type(item) == "string" then
--------            if ia_toolmods.substitutions[item] then
--------                new_recipe[i] = ia_toolmods.substitutions[item]
--------                found_sub = true
--------            end
--------        end
--------    end
--------    return new_recipe, found_sub
--------end
--------
--------local function inject_fake_crafts(recipe)
--------    if not recipe.output or recipe.type == "fuel" then return end
--------    
--------    local output_stack = ItemStack(recipe.output)
--------    local output_name = output_stack:get_name()
--------    
--------    -- Filter out our own generated namespaces to prevent infinite recursion
--------    if output_name:match("^enhanced:") or 
--------       output_name:match("^pooper:") or 
--------       output_name:match("^fakery:") or
--------       output_name:match("^:") then 
--------        return 
--------    end
--------
--------    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
--------    if found then
--------        local v_name, alias = get_variant_names(output_name, "fake")
--------        
--------        if not minetest.registered_items[v_name] then
--------            local original_def = minetest.registered_items[output_name]
--------            if original_def then
--------                local f_def = apply_visuals(original_def, nil, "Fake ")
--------                f_def.tool_capabilities = nil
--------                minetest.register_craftitem(v_name, f_def)
--------                minetest.register_alias(alias, v_name)
--------            end
--------        end
--------
--------        local fake_craft = table.copy(recipe)
--------        fake_craft.recipe = sub_recipe
--------        output_stack:set_name(v_name)
--------        fake_craft.output = output_stack:to_string()
--------        minetest.register_craft(fake_craft)
--------    end
--------end
--------
---------- 4. BOOTSTRAP --
--------
--------function ia_toolmods.init()
--------    minetest.log("action", "[ia_toolmods] Processing legacy variants (enhanced, pooper, fakery)...")
--------    
--------    -- Hook register_craft
--------    local old_register_craft = minetest.register_craft
--------    minetest.register_craft = function(recipe)
--------        old_register_craft(recipe)
--------        inject_fake_crafts(recipe)
--------    end
--------
--------    for name, def in pairs(minetest.registered_tools) do
--------        -- Skip any item already belonging to our target legacy namespaces
--------        local mod_part = name:match("([^:]+):")
--------        if mod_part ~= "enhanced" and mod_part ~= "pooper" and mod_part ~= "fakery" then
--------            ia_toolmods.register_enhanced_tool(name, def)
--------            ia_toolmods.register_poopy_tool(name, def)
--------        end
--------    end
--------    minetest.log("action", "[ia_toolmods] Initialization complete.")
--------end
--------
--------minetest.register_on_mods_loaded(ia_toolmods.init)
-------- ia_toolmods/init.lua
-------- Handles creation of Enhanced, Poopy, and Fake item variants.
-------- Logic combined and deduplicated from iaenhance, pooper, and iafakery.
------
------local modname = minetest.get_current_modname() or "ia_toolmods"
------
------ia_toolmods = {
------    variants = {
------        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced", mod = "enhanced" },
------        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper",   mod = "pooper"   },
------        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake",     mod = "fakery"   }
------    },
------    substitutions = {
------        ["default:diamond"]      = "fakery:diamond",
------        ["default:mese_crystal"] = "fakery:mese",
------    }
------}
------
-------- 1. UTILITIES --
------
-------- Helper: Generates a valid modname:itemname string for our variants.
------local function get_variant_names(name, variant_key)
------    local v = ia_toolmods.variants[variant_key]
------    local m_name, i_name = name:match("([^:]+):([^:]+)")
------    
------    if not m_name or not i_name then
------        m_name = "unknown"
------        i_name = name:gsub(":", "_")
------    end
------
------    -- The technical name for registration (with colon override)
------    local technical_name = ":" .. v.mod .. ":" .. m_name .. "_" .. i_name
------    -- The internal name used by the engine after registration (without the leading colon)
------    local internal_name = v.mod .. ":" .. m_name .. "_" .. i_name
------    local alias_name = name .. v.suffix
------    
------    return technical_name, internal_name, alias_name
------end
------
-------- Helper: Applies visual changes and common group settings.
------local function apply_visuals(def, color, prefix)
------    local new_def = table.copy(def)
------    if prefix and new_def.description then
------        new_def.description = prefix .. new_def.description
------    end
------    if color then
------        local overlay = "^[colorize:" .. color .. ":40"
------        if new_def.inventory_image then
------            new_def.inventory_image = new_def.inventory_image .. overlay
------        end
------        if new_def.wield_image then
------            new_def.wield_image = new_def.wield_image .. overlay
------        end
------    end
------    -- Prevent creative inventory clutter
------    new_def.groups = table.copy(new_def.groups or {})
------    new_def.groups.not_in_creative_inventory = 1
------    return new_def
------end
------
-------- 2. ENHANCEMENT LOGIC --
------
------function ia_toolmods.register_enhanced_tool(name, def)
------    local v_name, i_name, alias = get_variant_names(name, "enhanced")
------    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
------    
------    -- Performance boost (20% faster digging)
------    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
------        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
------            if group.times then
------                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
------            end
------        end
------    end
------
------    minetest.log("action", "[ia_toolmods] Registering Legacy Enhanced: " .. i_name)
------    minetest.register_tool(v_name, e_def)
------    minetest.register_alias(alias, i_name)
------    
------    minetest.register_craft({
------        type = "shapeless",
------        output = i_name,
------        recipe = {name, "default:mese_crystal"},
------    })
------end
------
------function ia_toolmods.register_poopy_tool(name, def)
------    local v_name, i_name, alias = get_variant_names(name, "poopy")
------    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
------
------    p_def.on_use = function(itemstack, user, pointed_thing)
------        if pointed_thing and pointed_thing.type == "object" then
------            local target = pointed_thing.ref
------            if target and target:is_player() then
------                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
------                itemstack:set_name(name)
------                return itemstack
------            end
------        end
------        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
------    end
------
------    minetest.log("action", "[ia_toolmods] Registering Legacy Poopy: " .. i_name)
------    minetest.register_tool(v_name, p_def)
------    minetest.register_alias(alias, i_name)
------    
------    minetest.register_craft({
------        type = "shapeless",
------        output = i_name,
------        recipe = {name, "pooper:poop_turd"},
------    })
------end
------
-------- 3. FAKERY LOGIC --
------
------local function get_substituted_recipes(recipe_table)
------    local found_sub = false
------    local new_recipe = table.copy(recipe_table)
------    for i, item in ipairs(new_recipe) do
------        if type(item) == "table" then
------            local sub_item, sub_found = get_substituted_recipes(item)
------            new_recipe[i] = sub_item
------            if sub_found then found_sub = true end
------        elseif type(item) == "string" then
------            if ia_toolmods.substitutions[item] then
------                new_recipe[i] = ia_toolmods.substitutions[item]
------                found_sub = true
------            end
------        end
------    end
------    return new_recipe, found_sub
------end
------
------local function inject_fake_crafts(recipe)
------    if not recipe.output or recipe.type == "fuel" then return end
------    
------    local output_stack = ItemStack(recipe.output)
------    local output_name = output_stack:get_name()
------    
------    -- Filter out our own generated namespaces to prevent infinite recursion
------    if output_name:match("^enhanced:") or 
------       output_name:match("^pooper:") or 
------       output_name:match("^fakery:") or
------       output_name:match("^:") then 
------        return 
------    end
------
------    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
------    if found then
------        local v_name, i_name, alias = get_variant_names(output_name, "fake")
------        
------        if not minetest.registered_items[i_name] then
------            local original_def = minetest.registered_items[output_name]
------            if original_def then
------                local f_def = apply_visuals(original_def, nil, "Fake ")
------                f_def.tool_capabilities = nil
------                minetest.register_craftitem(v_name, f_def)
------                minetest.register_alias(alias, i_name)
------            end
------        end
------
------        local fake_craft = table.copy(recipe)
------        fake_craft.recipe = sub_recipe
------        output_stack:set_name(i_name)
------        fake_craft.output = output_stack:to_string()
------        minetest.register_craft(fake_craft)
------    end
------end
------
-------- 4. BOOTSTRAP --
------
------function ia_toolmods.init()
------    minetest.log("action", "[ia_toolmods] Processing legacy variants (enhanced, pooper, fakery)...")
------    
------    -- Hook register_craft
------    local old_register_craft = minetest.register_craft
------    minetest.register_craft = function(recipe)
------        old_register_craft(recipe)
------        inject_fake_crafts(recipe)
------    end
------
------    for name, def in pairs(minetest.registered_tools) do
------        local mod_part = name:match("([^:]+):")
------        if mod_part ~= "enhanced" and mod_part ~= "pooper" and mod_part ~= "fakery" then
------            ia_toolmods.register_enhanced_tool(name, def)
------            ia_toolmods.register_poopy_tool(name, def)
------        end
------    end
------    minetest.log("action", "[ia_toolmods] Initialization complete.")
------end
------
------minetest.register_on_mods_loaded(ia_toolmods.init)
------ ia_toolmods/init.lua
------ Handles creation of Enhanced, Poopy, and Fake item variants.
------ Logic combined and deduplicated from iaenhance, pooper, and iafakery.
----
----local modname = minetest.get_current_modname() or "ia_toolmods"
----
----ia_toolmods = {
----    variants = {
----        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced", mod = "enhanced" },
----        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper",   mod = "pooper"   },
----        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake",     mod = "fakery"   }
----    },
----    substitutions = {
----        ["default:diamond"]      = "fakery:diamond",
----        ["default:mese_crystal"] = "fakery:mese",
----    }
----}
----
------ 1. UTILITIES --
----
------ Helper: Generates name strings.
------ technical_name: used for minetest.register_* (with leading colon)
------ internal_name: the name the engine actually uses (mod:item)
----local function get_variant_names(name, variant_key)
----    local v = ia_toolmods.variants[variant_key]
----    local m_name, i_name = name:match("([^:]+):([^:]+)")
----    
----    if not m_name or not i_name then
----        m_name = "unknown"
----        i_name = name:gsub(":", "_")
----    end
----
----    local internal_name = v.mod .. ":" .. m_name .. "_" .. i_name
----    local technical_name = ":" .. internal_name
----    local alias_name = name .. v.suffix
----    
----    return technical_name, internal_name, alias_name
----end
----
------ Helper: Applies visual changes and common group settings.
----local function apply_visuals(def, color, prefix)
----    local new_def = table.copy(def)
----    if prefix and new_def.description then
----        new_def.description = prefix .. new_def.description
----    end
----    if color then
----        local overlay = "^[colorize:" .. color .. ":40"
----        if new_def.inventory_image then
----            new_def.inventory_image = new_def.inventory_image .. overlay
----        end
----        if new_def.wield_image then
----            new_def.wield_image = new_def.wield_image .. overlay
----        end
----    end
----    
----    -- Ensure the item is actually usable/visible
----    new_def.groups = table.copy(new_def.groups or {})
----    -- Note: We removed not_in_creative_inventory = 1 to verify they show up for testing
----    return new_def
----end
----
------ 2. ENHANCEMENT LOGIC --
----
----function ia_toolmods.register_enhanced_tool(name, def)
----    local v_name, i_name, alias = get_variant_names(name, "enhanced")
----    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
----    
----    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
----        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
----            if group.times then
----                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
----            end
----        end
----    end
----
----    minetest.register_tool(v_name, e_def)
----    minetest.register_alias(alias, i_name)
----    -- Add alias for the original name if this is a replacement (unlikely here but good for compat)
----    
----    minetest.register_craft({
----        type = "shapeless",
----        output = i_name,
----        recipe = {name, "default:mese_crystal"},
----    })
----end
----
----function ia_toolmods.register_poopy_tool(name, def)
----    local v_name, i_name, alias = get_variant_names(name, "poopy")
----    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
----
----    p_def.on_use = function(itemstack, user, pointed_thing)
----        if pointed_thing and pointed_thing.type == "object" then
----            local target = pointed_thing.ref
----            if target and target:is_player() then
----                -- Requirement: pooper:poop_turd must exist in your game
----                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
----                itemstack:set_name(name)
----                return itemstack
----            end
----        end
----        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
----    end
----
----    minetest.register_tool(v_name, p_def)
----    minetest.register_alias(alias, i_name)
----    
----    minetest.register_craft({
----        type = "shapeless",
----        output = i_name,
----        recipe = {name, "pooper:poop_turd"},
----    })
----end
----
------ 3. FAKERY LOGIC --
----
----local function get_substituted_recipes(recipe_table)
----    local found_sub = false
----    local new_recipe = table.copy(recipe_table)
----    for i, item in ipairs(new_recipe) do
----        if type(item) == "table" then
----            local sub_item, sub_found = get_substituted_recipes(item)
----            new_recipe[i] = sub_item
----            if sub_found then found_sub = true end
----        elseif type(item) == "string" then
----            if ia_toolmods.substitutions[item] then
----                new_recipe[i] = ia_toolmods.substitutions[item]
----                found_sub = true
----            end
----        end
----    end
----    return new_recipe, found_sub
----end
----
----local function inject_fake_crafts(recipe)
----    if not recipe.output or recipe.type == "fuel" then return end
----    
----    local output_stack = ItemStack(recipe.output)
----    local output_name = output_stack:get_name()
----    
----    -- Logic to prevent feedback loops
----    if output_name:match("^enhanced:") or 
----       output_name:match("^pooper:") or 
----       output_name:match("^fakery:") or
----       output_name:match("^:") then 
----        return 
----    end
----
----    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
----    if found then
----        local v_name, i_name, alias = get_variant_names(output_name, "fake")
----        
----        if not minetest.registered_items[i_name] then
----            local original_def = minetest.registered_items[output_name]
----            if original_def then
----                local f_def = apply_visuals(original_def, nil, "Fake ")
----                f_def.tool_capabilities = nil
----                minetest.register_craftitem(v_name, f_def)
----                minetest.register_alias(alias, i_name)
----            end
----        end
----
----        local fake_craft = table.copy(recipe)
----        fake_craft.recipe = sub_recipe
----        output_stack:set_name(i_name)
----        fake_craft.output = output_stack:to_string()
----        minetest.register_craft(fake_craft)
----    end
----end
----
------ 4. BOOTSTRAP --
----
----function ia_toolmods.init()
----    minetest.log("action", "[ia_toolmods] Iterating tools for legacy variants...")
----    
----    -- Hook register_craft
----    local old_register_craft = minetest.register_craft
----    minetest.register_craft = function(recipe)
----        old_register_craft(recipe)
----        inject_fake_crafts(recipe)
----    end
----
----    -- Process tools
----    for name, def in pairs(minetest.registered_tools) do
----        local mod_part = name:match("([^:]+):")
----        -- Filter: only process tools not already in our target namespaces
----        if mod_part ~= "enhanced" and mod_part ~= "pooper" and mod_part ~= "fakery" then
----            ia_toolmods.register_enhanced_tool(name, def)
----            ia_toolmods.register_poopy_tool(name, def)
----        end
----    end
----
----    -- Process existing crafts for Fakery
----    -- (Note: In Luanti, some crafts are stored in internal tables that aren't easily iterated 
----    -- outside of the registration phase, but register_craft hook handles new ones).
----    
----    minetest.log("action", "[ia_toolmods] Logic deployment finished.")
----end
----
----minetest.register_on_mods_loaded(ia_toolmods.init)
---- ia_toolmods/init.lua
---- Handles creation of Enhanced, Poopy, and Fake item variants.
---- Logic combined and deduplicated from iaenhance, pooper, and iafakery.
--
--local modname = minetest.get_current_modname() or "ia_toolmods"
--
--ia_toolmods = {
--    variants = {
--        enhanced = { prefix = "Enhanced ", color = "#FFFF00", suffix = "_enhanced", mod = "enhanced" },
--        poopy    = { prefix = "Poopy ",    color = "#964B00", suffix = "_pooper",   mod = "pooper"   },
--        fake     = { prefix = "Fake ",     color = nil,       suffix = "_fake",     mod = "fakery"   }
--    },
--    substitutions = {
--        ["default:diamond"]      = "fakery:diamond",
--        ["default:mese_crystal"] = "fakery:mese",
--    }
--}
--
---- 1. UTILITIES --
--
---- Helper: Generates name strings.
---- technical_name: used for minetest.register_* (with leading colon)
---- internal_name: the name the engine actually uses (mod:item)
--local function get_variant_names(name, variant_key)
--    local v = ia_toolmods.variants[variant_key]
--    -- Handle names with or without leading colons
--    local clean_name = name:match("^:(.+)") or name
--    local m_name, i_name = clean_name:match("([^:]+):([^:]+)")
--    
--    if not m_name or not i_name then
--        m_name = "unknown"
--        i_name = clean_name:gsub(":", "_")
--    end
--
--    local internal_name = v.mod .. ":" .. m_name .. "_" .. i_name
--    local technical_name = ":" .. internal_name
--    local alias_name = clean_name .. v.suffix
--    
--    return technical_name, internal_name, alias_name
--end
--
---- Helper: Applies visual changes and common group settings.
--local function apply_visuals(def, color, prefix)
--    local new_def = table.copy(def)
--    if prefix and new_def.description then
--        new_def.description = prefix .. new_def.description
--    end
--    if color then
--        local overlay = "^[colorize:" .. color .. ":40"
--        if new_def.inventory_image then
--            new_def.inventory_image = new_def.inventory_image .. overlay
--        end
--        if new_def.wield_image then
--            new_def.wield_image = new_def.wield_image .. overlay
--        end
--    end
--    
--    new_def.groups = table.copy(new_def.groups or {})
--    return new_def
--end
--
---- 2. ENHANCEMENT LOGIC --
--
--function ia_toolmods.register_enhanced_tool(name, def)
--    local v_name, i_name, alias = get_variant_names(name, "enhanced")
--    -- Prevent double registration
--    if minetest.registered_tools[i_name] then return end
--
--    local e_def = apply_visuals(def, ia_toolmods.variants.enhanced.color, "Enhanced ")
--    
--    if e_def.tool_capabilities and e_def.tool_capabilities.groupcaps then
--        for _, group in pairs(e_def.tool_capabilities.groupcaps) do
--            if group.times then
--                for i, t in pairs(group.times) do group.times[i] = t / 1.2 end
--            end
--        end
--    end
--
--    minetest.register_tool(v_name, e_def)
--    minetest.register_alias(alias, i_name)
--    
--    minetest.register_craft({
--        type = "shapeless",
--        output = i_name,
--        recipe = {name, "default:mese_crystal"},
--    })
--end
--
--function ia_toolmods.register_poopy_tool(name, def)
--    local v_name, i_name, alias = get_variant_names(name, "poopy")
--    -- Prevent double registration
--    if minetest.registered_tools[i_name] then return end
--
--    local p_def = apply_visuals(def, ia_toolmods.variants.poopy.color, "Poopy ")
--
--    p_def.on_use = function(itemstack, user, pointed_thing)
--        if pointed_thing and pointed_thing.type == "object" then
--            local target = pointed_thing.ref
--            if target and target:is_player() then
--                minetest.do_item_eat(0, "", ItemStack("pooper:poop_turd"), target, pointed_thing)
--                itemstack:set_name(name)
--                return itemstack
--            end
--        end
--        return def.on_use and def.on_use(itemstack, user, pointed_thing) or itemstack
--    end
--
--    minetest.register_tool(v_name, p_def)
--    minetest.register_alias(alias, i_name)
--    
--    minetest.register_craft({
--        type = "shapeless",
--        output = i_name,
--        recipe = {name, "pooper:poop_turd"},
--    })
--end
--
---- 3. FAKERY LOGIC --
--
--local function get_substituted_recipes(recipe_table)
--    local found_sub = false
--    local new_recipe = table.copy(recipe_table)
--    for i, item in ipairs(new_recipe) do
--        if type(item) == "table" then
--            local sub_item, sub_found = get_substituted_recipes(item)
--            new_recipe[i] = sub_item
--            if sub_found then found_sub = true end
--        elseif type(item) == "string" then
--            -- Check for substitutions
--            for orig, sub in pairs(ia_toolmods.substitutions) do
--                if item == orig then
--                    new_recipe[i] = sub
--                    found_sub = true
--                end
--            end
--        end
--    end
--    return new_recipe, found_sub
--end
--
--local function inject_fake_crafts(recipe)
--    if not recipe.output or recipe.type == "fuel" then return end
--    
--    local output_stack = ItemStack(recipe.output)
--    local output_name = output_stack:get_name()
--    
--    -- Avoid recursion on fake items themselves
--    if output_name:match("^fakery:") then return end
--
--    local sub_recipe, found = get_substituted_recipes(recipe.recipe)
--    if found then
--        local v_name, i_name, alias = get_variant_names(output_name, "fake")
--        
--        -- Register the fake item if it doesn't exist
--        if not minetest.registered_items[i_name] then
--            local original_def = minetest.registered_items[output_name]
--            if original_def then
--                local f_def = apply_visuals(original_def, nil, "Fake ")
--                -- Fake tools can't dig
--                f_def.tool_capabilities = nil
--                minetest.register_craftitem(v_name, f_def)
--                minetest.register_alias(alias, i_name)
--            end
--        end
--
--        local fake_craft = table.copy(recipe)
--        fake_craft.recipe = sub_recipe
--        output_stack:set_name(i_name)
--        fake_craft.output = output_stack:to_string()
--        minetest.register_craft(fake_craft)
--    end
--end
--
---- 4. BOOTSTRAP --
--
--function ia_toolmods.init()
--    minetest.log("action", "[ia_toolmods] Iterating tools for legacy variants...")
--    
--    -- 1. Register Hook for any dynamic crafts
--    local old_register_craft = minetest.register_craft
--    minetest.register_craft = function(recipe)
--        old_register_craft(recipe)
--        inject_fake_crafts(recipe)
--    end
--
--    -- 2. Process Tools (Multiple passes to allow Enhanced Poopy tools)
--    -- We take a snapshot of tools to avoid infinite loops during iteration
--    local function process_all_tools()
--        local current_tools = {}
--        for name, def in pairs(minetest.registered_tools) do
--            current_tools[name] = def
--        end
--
--        for name, def in pairs(current_tools) do
--            local mod_part = name:match("([^:]+):")
--            -- Register Enhanced version if it's not already enhanced
--            if mod_part ~= "enhanced" then
--                ia_toolmods.register_enhanced_tool(name, def)
--            end
--            -- Register Poopy version if it's not already poopy
--            if mod_part ~= "pooper" then
--                ia_toolmods.register_poopy_tool(name, def)
--            end
--        end
--    end
--
--    -- Pass 1: Base tools -> Enhanced/Poopy
--    process_all_tools()
--    -- Pass 2: Enhanced/Poopy -> Poopy Enhanced / Enhanced Poopy
--    process_all_tools()
--
--    -- 3. Process existing crafts for Fakery
--    -- Since we can't easily iterate the internal craft database, we rely on 
--    -- the fact that most mods register items before register_on_mods_loaded.
--    -- To catch early crafts, we can't, but we can iterate registered items.
--    
--    minetest.log("action", "[ia_toolmods] Logic deployment finished.")
--end
--
--minetest.register_on_mods_loaded(ia_toolmods.init)
-- ia_toolmods/init.lua
-- Handles creation of Enhanced, Poopy, and Fake item variants.
-- Logic combined and deduplicated from iaenhance, pooper, and iafakery.
--
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

----local function inject_fake_crafts(recipe)
----    if not recipe.output or recipe.type == "fuel" then return end
----    
----    local output_stack = ItemStack(recipe.output)
----    local output_name = output_stack:get_name()
----    
----    -- Avoid recursion on fake items themselves
----    if output_name:match("^fakery:") then return end
----
----    minetest.log('ia_toolmods.inject_fake_crafts() output     : '..recipe.output)
----    minetest.log('ia_toolmods.inject_fake_crafts() output_name: '..output_name)
----    minetest.log('ia_toolmods.inject_fake_crafts() type       : '..recipe.type)
----    minetest.log('ia_toolmods.inject_fake_crafts() method     : '..tostring(recipe.method)) -- can be nil
----    minetest.log('ia_toolmods.inject_fake_crafts() width      : '..tostring(recipe.width)) -- can be nil
----    --local recipe_data = recipe.recipe
----    local recipe_data = recipe.recipe or recipe.items
----    assert(output_name ~= "")
----    assert(recipe_data ~= nil)
----    assert(recipe.type == "normal" or recipe.type == "shapeless" or recipe.type == "cooking")
----    local sub_recipe, found = get_substituted_recipes(recipe_data)
----    if found then
----        local v_name, i_name, alias = get_variant_names(output_name, "fake")
----        
----        -- Register the fake item if it doesn't exist
----        if not minetest.registered_items[i_name] then
----            local original_def = minetest.registered_items[output_name]
----            if original_def then
----                local f_def = apply_visuals(original_def, nil, "Fake ")
----                -- Fake tools can't dig
----                f_def.tool_capabilities = nil
----                -- Register as craftitem (default) unless it's a node
----                if original_def.drawtype then
----                    minetest.register_node(v_name, f_def)
----                else
----                    minetest.register_craftitem(v_name, f_def)
----                end
----                minetest.register_alias(alias, i_name)
----            end
----        end
----
------        local fake_craft = table.copy(recipe)
------        fake_craft.recipe = sub_recipe
----        output_stack:set_name(i_name)
------        fake_craft.output = output_stack:to_string()
------	assert(fake_craft.type == "normal" or fake_craft.type == "shapeless" or fake_craft.type == "cooking")
------	if fake_craft.type == "normal" then -- FIXME
------            --fake_craft.type = "shaped"
------            fake_craft.type = nil
------	end
----        local fake_craft = {}
----	fake_craft    .recipe = sub_recipe
----	fake_craft    .output = output_stack:to_string()
----	if recipe.type ~= "normal" then
----            fake_craft.type   = recipe.type
----	end
----	for k,v in pairs(fake_craft.recipe) do
----	    minetest.log('k: '..k)
----	    minetest.log('v: '..v)
----	end
----	minetest.log('ia_toolmods.inject_fake_crafts() fake_craft.recipe: '..tostring(fake_craft.recipe))
----	minetest.log('ia_toolmods.inject_fake_crafts() fake_craft.output: '..tostring(fake_craft.output))
----	minetest.log('ia_toolmods.inject_fake_crafts() fake_craft.type  : '..tostring(fake_craft.type))
----        minetest.register_craft(fake_craft)
----    end
----end
--local function inject_fake_crafts(recipe)
--    -- Assertions to catch malformed inputs early
--    assert(recipe and type(recipe) == "table", "inject_fake_crafts: recipe must be a table")
--    if not recipe.recipe or not recipe.output then return end
--    
--    local function substitute(item)
--        if type(item) == "table" then
--            local res = {}
--            for k, v in pairs(item) do res[k] = substitute(v) end
--            return res
--        elseif type(item) == "string" then
--            return ia_toolmods.substitutions[item] or item
--        end
--        return item
--    end
--
--    local sub_recipe = substitute(recipe.recipe)
--    
--    -- Only proceed if substitutions actually changed the recipe
--    if dump(sub_recipe) ~= dump(recipe.recipe) then
--        local output_stack = ItemStack(recipe.output)
--        local output_name = output_stack:get_name()
--        
--        -- Prevent faking items that are already part of the fakery mod
--        -- Added check for the "fakery" mod prefix to prevent recursive naming
--        local current_mod = output_name:match("([^:]+)")
--        if current_mod == "fakery" then return end
--
--        -- FIX: Handle existing prefixes correctly to avoid "fakery:mod:item" (double colon)
--        -- We use get_variant_names which is designed to handle mod/item separation safely.
--        local v_name_raw, alias = get_variant_names(output_name, "fake")
--        
--        -- Use the ":" prefix to bypass the "modname prefix required" validation error
--        -- ensuring the engine treats this as a global registration for the specific mod prefix.
--        local v_name = ":" .. v_name_raw
--        
--        -- If the fake item doesn't exist yet, register it
--        if not minetest.registered_items[v_name] then
--            local original_def = minetest.registered_items[output_name]
--            if original_def then
--                local f_def = apply_visuals(original_def, nil, "Fake ")
--                f_def.tool_capabilities = nil -- Fakes have no stats
--                minetest.register_craftitem(v_name, f_def)
--                minetest.register_alias(alias, v_name)
--            else
--                -- Log skip if the base item definition is missing
--                return 
--            end
--        end
--
--        -- Register the new fake craft
--        local fake_craft = {
--            output = v_name .. " " .. output_stack:get_count(),
--            recipe = sub_recipe,
--            -- Ensure we preserve the original craft type (e.g., "shapeless")
--            type = recipe.type or (recipe.width and recipe.width > 0 and "normal" or nil),
--            width = recipe.width
--        }
--        
--        minetest.register_craft(fake_craft)
--    end
--end
-- 3. FAKE RECIPE INJECTION --

local function inject_fake_crafts(recipe)
    -- Assertions to ensure valid input state
    assert(recipe ~= nil, "inject_fake_crafts: recipe is nil")
    assert(type(recipe) == "table", "inject_fake_crafts: recipe must be a table")

    if not recipe.output or not recipe.recipe then return end

    local changed = false
    
    -- Recursive helper to handle nested tables in shaped recipes
    -- and perform substitutions for diamonds/mese.
    local function substitute_recursive(r)
        if type(r) == "string" then
            -- Check for exact match or group match
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
    local sub_recipe = substitute_recursive(recipe.recipe)
    
    -- If substitutions were made, register the fake variant
    if changed then
        local output_stack = ItemStack(recipe.output)
        local output_name = output_stack:get_name()
        
        -- Prevent infinite recursion by ignoring items already in the fakery mod
        if output_name:match("^fakery:") then return end

        local v_name, alias = get_variant_names(output_name, "fake")
        if not v_name then return end

        -- Register the fake item definition if it doesn't exist yet
        if not minetest.registered_items[v_name] then
            local original_def = minetest.registered_items[output_name]
            if original_def then
                local f_def = apply_visuals(original_def, nil, "Fake ")
                f_def.tool_capabilities = nil -- Fakes have no functionality
                minetest.register_craftitem(v_name, f_def)
                minetest.register_alias(alias, v_name)
            end
        end

        -- Create and register the new craft with substituted materials
        local fake_craft = table.copy(recipe)
        fake_craft.recipe = sub_recipe
        output_stack:set_name(v_name)
        fake_craft.output = output_stack:to_string()
        
        -- Ensure the output name is valid before registration
        assert(v_name ~= "", "inject_fake_crafts: generated variant name is empty")
        minetest.register_craft(fake_craft)
    end
end

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
            else
                minetest.log('ia_toolmods.init() no recipes for '..name)
            end
        end
    end
    
    minetest.log("action", "[ia_toolmods] Logic deployment finished.")
end

minetest.register_on_mods_loaded(ia_toolmods.init)
