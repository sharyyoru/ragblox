--[[
	CombatHandler Module
	Manages combo system and combat animations
	Uses WeaponRegistry for weapon-specific skills
	Place in ReplicatedStorage.Modules
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local WeaponRegistry = require(Modules:WaitForChild("WeaponRegistry"))

local CombatHandler = {}
CombatHandler.__index = CombatHandler

function CombatHandler.new(animationLoader, weaponId)
	local self = setmetatable({}, CombatHandler)
	
	self.AnimationLoader = animationLoader
	self.WeaponId = weaponId or "BasicSword"
	self.WeaponConfig = WeaponRegistry.GetWeapon(self.WeaponId)
	
	-- Get combo sequence from weapon config
	self.ComboSequence = self.WeaponConfig.ComboSequence or {"M1", "M2", "M3", "M4"}
	self.CurrentCombo = 0
	self.MaxCombo = #self.ComboSequence
	self.LastAttackTime = 0
	self.CanAttack = true
	self.CurrentTrack = nil
	self.SkillCooldowns = {} -- Track individual skill cooldowns
	
	return self
end

function CombatHandler:Attack()
	local currentTime = tick()
	local timeSinceLastAttack = currentTime - self.LastAttackTime
	
	local attackCooldown = self.WeaponConfig.AttackCooldown or 0.5
	local comboResetTime = self.WeaponConfig.ComboResetTime or 1.5
	
	print("[CombatHandler] Attack called - timeSince: " .. string.format("%.2f", timeSinceLastAttack))
	
	if not self.CanAttack then 
		print("[CombatHandler] Cannot attack - CanAttack is false")
		return false 
	end
	
	if timeSinceLastAttack < attackCooldown then
		print("[CombatHandler] Cannot attack - on cooldown")
		return false
	end
	
	-- Reset combo if too much time passed
	if timeSinceLastAttack > comboResetTime then
		self.CurrentCombo = 0
	end
	
	-- Increment combo
	self.CurrentCombo = self.CurrentCombo + 1
	if self.CurrentCombo > self.MaxCombo then
		self.CurrentCombo = 1
	end
	
	-- Get skill name for current combo
	local skillName = self.ComboSequence[self.CurrentCombo]
	local skillConfig = self.WeaponConfig.Skills[skillName]
	
	if not skillConfig then
		warn("[CombatHandler] Unknown skill: " .. skillName)
		return false
	end
	
	-- Get animation name from skill config
	local animName = skillConfig.Animation or skillName
	print("[CombatHandler] Playing combo " .. self.CurrentCombo .. ": " .. skillName .. " (anim: " .. animName .. ")")
	
	self.LastAttackTime = currentTime
	
	-- Stop previous track if playing
	if self.CurrentTrack and self.CurrentTrack.IsPlaying then
		self.CurrentTrack:Stop(0.1)
	end
	
	self.CurrentTrack = self.AnimationLoader:PlayAnimation(animName, 0.1)
	
	if self.CurrentTrack then
		print("[CombatHandler] Track playing: " .. animName)
		return true, skillName, animName
	else
		print("[CombatHandler] No track returned!")
		return false
	end
end

-- Use a specific skill (not part of combo)
function CombatHandler:UseSkill(skillName)
	local currentTime = tick()
	local skillConfig = self.WeaponConfig.Skills[skillName]
	
	if not skillConfig then
		warn("[CombatHandler] Unknown skill: " .. skillName)
		return false
	end
	
	-- Check skill-specific cooldown
	if skillConfig.Cooldown then
		local lastUse = self.SkillCooldowns[skillName] or 0
		if currentTime - lastUse < skillConfig.Cooldown then
			print("[CombatHandler] Skill on cooldown: " .. skillName)
			return false
		end
		self.SkillCooldowns[skillName] = currentTime
	end
	
	local animName = skillConfig.Animation or skillName
	
	-- Stop current track
	if self.CurrentTrack and self.CurrentTrack.IsPlaying then
		self.CurrentTrack:Stop(0.1)
	end
	
	self.CurrentTrack = self.AnimationLoader:PlayAnimation(animName, 0.1)
	
	if self.CurrentTrack then
		print("[CombatHandler] Skill used: " .. skillName)
		return true, skillName, animName
	end
	
	return false
end

-- Get all available skills for this weapon
function CombatHandler:GetAvailableSkills()
	local skills = {}
	for skillName, _ in pairs(self.WeaponConfig.Skills) do
		table.insert(skills, skillName)
	end
	return skills
end

-- Check if a skill is on cooldown
function CombatHandler:IsSkillOnCooldown(skillName)
	local skillConfig = self.WeaponConfig.Skills[skillName]
	if not skillConfig or not skillConfig.Cooldown then
		return false
	end
	
	local lastUse = self.SkillCooldowns[skillName] or 0
	return (tick() - lastUse) < skillConfig.Cooldown
end

-- Get remaining cooldown for a skill
function CombatHandler:GetSkillCooldown(skillName)
	local skillConfig = self.WeaponConfig.Skills[skillName]
	if not skillConfig or not skillConfig.Cooldown then
		return 0
	end
	
	local lastUse = self.SkillCooldowns[skillName] or 0
	local remaining = skillConfig.Cooldown - (tick() - lastUse)
	return math.max(0, remaining)
end

function CombatHandler:ResetCombo()
	self.CurrentCombo = 0
	if self.CurrentTrack and self.CurrentTrack.IsPlaying then
		self.CurrentTrack:Stop(0.1)
	end
end

function CombatHandler:SetCanAttack(canAttack)
	self.CanAttack = canAttack
end

function CombatHandler:GetCurrentCombo()
	return self.CurrentCombo
end

function CombatHandler:IsCurrentlyAttacking()
	if self.CurrentTrack and self.CurrentTrack.IsPlaying then
		return true
	end
	return false
end

function CombatHandler:Destroy()
	self:ResetCombo()
	self.SkillCooldowns = {}
end

return CombatHandler
