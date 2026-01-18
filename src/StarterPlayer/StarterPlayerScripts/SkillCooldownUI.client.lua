--[[
	SkillCooldownUI (Client)
	Displays skill cooldown indicators next to dash button
	Style matches DashCooldownUI (Destiny 2 style)
	Place in StarterPlayer.StarterPlayerScripts
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SkillHandler = require(Modules:WaitForChild("SkillHandler"))
local SkillRegistry = require(Modules:WaitForChild("SkillRegistry"))
local WeaponRegistry = require(Modules:WaitForChild("WeaponRegistry"))

-- Configuration
local READY_COLOR = Color3.fromRGB(255, 255, 255)
local COOLDOWN_COLOR = Color3.fromRGB(80, 80, 90)
local CHARGING_COLOR = Color3.fromRGB(200, 200, 200)
local SLOT_SIZE = 44
local SLOT_SPACING = 8
local BASE_X_OFFSET = -130 -- Start position (left of dash button)

-- State
local skillHandler = SkillHandler.new()
local skillSlotFrames = {} -- Store UI frames for each slot
local activeSlots = {} -- Currently displayed slots

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkillCooldownUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- Container for all skill slots
local mainContainer = Instance.new("Frame")
mainContainer.Name = "SkillSlotsContainer"
mainContainer.Size = UDim2.new(0, 300, 0, 60)
mainContainer.Position = UDim2.new(1, -70, 1, -70)
mainContainer.AnchorPoint = Vector2.new(1, 1)
mainContainer.BackgroundTransparency = 1
mainContainer.Parent = screenGui

-- Create a single skill slot UI
local function createSkillSlot(slotKey, skillName, displayName)
	local container = Instance.new("Frame")
	container.Name = "SkillSlot_" .. slotKey
	container.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 0.4
	container.BorderSizePixel = 0
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 6)
	containerCorner.Parent = container
	
	-- Border stroke
	local containerStroke = Instance.new("UIStroke")
	containerStroke.Name = "Stroke"
	containerStroke.Color = READY_COLOR
	containerStroke.Thickness = 1.5
	containerStroke.Transparency = 0.2
	containerStroke.Parent = container
	
	-- Cooldown overlay (fills from bottom to top)
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
	cooldownOverlay.Position = UDim2.new(0, 0, 1, 0)
	cooldownOverlay.AnchorPoint = Vector2.new(0, 1)
	cooldownOverlay.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	cooldownOverlay.BackgroundTransparency = 0.3
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.ZIndex = 2
	cooldownOverlay.Parent = container
	
	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 6)
	overlayCorner.Parent = cooldownOverlay
	
	-- Skill name label (top)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName or skillName
	nameLabel.TextColor3 = READY_COLOR
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 9
	nameLabel.TextScaled = false
	nameLabel.ZIndex = 3
	nameLabel.Parent = container
	
	-- Keybind indicator (bottom right corner)
	local keybindFrame = Instance.new("Frame")
	keybindFrame.Name = "KeybindFrame"
	keybindFrame.Size = UDim2.new(0, 16, 0, 16)
	keybindFrame.Position = UDim2.new(1, -2, 1, -2)
	keybindFrame.AnchorPoint = Vector2.new(1, 1)
	keybindFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	keybindFrame.BackgroundTransparency = 0.2
	keybindFrame.BorderSizePixel = 0
	keybindFrame.ZIndex = 4
	keybindFrame.Parent = container
	
	local keybindCorner = Instance.new("UICorner")
	keybindCorner.CornerRadius = UDim.new(0, 3)
	keybindCorner.Parent = keybindFrame
	
	local keybindLabel = Instance.new("TextLabel")
	keybindLabel.Name = "KeybindLabel"
	keybindLabel.Size = UDim2.new(1, 0, 1, 0)
	keybindLabel.BackgroundTransparency = 1
	keybindLabel.Text = slotKey
	keybindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	keybindLabel.Font = Enum.Font.GothamBold
	keybindLabel.TextSize = 10
	keybindLabel.ZIndex = 5
	keybindLabel.Parent = keybindFrame
	
	-- Cooldown text (shows remaining seconds)
	local cooldownText = Instance.new("TextLabel")
	cooldownText.Name = "CooldownText"
	cooldownText.Size = UDim2.new(1, 0, 0.5, 0)
	cooldownText.Position = UDim2.new(0, 0, 0.35, 0)
	cooldownText.BackgroundTransparency = 1
	cooldownText.Text = ""
	cooldownText.TextColor3 = CHARGING_COLOR
	cooldownText.Font = Enum.Font.GothamBold
	cooldownText.TextSize = 14
	cooldownText.ZIndex = 4
	cooldownText.Visible = false
	cooldownText.Parent = container
	
	return {
		Frame = container,
		Stroke = containerStroke,
		Overlay = cooldownOverlay,
		NameLabel = nameLabel,
		CooldownText = cooldownText,
		SlotKey = slotKey,
		SkillName = skillName,
		CooldownEndTime = 0,
		CooldownDuration = 0,
		IsOnCooldown = false,
	}
end

