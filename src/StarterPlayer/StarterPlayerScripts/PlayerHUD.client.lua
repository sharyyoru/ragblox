--[[
	PlayerHUD Client Script
	Creates and manages the player's own HP bar, name, and level display
	Modern animated UI matching SAO-style health bars exactly
	Place in StarterPlayerScripts
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
	-- Colors matching screenshot exactly
	HealthColor = Color3.fromRGB(154, 205, 50), -- Yellow-green like screenshot
	HealthColorMid = Color3.fromRGB(241, 196, 15),
	HealthColorLow = Color3.fromRGB(232, 65, 24),
	BackgroundColor = Color3.fromRGB(30, 30, 30),
	BorderColor = Color3.fromRGB(180, 180, 80), -- Olive/yellow border
	AccentColor = Color3.fromRGB(241, 196, 15), -- Yellow for bolt
	
	-- Animation
	HealthTweenTime = 0.3,
	PulseDuration = 0.5,
}

-- State
local currentHealth = 100
local maxHealth = 100
local currentLevel = 1
local playerName = Player.Name

-- Create the HUD matching screenshot 4 exactly
local function createPlayerHUD()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlayerHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = PlayerGui
	
	-- Main container positioned at bottom-left
	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "MainContainer"
	mainContainer.Size = UDim2.new(0, 480, 0, 85)
	mainContainer.Position = UDim2.new(0, 20, 1, -110)
	mainContainer.BackgroundTransparency = 1
	mainContainer.Parent = screenGui
	
	-- Party/Add button (+ icon on the left) - dark rounded square
	local addButton = Instance.new("ImageButton")
	addButton.Name = "AddButton"
	addButton.Size = UDim2.new(0, 40, 0, 40)
	addButton.Position = UDim2.new(0, 0, 0, 8)
	addButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	addButton.BackgroundTransparency = 0.1
	addButton.Image = ""
	addButton.Parent = mainContainer
	
	local addCorner = Instance.new("UICorner")
	addCorner.CornerRadius = UDim.new(0.25, 0)
	addCorner.Parent = addButton
	
	local addStroke = Instance.new("UIStroke")
	addStroke.Color = Color3.fromRGB(80, 80, 80)
	addStroke.Thickness = 1
	addStroke.Parent = addButton
	
	-- Plus icon
	local plusLabel = Instance.new("TextLabel")
	plusLabel.Name = "PlusLabel"
	plusLabel.Size = UDim2.new(1, 0, 1, 0)
	plusLabel.BackgroundTransparency = 1
	plusLabel.Text = "+"
	plusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	plusLabel.Font = Enum.Font.GothamBold
	plusLabel.TextSize = 24
	plusLabel.Parent = addButton
	
	-- Name label - white text
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 200, 0, 24)
	nameLabel.Position = UDim2.new(0, 50, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = playerName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.Parent = mainContainer
	
	-- Health bar outer frame with olive/yellow border
	local healthBarOuter = Instance.new("Frame")
	healthBarOuter.Name = "HealthBarOuter"
	healthBarOuter.Size = UDim2.new(0, 355, 0, 26)
	healthBarOuter.Position = UDim2.new(0, 50, 0, 26)
	healthBarOuter.BackgroundColor3 = CONFIG.BackgroundColor
	healthBarOuter.BorderSizePixel = 0
	healthBarOuter.ClipsDescendants = true
	healthBarOuter.Parent = mainContainer
	
	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0, 3)
	outerCorner.Parent = healthBarOuter
	
	-- Olive/yellow border stroke
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Name = "BorderStroke"
	borderStroke.Color = CONFIG.BorderColor
	borderStroke.Thickness = 2
	borderStroke.Parent = healthBarOuter
	
	-- Inner padding frame
	local healthBarInner = Instance.new("Frame")
	healthBarInner.Name = "HealthBarInner"
	healthBarInner.Size = UDim2.new(1, -6, 1, -6)
	healthBarInner.Position = UDim2.new(0, 3, 0, 3)
	healthBarInner.BackgroundTransparency = 1
	healthBarInner.ClipsDescendants = true
	healthBarInner.Parent = healthBarOuter
	
	-- Damage indicator (red/orange, behind health)
	local damageFill = Instance.new("Frame")
	damageFill.Name = "DamageFill"
	damageFill.Size = UDim2.new(1, 0, 1, 0)
	damageFill.Position = UDim2.new(0, 0, 0, 0)
	damageFill.BackgroundColor3 = CONFIG.HealthColorLow
	damageFill.BorderSizePixel = 0
	damageFill.ZIndex = 1
	damageFill.Parent = healthBarInner
	
	local damageCorner = Instance.new("UICorner")
	damageCorner.CornerRadius = UDim.new(0, 2)
	damageCorner.Parent = damageFill
	
	-- Health fill bar - yellow-green color
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.Position = UDim2.new(0, 0, 0, 0)
	healthFill.BackgroundColor3 = CONFIG.HealthColor
	healthFill.BorderSizePixel = 0
	healthFill.ZIndex = 2
	healthFill.Parent = healthBarInner
	
	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 2)
	healthCorner.Parent = healthFill
	
	-- Gradient for 3D shine effect
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(230, 230, 230)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(200, 200, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)),
	})
	gradient.Rotation = 90
	gradient.Parent = healthFill
	
	-- Top shine highlight
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(1, 0, 0.4, 0)
	shine.Position = UDim2.new(0, 0, 0, 0)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.ZIndex = 3
	shine.Parent = healthFill
	
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(0, 2)
	shineCorner.Parent = shine
	
	-- Small accent bar near end (angled like in screenshot)
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(0, 8, 0, 16)
	accentBar.Position = UDim2.new(1, -18, 0.5, -8)
	accentBar.BackgroundColor3 = CONFIG.HealthColor
	accentBar.BackgroundTransparency = 0.2
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 4
	accentBar.Rotation = 20
	accentBar.Parent = healthBarOuter
	
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0.15, 0)
	accentCorner.Parent = accentBar
	
	-- Lightning bolt frame (yellow, angled/diamond shape)
	local boltFrame = Instance.new("Frame")
	boltFrame.Name = "BoltFrame"
	boltFrame.Size = UDim2.new(0, 28, 0, 28)
	boltFrame.Position = UDim2.new(1, 8, 0, -1)
	boltFrame.BackgroundColor3 = CONFIG.AccentColor
	boltFrame.BorderSizePixel = 0
	boltFrame.Rotation = 45
	boltFrame.Parent = healthBarOuter
	
	local boltCorner = Instance.new("UICorner")
	boltCorner.CornerRadius = UDim.new(0.15, 0)
	boltCorner.Parent = boltFrame
	
	-- Lightning bolt icon
	local boltLabel = Instance.new("TextLabel")
	boltLabel.Name = "BoltLabel"
	boltLabel.Size = UDim2.new(1, 0, 1, 0)
	boltLabel.BackgroundTransparency = 1
	boltLabel.Text = "⚡"
	boltLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
	boltLabel.Font = Enum.Font.GothamBold
	boltLabel.TextSize = 16
	boltLabel.Rotation = -45
	boltLabel.Parent = boltFrame
	
	-- Stats container (HP numbers and Level) - dark rounded box
	local statsContainer = Instance.new("Frame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(0, 175, 0, 20)
	statsContainer.Position = UDim2.new(0, 230, 0, 55)
	statsContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	statsContainer.BackgroundTransparency = 0.2
	statsContainer.BorderSizePixel = 0
	statsContainer.Parent = mainContainer
	
	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0.15, 0)
	statsCorner.Parent = statsContainer
	
	-- HP text (left side)
	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.Size = UDim2.new(0.6, 0, 1, 0)
	hpLabel.Position = UDim2.new(0.05, 0, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Text = "100 / 100"
	hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpLabel.TextXAlignment = Enum.TextXAlignment.Left
	hpLabel.Font = Enum.Font.Gotham
	hpLabel.TextSize = 14
	hpLabel.Parent = statsContainer
	
	-- Level text (right side)
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0.35, 0, 1, 0)
	levelLabel.Position = UDim2.new(0.62, 0, 0, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "LV: 1"
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 14
	levelLabel.Parent = statsContainer
	
	return {
		ScreenGui = screenGui,
		MainContainer = mainContainer,
		NameLabel = nameLabel,
		HealthFill = healthFill,
		DamageFill = damageFill,
		AccentBar = accentBar,
		HPLabel = hpLabel,
		LevelLabel = levelLabel,
		BoltFrame = boltFrame,
		HealthBarOuter = healthBarOuter,
	}
end

-- Create the HUD
local HUD = createPlayerHUD()

-- Update health display
local function updateHealth(newHealth, newMaxHealth, instant)
	local oldPercent = currentHealth / maxHealth
	currentHealth = newHealth
	maxHealth = newMaxHealth
	local newPercent = math.clamp(newHealth / newMaxHealth, 0, 1)
	
	-- Update HP text
	HUD.HPLabel.Text = string.format("%d / %d", math.floor(newHealth), math.floor(newMaxHealth))
	
	-- Animate health bar
	local tweenInfo = TweenInfo.new(
		instant and 0 or CONFIG.HealthTweenTime,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)
	
	local healthTween = TweenService:Create(HUD.HealthFill, tweenInfo, {
		Size = UDim2.new(newPercent, 0, 1, 0)
	})
	healthTween:Play()
	
	-- Damage indicator animation (delayed follow)
	if newPercent < oldPercent then
		task.delay(0.2, function()
			local damageTween = TweenService:Create(HUD.DamageFill, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {
				Size = UDim2.new(newPercent, 0, 1, 0)
			})
			damageTween:Play()
		end)
	else
		HUD.DamageFill.Size = UDim2.new(newPercent, 0, 1, 0)
	end
	
	-- Color change based on health
	local healthColor
	if newPercent > 0.5 then
		healthColor = CONFIG.HealthColor
	elseif newPercent > 0.25 then
		healthColor = CONFIG.HealthColorMid
	else
		healthColor = CONFIG.HealthColorLow
		-- Pulse effect when low health
		local pulse = TweenService:Create(HUD.HealthFill, TweenInfo.new(CONFIG.PulseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundTransparency = 0.3
		})
		pulse:Play()
	end
	
	TweenService:Create(HUD.HealthFill, tweenInfo, {
		BackgroundColor3 = healthColor
	}):Play()
	
	TweenService:Create(HUD.AccentBar, tweenInfo, {
		BackgroundColor3 = healthColor
	}):Play()
end

-- Update level display
local function updateLevel(newLevel)
	currentLevel = newLevel
	HUD.LevelLabel.Text = "LV: " .. tostring(newLevel)
end

-- Update name display
local function updateName(newName)
	playerName = newName
	HUD.NameLabel.Text = newName
end

-- Connect to character
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	
	-- Initial update
	updateHealth(humanoid.Health, humanoid.MaxHealth, true)
	
	-- Connect to health changes
	humanoid.HealthChanged:Connect(function(newHealth)
		updateHealth(newHealth, humanoid.MaxHealth)
	end)
	
	-- Listen for max health changes
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealth(humanoid.Health, humanoid.MaxHealth)
	end)
end

-- Listen for level attribute changes
local function setupAttributeListeners()
	-- Check if Level attribute exists
	local level = Player:GetAttribute("Level")
	if level then
		updateLevel(level)
	end
	
	Player:GetAttributeChangedSignal("Level"):Connect(function()
		local newLevel = Player:GetAttribute("Level")
		if newLevel then
			updateLevel(newLevel)
		end
	end)
end

-- Initialize
if Player.Character then
	onCharacterAdded(Player.Character)
end

Player.CharacterAdded:Connect(onCharacterAdded)
setupAttributeListeners()

-- Expose functions for external use
local module = {}
module.UpdateHealth = updateHealth
module.UpdateLevel = updateLevel
module.UpdateName = updateName
module.HUD = HUD

return module
