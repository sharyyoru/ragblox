--[[
	GameLoader - Animated loading screen with asset preloading
	Ensures all animations and assets are loaded before gameplay
	Place in StarterPlayerScripts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
	MinLoadTime = 2, -- Minimum time to show loader (seconds)
	FadeOutTime = 0.8, -- Time to fade out loader
	
	-- Colors
	BackgroundColor = Color3.fromRGB(15, 15, 25),
	AccentColor = Color3.fromRGB(100, 180, 255),
	SecondaryColor = Color3.fromRGB(60, 120, 200),
	TextColor = Color3.fromRGB(255, 255, 255),
	SubTextColor = Color3.fromRGB(180, 180, 200),
}

-- Assets to preload
local ASSETS_TO_PRELOAD = {
	-- Animations (from WeaponRegistry and SkillRegistry)
	"rbxassetid://85712461062430", -- 1h Idle
	"rbxassetid://99797485122785", -- Sprint
	"rbxassetid://129967070737741", -- 2h Idle
	"rbxassetid://93246963192636", -- Bash
	"rbxassetid://83432713663049", -- Sweep
	"rbxassetid://76362379318834", -- Thrust
	"rbxassetid://72058025234006", -- Slam
	"rbxassetid://109953464351381", -- Whirlwind
	"rbxassetid://74241316366088", -- Equip
	"rbxassetid://87044822854350", -- Dash
	
	-- Sounds
	"rbxassetid://78344477605037", -- Swing
	"rbxassetid://92335651352179", -- Equip
	"rbxassetid://82748103106614", -- Dash
}

-- Create the loading screen UI
local function createLoaderUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameLoader"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 999
	screenGui.ResetOnSpawn = false
	screenGui.Parent = PlayerGui
	
	-- Main background
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = CONFIG.BackgroundColor
	background.BorderSizePixel = 0
	background.Parent = screenGui
	
	-- Animated gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 35)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 30, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25)),
	})
	gradient.Rotation = 45
	gradient.Parent = background
	
	-- Center container
	local centerContainer = Instance.new("Frame")
	centerContainer.Name = "CenterContainer"
	centerContainer.Size = UDim2.new(0, 400, 0, 300)
	centerContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	centerContainer.BackgroundTransparency = 1
	centerContainer.Parent = background
	
	-- Game title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "RAGBLOX"
	title.TextSize = 48
	title.TextColor3 = CONFIG.TextColor
	title.Parent = centerContainer
	
	-- Animated spinner container
	local spinnerContainer = Instance.new("Frame")
	spinnerContainer.Name = "SpinnerContainer"
	spinnerContainer.Size = UDim2.new(0, 80, 0, 80)
	spinnerContainer.Position = UDim2.new(0.5, 0, 0.5, -20)
	spinnerContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	spinnerContainer.BackgroundTransparency = 1
	spinnerContainer.Parent = centerContainer
	
	-- Create spinning rings
	for i = 1, 3 do
		local ring = Instance.new("Frame")
		ring.Name = "Ring" .. i
		ring.Size = UDim2.new(0, 60 + (i * 10), 0, 60 + (i * 10))
		ring.Position = UDim2.new(0.5, 0, 0.5, 0)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.BackgroundTransparency = 1
		ring.Parent = spinnerContainer
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ring
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = i == 1 and CONFIG.AccentColor or CONFIG.SecondaryColor
		stroke.Thickness = 3
		stroke.Transparency = 0.3 + (i * 0.15)
		stroke.Parent = ring
	end
	
	-- Center dot (pulsing)
	local centerDot = Instance.new("Frame")
	centerDot.Name = "CenterDot"
	centerDot.Size = UDim2.new(0, 16, 0, 16)
	centerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	centerDot.BackgroundColor3 = CONFIG.AccentColor
	centerDot.Parent = spinnerContainer
	
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = centerDot
	
	-- Progress bar container
	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressContainer"
	progressContainer.Size = UDim2.new(0.8, 0, 0, 8)
	progressContainer.Position = UDim2.new(0.5, 0, 0.75, 0)
	progressContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	progressContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	progressContainer.Parent = centerContainer
	
	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(1, 0)
	progressCorner.Parent = progressContainer
	
	-- Progress bar fill
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = CONFIG.AccentColor
	progressFill.Parent = progressContainer
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = progressFill
	
	-- Progress glow effect
	local progressGlow = Instance.new("UIGradient")
	progressGlow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 160, 255)),
	})
	progressGlow.Parent = progressFill
	
	-- Loading text
	local loadingText = Instance.new("TextLabel")
	loadingText.Name = "LoadingText"
	loadingText.Size = UDim2.new(1, 0, 0, 30)
	loadingText.Position = UDim2.new(0, 0, 0.85, 0)
	loadingText.BackgroundTransparency = 1
	loadingText.Font = Enum.Font.Gotham
	loadingText.Text = "Loading..."
	loadingText.TextSize = 18
	loadingText.TextColor3 = CONFIG.SubTextColor
	loadingText.Parent = centerContainer
	
	-- Percentage text
	local percentText = Instance.new("TextLabel")
	percentText.Name = "PercentText"
	percentText.Size = UDim2.new(1, 0, 0, 25)
	percentText.Position = UDim2.new(0, 0, 0.92, 0)
	percentText.BackgroundTransparency = 1
	percentText.Font = Enum.Font.GothamBold
	percentText.Text = "0%"
	percentText.TextSize = 22
	percentText.TextColor3 = CONFIG.AccentColor
	percentText.Parent = centerContainer
	
	-- Floating particles container
	local particlesContainer = Instance.new("Frame")
	particlesContainer.Name = "ParticlesContainer"
	particlesContainer.Size = UDim2.new(1, 0, 1, 0)
	particlesContainer.BackgroundTransparency = 1
	particlesContainer.ClipsDescendants = true
	particlesContainer.Parent = background
	
	-- Create floating particles
	for i = 1, 20 do
		local particle = Instance.new("Frame")
		particle.Name = "Particle" .. i
		particle.Size = UDim2.new(0, math.random(4, 12), 0, math.random(4, 12))
		particle.Position = UDim2.new(math.random() * 0.9 + 0.05, 0, math.random() * 0.9 + 0.05, 0)
		particle.BackgroundColor3 = CONFIG.AccentColor
		particle.BackgroundTransparency = 0.7 + math.random() * 0.2
		particle.Parent = particlesContainer
		
		local pCorner = Instance.new("UICorner")
		pCorner.CornerRadius = UDim.new(1, 0)
		pCorner.Parent = particle
	end
	
	return screenGui
