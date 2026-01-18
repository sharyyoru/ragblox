--[[
	MobConfig Module
	Centralized configuration for all mobs/NPCs
	Define stats, weapons, behavior, and spawn settings here
	Place in ReplicatedStorage.Modules
	
	Mob templates are stored in ReplicatedStorage.Mobs.[AreaName].[MobName]
	Spawn points are in Workspace.World1.[AreaName] (e.g., Spawn1, Spawn2, etc.)
]]

local MobConfig = {}

--[[
	MOB CONFIGURATION STRUCTURE:
	
	MobName = {
		-- Base Stats
		MaxHealth = number,
		WalkSpeed = number,
		RunSpeed = number,
		
		-- Combat
		WeaponName = string,        -- Weapon from ReplicatedStorage.Weapons
		BaseDamage = number,        -- Base damage (can override weapon)
		AttackRange = number,       -- Range to initiate attack
		AttackCooldown = number,    -- Seconds between attacks
		
		-- AI Behavior
		AggroRange = number,        -- Range to detect and chase players
		DeaggroRange = number,      -- Range to lose interest
		PatrolRadius = number,      -- Radius for patrol movement
		PatrolWaitTime = {min, max}, -- Random wait between patrols
		
		-- Respawn
		RespawnTime = number,       -- Seconds to respawn after death
		
		-- Rewards (optional)
		ExpReward = number,
		DropTable = {},
	}
]]

-- Default mob template (fallback)
local DEFAULT_MOB = {
	MaxHealth = 100,
	WalkSpeed = 8,
	RunSpeed = 16,
	
	WeaponName = "Sword",
	BaseDamage = 10,
	AttackRange = 5,
	AttackCooldown = 1.0,
	
	AggroRange = 20,
	DeaggroRange = 30,
	PatrolRadius = 10,
	PatrolWaitTime = {3, 6},
	
	RespawnTime = 30,
	
	ExpReward = 10,
	DropTable = {},
}

-- Mob Configurations by Area
local Mobs = {
	--[[
		AREA 1 MOBS
	]]
	["Area1"] = {
		["Brigand"] = {
			MaxHealth = 80,
			WalkSpeed = 8,
			RunSpeed = 14,
			
			WeaponName = "Sword",
			BaseDamage = 8,
			AttackRange = 5,
			AttackCooldown = 1.2,
			
			AggroRange = 15,
			DeaggroRange = 25,
			PatrolRadius = 8,
			PatrolWaitTime = {2, 5},
			
			RespawnTime = 20,
			
			ExpReward = 15,
			DropTable = {
				{ItemName = "Coin", Chance = 1.0, Amount = {1, 5}},
			},
		},
		
		["Bandit"] = {
			MaxHealth = 100,
			WalkSpeed = 10,
			RunSpeed = 16,
			
			WeaponName = "Tomahawk",
			BaseDamage = 12,
			AttackRange = 4,
			AttackCooldown = 0.9,
			
			AggroRange = 18,
			DeaggroRange = 28,
			PatrolRadius = 12,
			PatrolWaitTime = {3, 7},
			
			RespawnTime = 25,
			
			ExpReward = 20,
			DropTable = {
				{ItemName = "Coin", Chance = 1.0, Amount = {2, 8}},
			},
		},
		
		["Thug"] = {
			MaxHealth = 120,
			WalkSpeed = 7,
			RunSpeed = 12,
			
			WeaponName = "Caliburn",
			BaseDamage = 15,
			AttackRange = 6,
			AttackCooldown = 1.5,
			
			AggroRange = 12,
			DeaggroRange = 22,
			PatrolRadius = 6,
			PatrolWaitTime = {4, 8},
			
			RespawnTime = 35,
			
			ExpReward = 30,
			DropTable = {
				{ItemName = "Coin", Chance = 1.0, Amount = {5, 15}},
			},
		},
	},
	
	--[[
		AREA 2 MOBS (Template for future areas)
	]]
	["Area2"] = {
		-- Add mobs for Area2 here
	},
}

-- Get mob config by area and name
function MobConfig.GetMob(areaName, mobName)
	local area = Mobs[areaName]
	if area and area[mobName] then
		return area[mobName]
	end
	return DEFAULT_MOB
end

-- Get all mobs in an area
function MobConfig.GetAreaMobs(areaName)
	return Mobs[areaName] or {}
end

-- Get all area names
function MobConfig.GetAllAreas()
	local areas = {}
	for areaName, _ in pairs(Mobs) do
		table.insert(areas, areaName)
	end
	return areas
end

-- Get all mob names in an area
function MobConfig.GetMobNames(areaName)
	local names = {}
	local area = Mobs[areaName]
	if area then
		for mobName, _ in pairs(area) do
			table.insert(names, mobName)
		end
	end
	return names
end

-- Register a new mob (for runtime additions)
function MobConfig.RegisterMob(areaName, mobName, config)
	if not Mobs[areaName] then
		Mobs[areaName] = {}
	end
	Mobs[areaName][mobName] = config
end

-- Get default mob config
function MobConfig.GetDefault()
	return DEFAULT_MOB
end

-- Validate mob config (ensure all required fields exist)
function MobConfig.ValidateConfig(config)
	local validated = {}
	for key, value in pairs(DEFAULT_MOB) do
		validated[key] = config[key] or value
	end
	return validated
end

return MobConfig
