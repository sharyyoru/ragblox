--[[
	WeaponRegistry Module
	Centralized configuration for all weapons
	Define damage, skills, animations, and multipliers here
	Place in ReplicatedStorage.Modules
	
	Weapon style (1h/2h) is determined by folder structure:
	ReplicatedStorage.Weapons.1h or ReplicatedStorage.Weapons.2h
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponRegistry = {}

--[[
	WEAPON CONFIGURATION STRUCTURE:
	
	WeaponName = {
		WeaponStyle = "1h" or "2h",   -- Determines animation set
		BaseDamage = number,          -- Base damage for all attacks
		HitRange = number,            -- Attack range in studs
		AttackCooldown = number,      -- Seconds between attacks
		ComboResetTime = number,      -- Seconds before combo resets
		
		Skills = {
			SkillName = {
				Animation = "AnimationName",   -- Animation to play
				DamageMultiplier = number,     -- Multiplier applied to BaseDamage
				Cooldown = number,             -- Optional: skill-specific cooldown
				Range = number,                -- Optional: skill-specific range
				IsAoE = boolean,               -- Optional: hits multiple targets
				AoERadius = number,            -- Optional: AoE radius
				Knockback = number,            -- Optional: knockback force
			}
		},
		
		ComboSequence = {"Skill1", "Skill2", ...},  -- Order of combo attacks
	}
]]

-- Animation IDs by weapon style (global for all weapons of that style)
local STYLE_ANIMATIONS = {
	["1h"] = {
		Idle = "rbxassetid://85712461062430",
		M1 = "rbxassetid://100801018704943",
		M2 = "rbxassetid://70924391716335",
		M3 = "rbxassetid://95916017998734",
		M4 = "rbxassetid://71608173228517",
		Sprint = "rbxassetid://99797485122785",
	},
	["2h"] = {
		Idle = "rbxassetid://129967070737741",
		M1 = "rbxassetid://81923135757716",
		M2 = "rbxassetid://133519691446154",
		M3 = "rbxassetid://140283733644010",
		M4 = "rbxassetid://120912375980244",
		Sprint = "rbxassetid://99797485122785", -- Same sprint for all
	},
}

-- Hit timing (seconds from animation start) for each attack by weapon style
-- This determines when the swing sound plays and when damage is dealt
local STYLE_HIT_TIMING = {
	["1h"] = {
		M1 = 0.15,
		M2 = 0.18,
		M3 = 0.20,
		M4 = 0.25,
	},
	["2h"] = {
		M1 = 0.20,
		M2 = 0.25,
		M3 = 0.28,
		M4 = 0.35,
	},
}

-- Get hit timing for a specific attack
function WeaponRegistry.GetHitTiming(weaponStyle, attackName)
	local styleTiming = STYLE_HIT_TIMING[weaponStyle] or STYLE_HIT_TIMING["1h"]
	return styleTiming[attackName] or 0.2
end

-- Get animation IDs for a weapon style
function WeaponRegistry.GetStyleAnimations(weaponStyle)
	return STYLE_ANIMATIONS[weaponStyle] or STYLE_ANIMATIONS["1h"]
end

-- Default weapon template (fallback)
local DEFAULT_WEAPON = {
	WeaponStyle = "1h",
	BaseDamage = 10,
	HitRange = 6,
	AttackCooldown = 0.5,
	ComboResetTime = 1.5,
	
	Skills = {
		M1 = { Animation = "M1", DamageMultiplier = 1.0 },
		M2 = { Animation = "M2", DamageMultiplier = 1.2 },
		M3 = { Animation = "M3", DamageMultiplier = 1.5 },
		M4 = { Animation = "M4", DamageMultiplier = 2.0 },
	},
	
	ComboSequence = {"M1", "M2", "M3", "M4"},
}

-- Weapon Configurations
local Weapons = {
	--[[
		1-HANDED WEAPONS (1h folder)
		Use 1h animation set
	]]
	["Sword"] = {
		WeaponStyle = "1h",
		BaseDamage = 10,
		HitRange = 6,
		AttackCooldown = 0.5,
		ComboResetTime = 1.5,
		
		Skills = {
			M1 = { 
				Animation = "M1", 
				DamageMultiplier = 1.0,
			},
			M2 = { 
				Animation = "M2", 
				DamageMultiplier = 1.2,
			},
			M3 = { 
				Animation = "M3", 
				DamageMultiplier = 1.5,
			},
			M4 = { 
				Animation = "M4", 
				DamageMultiplier = 2.0,
				Knockback = 10,
			},
		},
		
		ComboSequence = {"M1", "M2", "M3", "M4"},
	},
	
	["Tomahawk"] = {
		WeaponStyle = "1h",
		BaseDamage = 12,
		HitRange = 5,
		AttackCooldown = 0.45,
		ComboResetTime = 1.3,
		
		Skills = {
			M1 = { 
				Animation = "M1", 
				DamageMultiplier = 1.0,
			},
			M2 = { 
				Animation = "M2", 
				DamageMultiplier = 1.3,
			},
			M3 = { 
				Animation = "M3", 
				DamageMultiplier = 1.6,
			},
			M4 = { 
				Animation = "M4", 
				DamageMultiplier = 2.2,
				Knockback = 12,
			},
		},
		
		ComboSequence = {"M1", "M2", "M3", "M4"},
	},
	
	--[[
		2-HANDED WEAPONS (2h folder)
		Use 2h animation set
	]]
	["Caliburn"] = {
		WeaponStyle = "2h",
		BaseDamage = 18,
		HitRange = 8,
		AttackCooldown = 0.7,
		ComboResetTime = 2.0,
		
		Skills = {
			M1 = { 
				Animation = "M1", 
				DamageMultiplier = 1.0,
			},
			M2 = { 
				Animation = "M2", 
				DamageMultiplier = 1.2,
			},
			M3 = { 
				Animation = "M3", 
				DamageMultiplier = 1.5,
			},
			M4 = { 
				Animation = "M4", 
				DamageMultiplier = 2.0,
				Knockback = 18,
			},
		},
		
		ComboSequence = {"M1", "M2", "M3", "M4"},
	},
}

-- Get weapon config by name
function WeaponRegistry.GetWeapon(weaponName)
	return Weapons[weaponName] or DEFAULT_WEAPON
end

-- Get weapon config by tool (reads WeaponId attribute or tool name)
function WeaponRegistry.GetWeaponFromTool(tool)
	local weaponId = tool:GetAttribute("WeaponId") or tool.Name
	return WeaponRegistry.GetWeapon(weaponId)
end

-- Detect weapon style from folder structure in ReplicatedStorage.Weapons
function WeaponRegistry.DetectWeaponStyle(weaponName)
	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	if not weaponsFolder then
		warn("[WeaponRegistry] Weapons folder not found in ReplicatedStorage")
		return "1h" -- Default to 1h
	end
	
	-- Check 1h folder
	local folder1h = weaponsFolder:FindFirstChild("1h")
	if folder1h and folder1h:FindFirstChild(weaponName) then
		return "1h"
	end
	
	-- Check 2h folder
	local folder2h = weaponsFolder:FindFirstChild("2h")
	if folder2h and folder2h:FindFirstChild(weaponName) then
		return "2h"
	end
	
	-- Fall back to config if not found in folders
	local weapon = Weapons[weaponName]
	if weapon and weapon.WeaponStyle then
		return weapon.WeaponStyle
	end
	
	return "1h" -- Default
end

-- Get weapon style for a weapon (from config or folder detection)
function WeaponRegistry.GetWeaponStyle(weaponName)
	local weapon = Weapons[weaponName]
	if weapon and weapon.WeaponStyle then
		return weapon.WeaponStyle
	end
	return WeaponRegistry.DetectWeaponStyle(weaponName)
end

-- Get skill config for a weapon
function WeaponRegistry.GetSkill(weaponName, skillName)
	local weapon = WeaponRegistry.GetWeapon(weaponName)
	return weapon.Skills[skillName]
end

-- Calculate damage for a skill
function WeaponRegistry.CalculateDamage(weaponName, skillName)
	local weapon = WeaponRegistry.GetWeapon(weaponName)
	local skill = weapon.Skills[skillName]
	
	if not skill then
		return weapon.BaseDamage
	end
	
	return math.floor(weapon.BaseDamage * (skill.DamageMultiplier or 1.0))
end

-- Get combo sequence for a weapon
function WeaponRegistry.GetComboSequence(weaponName)
	local weapon = WeaponRegistry.GetWeapon(weaponName)
	return weapon.ComboSequence
end

-- Get animation names for combo sequence
function WeaponRegistry.GetComboAnimations(weaponName)
	local weapon = WeaponRegistry.GetWeapon(weaponName)
	local animations = {}
	
	for _, skillName in ipairs(weapon.ComboSequence) do
		local skill = weapon.Skills[skillName]
		if skill then
			table.insert(animations, skill.Animation)
		end
	end
	
	return animations
end

-- Register a new weapon (for runtime additions)
function WeaponRegistry.RegisterWeapon(weaponName, config)
	Weapons[weaponName] = config
end

-- Get all registered weapon names
function WeaponRegistry.GetAllWeaponNames()
	local names = {}
	for name, _ in pairs(Weapons) do
		table.insert(names, name)
	end
	return names
end

-- Get default weapon config
function WeaponRegistry.GetDefault()
	return DEFAULT_WEAPON
end

return WeaponRegistry