end

-- Animate the loader
local function animateLoader(screenGui)
	local background = screenGui:FindFirstChild("Background")
	local spinnerContainer = background.CenterContainer.SpinnerContainer
	local particlesContainer = background.ParticlesContainer
	
	-- Spin the rings
	local ringAngles = {0, 0, 0}
	local ringSpeeds = {1.5, -1.2, 0.8}
	
	local spinConnection = RunService.Heartbeat:Connect(function(dt)
		for i = 1, 3 do
			local ring = spinnerContainer:FindFirstChild("Ring" .. i)
			if ring then
				ringAngles[i] = ringAngles[i] + (ringSpeeds[i] * dt * 60)
				ring.Rotation = ringAngles[i]
			end
		end
		
		-- Pulse center dot
		local centerDot = spinnerContainer:FindFirstChild("CenterDot")
		if centerDot then
			local scale = 1 + math.sin(tick() * 3) * 0.2
			centerDot.Size = UDim2.new(0, 16 * scale, 0, 16 * scale)
		end
		
		-- Animate particles
		for _, particle in pairs(particlesContainer:GetChildren()) do
			if particle:IsA("Frame") then
				local currentY = particle.Position.Y.Scale
				local newY = currentY - dt * 0.05
				if newY < -0.1 then
					newY = 1.1
					particle.Position = UDim2.new(math.random() * 0.9 + 0.05, 0, newY, 0)
				else
					particle.Position = UDim2.new(particle.Position.X.Scale, 0, newY, 0)
				end
			end
		end
	end)
	
	return spinConnection