-- Set slot to ready state
local function setSlotReady(slotData)
	slotData.IsOnCooldown = false
	
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	TweenService:Create(slotData.NameLabel, tweenInfo, {
		TextColor3 = READY_COLOR,
		TextTransparency = 0
	}):Play()
	
	TweenService:Create(slotData.Stroke, tweenInfo, {
		Color = READY_COLOR,
		Transparency = 0.2
	}):Play()
	
	TweenService:Create(slotData.Overlay, tweenInfo, {
		Size = UDim2.new(1, 0, 1, 0)
	}):Play()
	
	slotData.CooldownText.Visible = false
	
	-- Subtle pulse
	local pulseInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	slotData.Frame.Size = UDim2.new(0, SLOT_SIZE - 4, 0, SLOT_SIZE - 4)
	TweenService:Create(slotData.Frame, pulseInfo, {
		Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	}):Play()
end

-- Start cooldown on a slot
local function startSlotCooldown(slotData, duration)
	slotData.IsOnCooldown = true
	slotData.CooldownDuration = duration
	slotData.CooldownEndTime = tick() + duration
	
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	TweenService:Create(slotData.NameLabel, tweenInfo, {
		TextColor3 = COOLDOWN_COLOR,
		TextTransparency = 0.5
	}):Play()
	
	TweenService:Create(slotData.Stroke, tweenInfo, {
		Color = COOLDOWN_COLOR,
		Transparency = 0.6
	}):Play()
	
	slotData.Overlay.Size = UDim2.new(1, 0, 0, 0)
	slotData.CooldownText.Visible = true
end

-- Clear all skill slots
local function clearSkillSlots()
	for _, slotData in pairs(skillSlotFrames) do
		if slotData.Frame then
			slotData.Frame:Destroy()
		end
	end
	skillSlotFrames = {}
	activeSlots = {}
end

-- Update skill slots for current weapon
local function updateSkillSlots(weaponName)
	clearSkillSlots()
	
	if not weaponName then
		return
	end
	
	skillHandler:SetWeapon(weaponName)
	local slots = skillHandler:GetActiveSlots()
	
	-- Position slots from right to left (next to dash button)
	local slotIndex = 0
	for _, skillInfo in ipairs(slots) do
		local xOffset = BASE_X_OFFSET - (slotIndex * (SLOT_SIZE + SLOT_SPACING))
		
		local slotData = createSkillSlot(
			skillInfo.SlotKey,
			skillInfo.SkillName,
			skillInfo.DisplayName
		)
		
		slotData.Frame.Position = UDim2.new(1, xOffset, 1, -70)
		slotData.Frame.AnchorPoint = Vector2.new(1, 1)
		slotData.Frame.Parent = screenGui
		
		-- Store cooldown duration from skill config
		slotData.SkillCooldown = skillInfo.Cooldown
		
		skillSlotFrames[skillInfo.SlotKey] = slotData
		table.insert(activeSlots, skillInfo.SlotKey)
		
		setSlotReady(slotData)
		slotIndex = slotIndex + 1
	end
	
	print("[SkillCooldownUI] Updated slots for weapon: " .. weaponName .. " (" .. slotIndex .. " skills)")
end

-- Listen for skill cooldown events
local function setupCooldownEvents()
	-- Create BindableEvent for skill cooldowns
	local cooldownEvent = Instance.new("BindableEvent")
	cooldownEvent.Name = "SkillCooldownEvent"
	cooldownEvent.Parent = Player
	
	cooldownEvent.Event:Connect(function(slotKey, duration)
		local slotData = skillSlotFrames[slotKey]
		if slotData then
			startSlotCooldown(slotData, duration)
		end
	end)
	
	print("[SkillCooldownUI] Cooldown event listener ready")
end

-- Listen for weapon equip/unequip
local function setupWeaponListener()
	local character = Player.Character or Player.CharacterAdded:Wait()
	
	local function onChildAdded(child)
		if child:IsA("Tool") then
			local weaponName = child:GetAttribute("WeaponId") or child.Name
			updateSkillSlots(weaponName)
		end
	end
	
	local function onChildRemoved(child)
		if child:IsA("Tool") then
			-- Check if any other tool is equipped
			local hasTool = false
			for _, item in pairs(character:GetChildren()) do
				if item:IsA("Tool") and item ~= child then
					hasTool = true
					break
				end
			end
			
			if not hasTool then
				clearSkillSlots()
			end
		end
	end
	
	character.ChildAdded:Connect(onChildAdded)
	character.ChildRemoved:Connect(onChildRemoved)
	
	-- Check for existing equipped tool
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Tool") then
			onChildAdded(child)
			break
		end
	end
	
	-- Handle respawn
	Player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		clearSkillSlots()
		
		character.ChildAdded:Connect(onChildAdded)
		character.ChildRemoved:Connect(onChildRemoved)
	end)
end

-- Update loop for cooldown displays
RunService.Heartbeat:Connect(function()
	for slotKey, slotData in pairs(skillSlotFrames) do
		if slotData.IsOnCooldown then
			local remaining = slotData.CooldownEndTime - tick()
			
			if remaining <= 0 then
				setSlotReady(slotData)
			else
				slotData.CooldownText.Text = string.format("%.0f", math.ceil(remaining))
				local progress = 1 - (remaining / slotData.CooldownDuration)
				slotData.Overlay.Size = UDim2.new(1, 0, progress, 0)
			end
		end
	end
end)

-- Initialize
setupCooldownEvents()
setupWeaponListener()

print("[SkillCooldownUI] Initialized")

-- Export for other scripts
return {
	StartCooldown = function(slotKey, duration)
		local slotData = skillSlotFrames[slotKey]
		if slotData then
			startSlotCooldown(slotData, duration)
		end
	end,
	
	UpdateWeapon = updateSkillSlots,
	ClearSlots = clearSkillSlots,
}
