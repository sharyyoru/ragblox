--[[
	DashCooldownUI (Client)
	Destiny 2 style ability indicator - clean and minimal
	Place in StarterPlayer.StarterPlayerScripts
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Configuration
local READY_COLOR = Color3.fromRGB(255, 255, 255)
local COOLDOWN_COLOR = Color3.fromRGB(80, 80, 90)
local CHARGING_COLOR = Color3.fromRGB(200, 200, 200)

-- State
local cooldownEndTime = 0
local isOnCooldown = false
local cooldownDuration = 5

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DashCooldownUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- Main container - positioned bottom right, Destiny 2 style
local container = Instance.new("Frame")
container.Name = "DashContainer"
container.Size = UDim2.new(0, 44, 0, 44)
container.Position = UDim2.new(1, -70, 1, -70)
container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
container.BackgroundTransparency = 0.4
container.BorderSizePixel = 0
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 6)
containerCorner.Parent = container

-- Thin border stroke
local containerStroke = Instance.new("UIStroke")
containerStroke.Color = READY_COLOR
containerStroke.Thickness = 1.5
containerStroke.Transparency = 0.2
containerStroke.Parent = container

-- Cooldown overlay (fills from bottom to top)
local cooldownOverlay = Instance.new("Frame")
cooldownOverlay.Name = "CooldownOverlay"
cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
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

-- Dash icon (wind/speed lines icon)
local dashIcon = Instance.new("ImageLabel")
dashIcon.Name = "DashIcon"
dashIcon.Size = UDim2.new(0, 24, 0, 24)
dashIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
dashIcon.AnchorPoint = Vector2.new(0.5, 0.5)
dashIcon.BackgroundTransparency = 1
dashIcon.Image = "rbxassetid://6031091004" -- Dash/running icon
dashIcon.ImageColor3 = READY_COLOR
dashIcon.ZIndex = 3
dashIcon.Parent = container

-- Keybind indicator (small, bottom right corner)
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
keybindLabel.Text = "Q"
keybindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
keybindLabel.Font = Enum.Font.GothamBold
keybindLabel.TextSize = 10
keybindLabel.ZIndex = 5
keybindLabel.Parent = keybindFrame

-- Cooldown text (shows remaining seconds when on cooldown)
local cooldownText = Instance.new("TextLabel")
cooldownText.Name = "CooldownText"
cooldownText.Size = UDim2.new(1, 0, 1, 0)
cooldownText.BackgroundTransparency = 1
cooldownText.Text = ""
cooldownText.TextColor3 = CHARGING_COLOR
cooldownText.Font = Enum.Font.GothamBold
cooldownText.TextSize = 16
cooldownText.ZIndex = 4
cooldownText.Visible = false
cooldownText.Parent = container

local function setReady()
	isOnCooldown = false
	
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	-- Fade in icon, hide cooldown text
	TweenService:Create(dashIcon, tweenInfo, {
		ImageColor3 = READY_COLOR,
		ImageTransparency = 0
	}):Play()
	
	TweenService:Create(containerStroke, tweenInfo, {
		Color = READY_COLOR,
		Transparency = 0.2
	}):Play()
	
	TweenService:Create(cooldownOverlay, tweenInfo, {
		Size = UDim2.new(1, 0, 1, 0)
	}):Play()
	
	cooldownText.Visible = false
	
	-- Subtle pulse on ready
	local pulseInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	container.Size = UDim2.new(0, 40, 0, 40)
	TweenService:Create(container, pulseInfo, {
		Size = UDim2.new(0, 44, 0, 44)
	}):Play()
end

local function startCooldown(duration)
	isOnCooldown = true
	cooldownDuration = duration
	cooldownEndTime = tick() + duration
	
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	-- Dim icon, show cooldown state
	TweenService:Create(dashIcon, tweenInfo, {
		ImageColor3 = COOLDOWN_COLOR,
		ImageTransparency = 0.5
	}):Play()
	
	TweenService:Create(containerStroke, tweenInfo, {
		Color = COOLDOWN_COLOR,
		Transparency = 0.6
	}):Play()
	
	-- Reset overlay to empty
	cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
	
	cooldownText.Visible = true
end

-- Listen for dash events from ToolController
local function waitForDashEvent()
	local dashEvent = Player:WaitForChild("DashCooldownEvent", 10)
	if dashEvent then
		dashEvent.Event:Connect(function(duration)
			startCooldown(duration)
		end)
		print("[DashCooldownUI] Connected to DashCooldownEvent")
	else
		warn("[DashCooldownUI] DashCooldownEvent not found")
	end
end

task.spawn(waitForDashEvent)

-- Update loop
RunService.Heartbeat:Connect(function()
	if isOnCooldown then
		local remaining = cooldownEndTime - tick()
		
		if remaining <= 0 then
			setReady()
		else
			-- Update cooldown text
			cooldownText.Text = string.format("%.0f", math.ceil(remaining))
			
			-- Update fill based on progress (fills up as cooldown completes)
			local progress = 1 - (remaining / cooldownDuration)
			cooldownOverlay.Size = UDim2.new(1, 0, progress, 0)
		end
	end
end)

-- Start in ready state
setReady()

print("[DashCooldownUI] Initialized")