end

-- Update progress
local function updateProgress(screenGui, progress, statusText)
	local background = screenGui:FindFirstChild("Background")
	if not background then return end
	
	local progressFill = background.CenterContainer.ProgressContainer.ProgressFill
	local loadingText = background.CenterContainer.LoadingText
	local percentText = background.CenterContainer.PercentText
	
	-- Animate progress bar
	local tween = TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.new(progress, 0, 1, 0)
	})
	tween:Play()
	
	-- Update text
	percentText.Text = math.floor(progress * 100) .. "%"
	if statusText then
		loadingText.Text = statusText
	end
end

-- Fade out loader
local function fadeOutLoader(screenGui)
	local background = screenGui:FindFirstChild("Background")
	if not background then return end
	
	-- Fade all elements
	local tweenInfo = TweenInfo.new(CONFIG.FadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	local fadeTween = TweenService:Create(background, tweenInfo, {
		BackgroundTransparency = 1
	})
	
	-- Fade text and elements
	for _, desc in pairs(background:GetDescendants()) do
		if desc:IsA("TextLabel") then
			TweenService:Create(desc, tweenInfo, {TextTransparency = 1}):Play()
		elseif desc:IsA("Frame") then
			TweenService:Create(desc, tweenInfo, {BackgroundTransparency = 1}):Play()
		elseif desc:IsA("UIStroke") then
			TweenService:Create(desc, tweenInfo, {Transparency = 1}):Play()
		end
	end
	
	fadeTween:Play()
	fadeTween.Completed:Wait()
	
	screenGui:Destroy()
end

-- Main loading function
local function startLoading()
	-- Create and show loader
	local screenGui = createLoaderUI()
	local animConnection = animateLoader(screenGui)
	
	local startTime = tick()
	local totalAssets = #ASSETS_TO_PRELOAD
	local loadedCount = 0
	
	updateProgress(screenGui, 0, "Initializing...")
	task.wait(0.5)
	
	-- Preload assets
	updateProgress(screenGui, 0.1, "Loading assets...")
	
	for i, assetId in ipairs(ASSETS_TO_PRELOAD) do
		local success, err = pcall(function()
			ContentProvider:PreloadAsync({assetId})
		end)
		
		loadedCount = loadedCount + 1
		local progress = 0.1 + (loadedCount / totalAssets) * 0.6
		updateProgress(screenGui, progress, "Loading assets... (" .. loadedCount .. "/" .. totalAssets .. ")")
		
		-- Small delay between assets
		task.wait(0.05)
	end
	
	-- Wait for character
	updateProgress(screenGui, 0.75, "Waiting for character...")
	
	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	
	updateProgress(screenGui, 0.85, "Loading modules...")
	task.wait(0.3)
	
	-- Wait for modules to be ready
	local Modules = ReplicatedStorage:WaitForChild("Modules")
	Modules:WaitForChild("WeaponRegistry")
	Modules:WaitForChild("SkillRegistry")
	Modules:WaitForChild("AnimationLoader")
	Modules:WaitForChild("CombatHandler")
	
	updateProgress(screenGui, 0.95, "Almost ready...")
	
	-- Ensure minimum load time for smooth experience
	local elapsed = tick() - startTime
	if elapsed < CONFIG.MinLoadTime then
		task.wait(CONFIG.MinLoadTime - elapsed)
	end
	
	updateProgress(screenGui, 1, "Ready!")
	task.wait(0.5)
	
	-- Stop animations and fade out
	animConnection:Disconnect()
	fadeOutLoader(screenGui)
	
	print("[GameLoader] Loading complete!")
end

-- Start loading immediately
startLoading()
