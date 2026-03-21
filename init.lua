-- ia_counterfeit/init.lua
-- FIXME fake lights shouldn't work (reliably) ... gotta check the light source property ?
-- FIXME fake nodes/items should (risk) explode or catch fire, especially if they have fake mese
-- FIXME fake nodes/items should not on_use properly; risk of just not working; risk of breaking; risk of injuring user; especially if they have fake diamond
-- FIXME fake nodes/items should (risk) injuring the user / nearby players/mobs
-- TODO any other properties or fields we wanna override with intentional "jankiness" ?
-- TODO use ia_crapht
-- TODO durability decay

assert(minetest.get_modpath('ia_util'))
assert(ia_util ~= nil)
local modname                    = minetest.get_current_modname() or "ia_counterfeit"
local storage                    = minetest.get_mod_storage()
ia_counterfeit                   = {
    substitutions   = {
        ["default:diamond"]      = "fakery:diamond",
        ["default:mese_crystal"] = "fakery:mese",
    },
    processed_items = {} 
}
ia_counterfeit.mod               = 'ia'
if minetest.registered_items['fakery:obsidian'] then
	ia_counterfeit.substitutions["default:obsidian_shard"] = "fakery:obsidian"
end
if minetest.registered_items['fakery:gold'] then
	ia_counterfeit.substitutions["default:gold_ingot"]     = "fakery:gold"
end
--if minetest.get_modpath("moreores") then -- TODO I need those specific item names
--	ia_counterfeit.substitutions[...] = "fakery:mithril"
--end
--if minetest.get_modpath("cloud_items") then
--	ia_counterfeit.substitutions[...] = "fakery:cloud"
--end
--if minetest.get_modpath("lavastuff") then
--	ia_counterfeit.substitutions[...] = "fakery:lava"
--end
--if minetest.get_modpath("overpowered") then
--	ia_counterfeit.substitutions[...] = "fakery:op"
--end
if minetest.get_modpath("technic_worldgen") then
	ia_counterfeit.substitutions['technic:uranium_lump']   = 'fakery:uranium'
end

local modpath, S                 = ia_util.loadmod(modname)
local log                        = ia_util.get_logger(modname)
local assert                     = ia_util.get_assert(modname)

minetest.register_on_mods_loaded(function()
    local all_items = {}
    for name, _ in pairs(minetest.registered_items) do
        table.insert(all_items, name)
    end

    for _, name in ipairs(all_items) do
        ia_counterfeit.ensure_fake_variant(name)
    end





















if minetest.get_modpath("technic") and minetest.get_modpath("mcg_lockworkshop") then
	mcg_lockworkshop.register_craft("technic:gold_chest",    "technic:gold_locked_chest")
	mcg_lockworkshop.register_craft("technic:iron_chest",    "technic:iron_locked_chest")
	mcg_lockworkshop.register_craft("technic:copper_chest",  "technic:copper_locked_chest")
	mcg_lockworkshop.register_craft("technic:silver_chest",  "technic:silver_locked_chest")
	mcg_lockworkshop.register_craft("technic:mithril_chest", "technic:mithril_locked_chest")

	mcg_lockworkshop.register_craft("fakery:technic_gold_chest",    "fakery:technic_gold_locked_chest")
	mcg_lockworkshop.register_craft("fakery:technic_iron_chest",    "fakery:technic_iron_locked_chest")
	mcg_lockworkshop.register_craft("fakery:technic_copper_chest",  "fakery:technic_copper_locked_chest")
	mcg_lockworkshop.register_craft("fakery:technic_silver_chest",  "fakery:technic_silver_locked_chest")
	mcg_lockworkshop.register_craft("fakery:technic_mithril_chest", "fakery:technic_mithril_locked_chest")
end






end)
