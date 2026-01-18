--[[
	SkillRegistry Module
	Centralized configuration for all skills
	Define animation, cooldown, VFX, and base properties here
	Place in ReplicatedStorage.Modules
	
	Skills are stored in ReplicatedStorage.Skills.[SkillName]
	This module defines the data/config for each skill
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillRegistry = {}

--[[
	SKILL CONFIGURATION STRUCTURE:
	
	SkillName = {
		DisplayName = "Skill Name",        -- Name shown in UI
		Animation = "rbxassetid://...",    -- Animation ID to play
		Cooldown = number,                 -- Cooldown in seconds
		Duration = number,                 -- How long the skill lasts (for damage timing)
		HitTime = number,                  -- When damage is dealt (seconds from start)
		
		-- Optional VFX
		VFX = {
			OnCast = "VFXName",            -- VFX to play on cast (from ReplicatedStorage.vfx)
			OnHit = "VFXName",             -- VFX to play on hit
		},
		
		-- Optional properties
		IsAoE = boolean,                   -- Hits multiple targets
		AoERadius = number,                -- AoE radius in studs
		Knockback = number,                -- Knockback force
		RangeMultiplier = number,          -- Multiplier for weapon's base range
	}
]]

-- Skill Configurations
local Skills = {
	--[[
		BASH - Basic impact skill
		Heavy overhead strike that deals high damage
	]]
	["Bash"] = {
		DisplayName = "Bash",
		Animation = "rbxassetid://93246963192636",
		Cooldown = 5,
		Duration = 0.8,
		HitTime = 0.3,
		
		VFX = {
			OnCast = nil,
			OnHit = nil,
		},
		
		IsAoE = false,
		Knockback = 15,
		RangeMultiplier = 1.0,
	},
	
	--[[
		SWEEP - Wide arc attack (2-stage)
		Horizontal sweep with two hits at 30 and 60 frames
	]]
	["Sweep"] = {
		DisplayName = "Sweep",
		Animation = "rbxassetid://83432713663049",
		Cooldown = 8,
		Duration = 2.2, -- Full animation duration
		
		-- Multi-hit configuration (frame times at 30 FPS)
		IsMultiHit = true,
		HitTimes = {
			30 / 30, -- First hit at frame 30 = 1.0 seconds
			60 / 30, -- Second hit at frame 60 = 2.0 seconds
		},
		HitTime = 1.0, -- First hit time for single-hit fallback
		
		VFX = {
			OnCast = nil,
			OnHit = nil,
		},
		
		IsAoE = true,
		AoERadius = 8,
		Knockback = 8,
		RangeMultiplier = 1.2,
	},
	
	--[[
		THRUST - Piercing lunge
		Quick forward thrust with dash and extended range
	]]
	["Thrust"] = {
		DisplayName = "Thrust",
		Animation = "rbxassetid://76362379318834",
		Cooldown = 4,
		Duration = 0.5,
		HitTime = 0.2,
		
		-- Dash configuration
		DashForward = 5, -- Studs to dash forward
		DashDuration = 0.15, -- How long the dash takes
		LeaveTrail = true, -- Enable trail effect during dash
		
		VFX = {
			OnCast = nil,
			OnHit = "skills/thrust-hit", -- VFX path under ReplicatedStorage.vfx
		},
		
		IsAoE = false,
		Knockback = 5,
		RangeMultiplier = 1.5,
	},
	
	--[[
		UPPERCUT - Launching strike
		Upward slash that launches enemies
	]]
	["Uppercut"] = {
		DisplayName = "Uppercut",
		Animation = "rbxassetid://93246963192636", -- Replace with actual uppercut animation
		Cooldown = 6,
		Duration = 0.7,
		HitTime = 0.25,
		
		VFX = {
			OnCast = nil,
			OnHit = nil,
		},
		
		IsAoE = false,
		Knockback = 25,
		RangeMultiplier = 0.8,
	},
	
	--[[
		SLAM - Ground pound
		Powerful downward strike with AoE damage
	]]
	["Slam"] = {
		DisplayName = "Slam",
		Animation = "rbxassetid://93246963192636", -- Replace with actual slam animation
		Cooldown = 10,
		Duration = 1.0,
		HitTime = 0.5,
		
		VFX = {
			OnCast = nil,
			OnHit = nil,
		},
		
		IsAoE = true,
		AoERadius = 10,
		Knockback = 20,
		RangeMultiplier = 0.6,
	},
}

-- Default skill template (fallback)
local DEFAULT_SKILL = {
	DisplayName = "Unknown",
	Animation = "",
	Cooldown = 5,
	Duration = 0.5,
	HitTime = 0.2,
	VFX = {},
	IsAoE = false,
	Knockback = 0,
	RangeMultiplier = 1.0,
}

-- Get skill config by name
function SkillRegistry.GetSkill(skillName)
	return Skills[skillName] or DEFAULT_SKILL
end

-- Check if skill exists
function SkillRegistry.HasSkill(skillName)
	return Skills[skillName] ~= nil
end

-- Get all skill names
function SkillRegistry.GetAllSkillNames()
	local names = {}
	for name, _ in pairs(Skills) do
		table.insert(names, name)
	end
	return names
end

-- Register a new skill (for runtime additions)
function SkillRegistry.RegisterSkill(skillName, config)
	Skills[skillName] = config
end

-- Get skill animation ID
function SkillRegistry.GetAnimation(skillName)
	local skill = SkillRegistry.GetSkill(skillName)
	return skill.Animation
end

-- Get skill cooldown
function SkillRegistry.GetCooldown(skillName)
	local skill = SkillRegistry.GetSkill(skillName)
	return skill.Cooldown
end

-- Get skill VFX config
function SkillRegistry.GetVFX(skillName)
	local skill = SkillRegistry.GetSkill(skillName)
	return skill.VFX or {}
end

-- Get default skill config
function SkillRegistry.GetDefault()
	return DEFAULT_SKILL
end

return SkillRegistry
