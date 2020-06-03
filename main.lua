local HiveMod = RegisterMod("Hive Mod", 1)

-- Enumerations.
local id = { item = 1, trinket = 2, animation = 3 }
local flies = { normal = 0, war = 1, pestilence = 2, famine = 3, death = 4, conquest = 5, random = 6 }
local vars = { "war", "pestilence", "famine", "death", "conquest", "random" }

-- Chance for trinkets to modify flies = 1/TRINKET_CHANCE * 100
local TRINKET_CHANCE = 10

-- Chance for a conquest fly to spawn another fly when it hits an enemy = 1/CONQUEST_CHANCE * 100
local CONQUEST_CHANCE = 4

-- Minimum and maximum amount of flies to spawn when you pick up a HiveMod item.
local PICKUP_SPAWN_MIN = 3
local PICKUP_SPAWN_MAX = 8

-- Placeholder for random flies.
local HIVEMOD_RANDOM = -1

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
	if entity.SubType == flies.normal then
		local player = Isaac.GetPlayer(0)

		-- Check if Isaac has the random flies trinket and give it priority over everything else.
		if player:HasTrinket(HiveMod_Items[flies.random][id.trinket]) then
			if math.random(TRINKET_CHANCE) == 1 then
				-- Randomize the blue fly's variant.
				HiveMod:SetFlyType(entity, HiveMod:GetRandomFlyType())

				-- Stop the function so we don't mix up the flies.
				return
			end
		end

		-- Check if Isaac has any of the HiveMod trinkets.
		for index,value in ipairs(HiveMod_Items) do
			if player:HasTrinket(HiveMod_Items[index][id.trinket]) then
				-- The trinkets have a 10% chance of modifying a fly.
				if math.random(TRINKET_CHANCE) == 1 then
					-- Change the fly's type and end the function here.
					HiveMod:SetFlyType(entity, index)

					-- If Isaac has any of the trinkets and its effect was activated, we don't want any of the HiveMod items to overwrite this.
					return
				end
			end
		end

		-- Check if Isaac has the random flies item and give it priority over the other ones.
		if player:HasCollectible(HiveMod_Items[flies.random][id.item]) then
			-- Randomize the blue fly's variant.
			HiveMod:SetFlyType(entity, HiveMod:GetRandomFlyType())

			-- Stop the function so we don't mix up the flies.
			return
		end

		-- Check if Isaac has any of the HiveMod items.
		for index,value in ipairs(HiveMod_Items) do
			if player:HasCollectible(HiveMod_Items[index][id.item]) then
				-- Change the fly's type if a match is found.
				HiveMod:SetFlyType(entity, index)

				-- Stop the function so we don't mix up the flies.
				return
			end
		end
	end
end

-- Called when a blue fly does damage to an entity.
function HiveMod:OnBlueFlyDoDamage(victim, amount, flags, attacker, frames)
	-- Check if the attacker is a conquest fly.
	if attacker.Variant == FamiliarVariant.BLUE_FLY and attacker.Entity.SubType == flies.conquest then
		local player = Isaac.GetPlayer(0)

		-- Check if the player has the conquest item or trinket or any of the random ones.
		-- Although this doesn't guarantee that other white locusts won't be affected, it's the best I came up with since GetData() doesn't work here.
		if player:HasCollectible(HiveMod_Items[flies.conquest][id.item]) or player:HasCollectible(HiveMod_Items[flies.conquest][id.trinket])
		or player:HasCollectible(HiveMod_Items[flies.random][id.item]) or player:HasCollectible(HiveMod_Items[flies.random][id.trinket]) then
			-- Conquest flies have a 20% chance to spawn another conquest fly when they hit an enemy.
			if math.random(CONQUEST_CHANCE) == 1 then
				HiveMod:SpawnBlueFly(player, flies.conquest)
			end
		end
	end
end

-- Called when stats are evaluated.
function HiveMod:OnEvaluateCache(player, flags)
	-- We use this to make sure we don't spawn flies more than once.
	local data = player:GetData()

	-- Check if Isaac picked up the random flies item.
	if player:HasCollectible(HiveMod_Items[flies.random][id.item]) then
		if data[vars[flies.random]] == true then
			return
		end

		data[vars[flies.random]] = true

		-- Randomize all flies in the room.
		if HiveMod:SetFliesInRoom(HIVEMOD_RANDOM) == 0 then
			-- If no flies were randomized, spawn a bunch of randomized flies.
			for i = 1, math.random(PICKUP_SPAWN_MIN, PICKUP_SPAWN_MAX), 1 do
				HiveMod:SpawnBlueFly(player, HiveMod:GetRandomFlyType())
			end
		end

		-- Stop the function so no flies are mixed up.
		return
	else
		data[vars[flies.random]] = false
	end

	-- Check if Isaac picked up a HiveMod item.
	for index,value in ipairs(HiveMod_Items) do
		if player:HasCollectible(HiveMod_Items[index][id.item]) then
			if data[vars[index]] == true then
				return
			end

			data[vars[index]] = true

			-- Change the variant of all flies in the room.
			if HiveMod:SetFliesInRoom(index) == 0 then
				-- If no flies were modified, spawn a bunch of modified flies.
				for i = 1, math.random(PICKUP_SPAWN_MIN, PICKUP_SPAWN_MAX), 1 do
					HiveMod:SpawnBlueFly(player, index)
				end
			end

			-- Stop the function so no flies are mixed up.
			return
		else
			data[vars[index]] = false
		end
	end
end

-- Spawns a blue fly with the given variant at the player's position.
-- Also removes the dust cloud when spawned because blue flies usually don't appear with one.
function HiveMod:SpawnBlueFly(player, index)
	Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY, index, player.Position, Vector(0.0, 0.0), player):ClearEntityFlags(EntityFlag.FLAG_APPEAR)
end

-- Set's the blue fly's variant.
function HiveMod:SetFlyType(entity, index)
	entity.SubType = index
	entity:GetSprite():Play(HiveMod_Items[index][id.animation])
end

-- Changes the variant of all blue flies in the room.
function HiveMod:SetFliesInRoom(index)
	local counter = 0

	for _,entity in pairs(Isaac.GetRoomEntities()) do
		if entity.Variant == FamiliarVariant.BLUE_FLY and entity.SubType == flies.normal then
			counter = counter + 1

			if index == HIVEMOD_RANDOM then
				HiveMod:SetFlyType(entity, HiveMod:GetRandomFlyType())
			else
				HiveMod:SetFlyType(entity, index)
			end
		end
	end

	return counter
end

-- Returns a random blue fly variant.
function HiveMod:GetRandomFlyType()
	return math.random(flies.war, flies.conquest)
end

HiveMod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, HiveMod.OnBlueFlySpawn, FamiliarVariant.BLUE_FLY)
HiveMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, HiveMod.OnBlueFlyDoDamage, ENTITY_FAMILIAR)
HiveMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, HiveMod.OnEvaluateCache, CACHE_FAMILIARS)
