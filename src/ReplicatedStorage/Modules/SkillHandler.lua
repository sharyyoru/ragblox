--[[
	SkillHandler Module
	Handles skill execution, cooldowns, and animations
	Place in ReplicatedStorage.Modules
	
	Usage:
	- Client: Use for playing animations and tracking cooldowns
	- Server: Use for damage calculation and validation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local SkillRegistry = require(Modules:WaitForChild("SkillRegistry"))
local WeaponRegistry = require(Modules:WaitForChild("WeaponRegistry"))

local SkillHandler = {}
SkillHandler.__index = SkillHandler

-- Skill slot key bindings
SkillHandler.SKILL_KEYS = {"Z", "X", "C", "V", "F"}

function SkillHandler.new()
	local self = setmetatable({}, SkillHandler)
	
	-- Track cooldowns per skill slot
	self.Cooldowns = {
		Z = 0,
		X = 0,
		C = 0,
		V = 0,
		F = 0,
	}
	
	-- Current weapon name
	self.CurrentWeapon = nil
	
	-- Animation tracks cache
	self.AnimationTracks = {}
	
	-- Callback for cooldown events (UI updates)
	self.OnCooldownStart = nil
	self.OnCooldownEnd = nil
	
	return self
end

-- Set current weapon
function SkillHandler:SetWeapon(weaponName)
	self.CurrentWeapon = weaponName
	
	-- Clear animation cache when weapon changes
	self.AnimationTracks = {}
end

-- Check if a skill slot is available (not on cooldown)
function SkillHandler:CanUseSkill(slotKey)
	if not self.CurrentWeapon then
		return false, "No weapon equipped"
	end
	
	-- Check if slot has a skill assigned
	local slotData = WeaponRegistry.GetSkillSlot(self.CurrentWeapon, slotKey)
	if not slotData then
		return false, "No skill in slot " .. slotKey
	end
	
	-- Check cooldown
	local now = tick()
	if self.Cooldowns[slotKey] and self.Cooldowns[slotKey] > now then
		local remaining = self.Cooldowns[slotKey] - now
		return false, string.format("On cooldown (%.1fs)", remaining)
	end
	
	return true, slotData
end

-- Get skill info for a slot
function SkillHandler:GetSlotSkillInfo(slotKey)
	if not self.CurrentWeapon then
		return nil
	end
	
	local slotData = WeaponRegistry.GetSkillSlot(self.CurrentWeapon, slotKey)
	if not slotData then
		return nil
	end
	
	local skillConfig = SkillRegistry.GetSkill(slotData.SkillName)
	return {
		SlotKey = slotKey,
		SkillName = slotData.SkillName,
		DisplayName = skillConfig.DisplayName,
		DamageMultiplier = slotData.DamageMultiplier,
		Cooldown = skillConfig.Cooldown,
		Animation = skillConfig.Animation,
		HitTime = skillConfig.HitTime,
		Duration = skillConfig.Duration,
		IsAoE = skillConfig.IsAoE,
		AoERadius = skillConfig.AoERadius,
		Knockback = skillConfig.Knockback,
		RangeMultiplier = skillConfig.RangeMultiplier,
		VFX = skillConfig.VFX,
		-- Multi-hit support
		IsMultiHit = skillConfig.IsMultiHit,
		HitTimes = skillConfig.HitTimes,
		-- Dash support
		DashForward = skillConfig.DashForward,
		DashDuration = skillConfig.DashDuration,
		LeaveTrail = skillConfig.LeaveTrail,
		-- Channeled skill support
		IsChanneled = skillConfig.IsChanneled,
		DamageInterval = skillConfig.DamageInterval,
		MinDuration = skillConfig.MinDuration,
		-- Flight skill support
		IsFlight = skillConfig.IsFlight,
		IdleAnimation = skillConfig.IdleAnimation,
		MoveAnimation = skillConfig.MoveAnimation,
		Sound = skillConfig.Sound,
	}
end

-- Get all active skill slots for current weapon
function SkillHandler:GetActiveSlots()
	if not self.CurrentWeapon then
		return {}
	end
	
	local activeSlots = {}
	local skillSlots = WeaponRegistry.GetSkillSlots(self.CurrentWeapon)
	
	for _, slotKey in ipairs(SkillHandler.SKILL_KEYS) do
		local slotData = skillSlots[slotKey]
		if slotData then
			local skillInfo = self:GetSlotSkillInfo(slotKey)
			if skillInfo then
				table.insert(activeSlots, skillInfo)
			end
		end
	end
	
	return activeSlots
end

-- Start cooldown for a skill slot
function SkillHandler:StartCooldown(slotKey)
	local skillInfo = self:GetSlotSkillInfo(slotKey)
	if not skillInfo then
		return
	end
	
	local cooldownDuration = skillInfo.Cooldown
	self.Cooldowns[slotKey] = tick() + cooldownDuration
	
	-- Fire callback for UI
	if self.OnCooldownStart then
		self.OnCooldownStart(slotKey, cooldownDuration, skillInfo.DisplayName)
	end
	
	-- Schedule cooldown end callback
	task.delay(cooldownDuration, function()
		if self.OnCooldownEnd then
			self.OnCooldownEnd(slotKey)
		end
	end)
end

-- Get remaining cooldown for a slot
function SkillHandler:GetCooldownRemaining(slotKey)
	local endTime = self.Cooldowns[slotKey] or 0
	local remaining = endTime - tick()
	return math.max(0, remaining)
end

-- Check if slot is on cooldown
function SkillHandler:IsOnCooldown(slotKey)
	return self:GetCooldownRemaining(slotKey) > 0
end

-- Use a skill (returns skill info if successful)
function SkillHandler:UseSkill(slotKey)
	local canUse, result = self:CanUseSkill(slotKey)
	
	if not canUse then
		return nil, result
	end
	
	local skillInfo = self:GetSlotSkillInfo(slotKey)
	if not skillInfo then
		return nil, "Skill not found"
	end
	
	-- Start cooldown
	self:StartCooldown(slotKey)
	
	return skillInfo, "Success"
end

-- Calculate damage for a skill
function SkillHandler:CalculateDamage(slotKey)
	if not self.CurrentWeapon then
		return 0
	end
	
	return WeaponRegistry.CalculateSkillSlotDamage(self.CurrentWeapon, slotKey)
end

-- Load and play skill animation
function SkillHandler:PlayAnimation(humanoid, slotKey)
	local skillInfo = self:GetSlotSkillInfo(slotKey)
	if not skillInfo or not skillInfo.Animation or skillInfo.Animation == "" then
		return nil
	end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	-- Check cache
	local cacheKey = slotKey .. "_" .. skillInfo.SkillName
	if not self.AnimationTracks[cacheKey] then
		local animation = Instance.new("Animation")
		animation.AnimationId = skillInfo.Animation
		self.AnimationTracks[cacheKey] = animator:LoadAnimation(animation)
	end
	
	local track = self.AnimationTracks[cacheKey]
	track:Play()
	
	return track, skillInfo.HitTime
end

-- Reset all cooldowns
function SkillHandler:ResetCooldowns()
	for _, slotKey in ipairs(SkillHandler.SKILL_KEYS) do
		self.Cooldowns[slotKey] = 0
	end
end

return SkillHandler
