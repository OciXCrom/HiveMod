local HiveMod = RegisterMod("Hive Mod", 1)

-- Settings; feel free to adjust these to your needs.
local Settings =
{
	-- % chance for trinkets to modify flies.
	TRINKET_CHANCE = 10,

	-- % chance for a conquest fly to spawn another fly when it hits an enemy.
	CONQUEST_CHANCE = 33,

	-- Minimum and maximum amount of flies to spawn when you pick up a HiveMod item.
	PICKUP_SPAWN_MIN = 3,
	PICKUP_SPAWN_MAX = 8,
}

-- Enumerations.
local id = { item = 1, trinket = 2, animation = 3 }
local LocustType = { NORMAL = 0, WAR = 1, PESTILENCE = 2, FAMINE = 3, DEATH = 4, CONQUEST = 5, RANDOM = 6 }

-- Store the player's HiveMod items.
local PLAYER_ITEMS = {}

-- List of items, trinkets and animation names.
local HiveMod_Items =
{
	-- <item id>                                   <trinket id>                                      <animation>
	{ Isaac.GetItemIdByName("Short-Tempered Fly"), Isaac.GetTrinketIdByName("Flower of War"),        "LocustWrath" },
	{ Isaac.GetItemIdByName("Poison Hive"),        Isaac.GetTrinketIdByName("Flower of Pestilence"), "LocustPestilence" },
	{ Isaac.GetItemIdByName("Sedated Fly"),        Isaac.GetTrinketIdByName("Flower of Famine"),     "LocustFamine" },
	{ Isaac.GetItemIdByName("Deathbringer"),       Isaac.GetTrinketIdByName("Flower of Death"),      "LocustDeath" },
	{ Isaac.GetItemIdByName("Fly of Conquest"),    Isaac.GetTrinketIdByName("Flower of Conquest"),   "LocustConquest" },
	{ Isaac.GetItemIdByName("Vibrant Fly"),        Isaac.GetTrinketIdByName("Vibrant Flower"),       "", }
}

-- Called when a blue fly spawns.
function HiveMod:OnBlueFlySpawn(entity)
	-- Check if the fly is a regular blue fly.
	if entity.SubType == LocustType.NORMAL then
		local player = Isaac.GetPlayer(0)

		-- Check if Isaac has any of the HiveMod trinkets.
		for index, value in pairs(HiveMod_Items) do
			if player:HasTrinket(HiveMod_Items[index][id.trinket]) then
				-- The trinkets have a 10% chance of modifying a fly.
				if GetChance(Settings.TRINKET_CHANCE) then
					-- Change the fly's type and end the function here.
					HiveMod:SetFlyType(entity, index)

					-- If Isaac has any of the trinkets and its effect was activated, we don't want any of the HiveMod items to overwrite this.
					return
				end
			end
		end

		-- Check if the player has a HiveMod item.
		if #PLAYER_ITEMS > 0 then
			-- Change the fly's variant.
			-- If more than one item is acquired, the game will randomly choose which one to spawn.
			HiveMod:SetFlyType(entity, PLAYER_ITEMS[math.random(1, #PLAYER_ITEMS)])
		end
	end
end

-- Called when a blue fly does damage to an entity.
function HiveMod:OnBlueFlyDoDamage(victim, amount, flags, attacker, frames)
	-- Check if the attacker is a conquest fly.
	if attacker.Variant == FamiliarVariant.BLUE_FLY and attacker.Entity.SubType == LocustType.CONQUEST then
		local player = Isaac.GetPlayer(0)

		-- Check if the player has the conquest item or trinket or any of the random ones.
		-- Although this doesn't guarantee that other white locusts won't be affected, it's the best I came up with since GetData() doesn't work here.
		if HiveMod:HasFlyItem(LocustType.CONQUEST) or HiveMod:HasFlyItem(LocustType.RANDOM)
		or player:HasCollectible(HiveMod_Items[LocustType.CONQUEST][id.item]) or player:HasCollectible(HiveMod_Items[LocustType.RANDOM][id.trinket]) then
			-- Conquest flies have a chance to spawn another conquest fly when they hit an enemy.
			if GetChance(Settings.CONQUEST_CHANCE) then
				HiveMod:SpawnBlueFly(player, LocustType.CONQUEST)
			end
		end
	end
end

-- Called when stats are evaluated.
function HiveMod:OnEvaluateCache(player, flags)
	-- Loop through each HiveMod item.
	for index, value in pairs(HiveMod_Items) do
		-- Check if the player has the item.
		if player:HasCollectible(HiveMod_Items[index][id.item]) then
			-- If he previously didn't have it, add it to the list of items and spawn some flies.
			if HiveMod:HasFlyItem(index) == 0 then
				table.insert(PLAYER_ITEMS, index)
				HiveMod:OnPickupFlyItem(player, index)
			end
		else
			-- If he doesn't have it but previously did, remove that item from the list of items.
			local position = HiveMod:HasFlyItem(index)

			if position > 0 then
				table.remove(PLAYER_ITEMS, position)
			end
		end
	end
end

-- Called when a HiveMod item is picked up.
function HiveMod:OnPickupFlyItem(player, index)
	-- Set all normal blue flies in the room to the specified fly variant.
	-- If no flies were changed, spawn a random amount of modified flies.
	if HiveMod:SetFliesInRoom(index) == 0 then
		for i = 1, math.random(Settings.PICKUP_SPAWN_MIN, Settings.PICKUP_SPAWN_MAX) do
			HiveMod:SpawnBlueFly(player, index)
		end
	end
end

-- Spawns a blue fly with the given variant at the player's position.
-- Also removes the dust cloud when spawned because blue flies usually don't appear with one.
function HiveMod:SpawnBlueFly(player, index)
	Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY, index == LocustType.RANDOM and HiveMod:GetRandomFlyType() or index, player.Position, Vector(0.0, 0.0), player):ClearEntityFlags(EntityFlag.FLAG_APPEAR)
end

-- Set's the blue fly's variant.
function HiveMod:SetFlyType(entity, index)
	indexToSet = index == LocustType.RANDOM and HiveMod:GetRandomFlyType() or index
	entity.SubType = indexToSet
	entity:GetSprite():Play(HiveMod_Items[indexToSet][id.animation])
end

-- Changes the variant of all blue flies in the room.
function HiveMod:SetFliesInRoom(index)
	local counter = 0

	for _,entity in pairs(Isaac.GetRoomEntities()) do
		if entity.Variant == FamiliarVariant.BLUE_FLY and entity.SubType == LocustType.NORMAL then
			counter = counter + 1
			HiveMod:SetFlyType(entity, index == LocustType.RANDOM and HiveMod:GetRandomFlyType() or index)
		end
	end

	-- Return the number of flies that were changed.
	return counter
end

-- Returns a random blue fly variant.
function HiveMod:GetRandomFlyType()
	return math.random(LocustType.WAR, LocustType.CONQUEST)
end

-- Checks if the player has a HiveMod item.
-- Returns the position of the item in the custom items list.
function HiveMod:HasFlyItem(index)
	for i = 1, #PLAYER_ITEMS do
		if PLAYER_ITEMS[i] == index then
			return i
		end
	end

	return 0
end

-- Tries to proc a random % chance.
function GetChance(chance)
	return math.random(1, 100) <= chance and true or false
end

-- Register callbacks.
HiveMod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, HiveMod.OnBlueFlySpawn, FamiliarVariant.BLUE_FLY)
HiveMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, HiveMod.OnBlueFlyDoDamage, ENTITY_FAMILIAR)
HiveMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, HiveMod.OnEvaluateCache, CACHE_FAMILIARS)
