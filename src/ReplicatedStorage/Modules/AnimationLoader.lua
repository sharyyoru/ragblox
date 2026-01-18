--[[
	AnimationLoader Module
	Handles modular animation loading based on weapon style (1h/2h)
	Place in ReplicatedStorage.Modules
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local WeaponRegistry = require(Modules:WaitForChild("WeaponRegistry"))

local AnimationLoader = {}
AnimationLoader.__index = AnimationLoader

-- Cache for loaded animation tracks per character
local animationCache = {}

function AnimationLoader.new(character, weaponStyle)
	local self = setmetatable({}, AnimationLoader)
	
	print("[AnimationLoader] Creating for character: " .. character.Name .. ", weaponStyle: " .. weaponStyle)
	
	self.Character = character
	self.WeaponStyle = weaponStyle or "1h"
	self.Humanoid = character:FindFirstChildOfClass("Humanoid")
	self.Animator = self.Humanoid and self.Humanoid:FindFirstChildOfClass("Animator")
	self.LoadedTracks = {}
	
	print("[AnimationLoader] Humanoid: " .. tostring(self.Humanoid))
	print("[AnimationLoader] Animator (before): " .. tostring(self.Animator))
	
	if not self.Animator and self.Humanoid then
		self.Animator = Instance.new("Animator")
		self.Animator.Parent = self.Humanoid
		print("[AnimationLoader] Created new Animator")
	end
	
	print("[AnimationLoader] Animator (after): " .. tostring(self.Animator))
	
	return self
end

function AnimationLoader:GetStyleAnimations()
	return WeaponRegistry.GetStyleAnimations(self.WeaponStyle)
end

function AnimationLoader:LoadAnimations()
	print("[AnimationLoader] LoadAnimations called for style: " .. self.WeaponStyle)
	
	if not self.Animator then
		warn("[AnimationLoader] No Animator found!")
		return false
	end
	
	local styleAnims = self:GetStyleAnimations()
	if not styleAnims then
		warn("[AnimationLoader] No style animations found for: " .. self.WeaponStyle)
		return false
	end
	
	local count = 0
	for animName, animId in pairs(styleAnims) do
		print("[AnimationLoader] Loading animation: " .. animName .. " ID: " .. animId)
		
		local animInstance = Instance.new("Animation")
		animInstance.AnimationId = animId
		
		local success, track = pcall(function()
			return self.Animator:LoadAnimation(animInstance)
		end)
		
		if success and track then
			self.LoadedTracks[animName] = track
			count = count + 1
			print("[AnimationLoader] Loaded track: " .. animName)
		else
			warn("[AnimationLoader] Failed to load animation: " .. animName .. " - " .. tostring(track))
		end
	end
	
	print("[AnimationLoader] Total animations loaded: " .. count)
	return count > 0
end

function AnimationLoader:GetTrack(animationName)
	return self.LoadedTracks[animationName]
end

function AnimationLoader:PlayAnimation(animationName, fadeTime, weight, speed, priority)
	local track = self.LoadedTracks[animationName]
	if track then
		-- Set animation priority (Action for attacks, Movement for sprint, Idle for idle)
		if priority then
			track.Priority = priority
		elseif animationName:match("^M%d") then
			-- M1, M2, M3, M4 are attack animations - use Action priority
			track.Priority = Enum.AnimationPriority.Action
		elseif animationName == "Sprint" then
			track.Priority = Enum.AnimationPriority.Movement
		elseif animationName == "Idle" then
			track.Priority = Enum.AnimationPriority.Idle
		end
		
		print("[AnimationLoader] Playing " .. animationName .. " with priority: " .. tostring(track.Priority))
		track:Play(fadeTime or 0.1, weight or 1, speed or 1)
		return track
	else
		warn("[AnimationLoader] Animation not found: " .. animationName)
		return nil
	end
end

function AnimationLoader:StopAnimation(animationName, fadeTime)
	local track = self.LoadedTracks[animationName]
	if track then
		track:Stop(fadeTime or 0.1)
	end
end

function AnimationLoader:StopAllAnimations(fadeTime)
	for _, track in pairs(self.LoadedTracks) do
		track:Stop(fadeTime or 0.1)
	end
end

function AnimationLoader:Destroy()
	self:StopAllAnimations(0)
	for name, track in pairs(self.LoadedTracks) do
		track:Destroy()
	end
	self.LoadedTracks = {}
end

return AnimationLoader
