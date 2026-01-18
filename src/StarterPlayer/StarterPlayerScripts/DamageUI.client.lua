--[[
	DamageUI (Client)
	Displays damage numbers and total damage counter
	Place in StarterPlayer.StarterPlayerScripts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DamageRemote = Remotes:WaitForChild("DamageDealt")

-- Get hit VFX
local VFX = ReplicatedStorage:WaitForChild("vfx")
local HitFolder = VFX:WaitForChild("hit")
local NormalHitVFX = HitFolder:WaitForChild("normalhit")

-- Hit sound
local HIT_SOUND_ID = "rbxassetid://72917925606651"
local hitSound = Instance.new("Sound")
hitSound.SoundId = HIT_SOUND_ID
hitSound.Volume = 0.5
hitSound.Name = "HitSound"

-- Configuration
local DAMAGE_RESET_TIME = 3 -- Seconds before counter resets
local FONT_BOLD = Enum.Font.GothamBold
local FONT_MEDIUM = Enum.Font.GothamMedium
local DAMAGE_NUMBER_COLOR = Color3.fromRGB(255, 200, 50) -- Yellow/orange
local CRIT_COLOR = Color3.fromRGB(255, 100, 100) -- Red for big hits
local TOTAL_DAMAGE_COLOR = Color3.fromRGB(255, 170, 50) -- Orange

-- State
local totalDamage = 0
local lastHitTime = 0
local isCounterActive = false

-- Create main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DamageUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- Track damage number offset for stacking
local damageNumberOffset = 0
local lastDamageTime = 0

-- Create BillboardGui template for damage numbers
local function createDamageNumber(damage, worldPosition)
	-- Reset stack if time passed
	local now = tick()
	if now - lastDamageTime > 0.5 then
		damageNumberOffset = 0
	end
	lastDamageTime = now
	damageNumberOffset = damageNumberOffset + 1
	
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "DamageNumber"
	billboardGui.Size = UDim2.new(0, 80, 0, 40)
	billboardGui.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 1.5 + (damageNumberOffset * 0.4), 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 100
	
	-- Create a temporary part at the world position
	local part = Instance.new("Part")
	part.Name = "DamageAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = worldPosition
	part.Parent = workspace
	
	billboardGui.Adornee = part
	billboardGui.Parent = PlayerGui
	
	-- Determine color based on damage (higher = more red)
	local isCrit = damage >= 15
	local textColor = isCrit and CRIT_COLOR or DAMAGE_NUMBER_COLOR
	
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "DamageText"
	damageLabel.Size = UDim2.new(1, 0, 1, 0)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = tostring(damage) .. (isCrit and "!" or "")
	damageLabel.TextColor3 = textColor
	damageLabel.TextStrokeColor3 = Color3.fromRGB(30, 30, 30)
	damageLabel.TextStrokeTransparency = 0
	damageLabel.Font = FONT_BOLD
	damageLabel.TextScaled = true
	damageLabel.Parent = billboardGui
	
	-- Animate: float up and fade out
	local startPos = billboardGui.StudsOffset
	local endPos = startPos + Vector3.new(0, 2, 0)
	
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	local moveTween = TweenService:Create(billboardGui, tweenInfo, {
		StudsOffset = endPos
	})
	
	local fadeTween = TweenService:Create(damageLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	
	-- Pop effect
	billboardGui.Size = UDim2.new(0, 40, 0, 20)
	local popTween = TweenService:Create(billboardGui, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 100, 0, 50)
	})
	
	popTween:Play()
	moveTween:Play()
	task.delay(0.3, function()
		fadeTween:Play()
	end)
	
	-- Cleanup after animation
	task.delay(1, function()
		billboardGui:Destroy()
		part:Destroy()
	end)
end

-- Create total damage counter UI (top-right like screenshot)
local counterFrame = Instance.new("Frame")
counterFrame.Name = "DamageCounter"
counterFrame.Size = UDim2.new(0, 180, 0, 55)
counterFrame.Position = UDim2.new(1, -195, 0, 80)
counterFrame.AnchorPoint = Vector2.new(0, 0)
counterFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
counterFrame.BackgroundTransparency = 0.2
counterFrame.BorderSizePixel = 0
counterFrame.Visible = false
counterFrame.Parent = screenGui

local counterCorner = Instance.new("UICorner")
counterCorner.CornerRadius = UDim.new(0, 6)
counterCorner.Parent = counterFrame

local counterStroke = Instance.new("UIStroke")
counterStroke.Color = Color3.fromRGB(60, 60, 70)
counterStroke.Thickness = 1
counterStroke.Transparency = 0.5
counterStroke.Parent = counterFrame

-- Orange accent circle
local accentCircle = Instance.new("Frame")
accentCircle.Name = "Accent"
accentCircle.Size = UDim2.new(0, 8, 0, 8)
accentCircle.Position = UDim2.new(0, 10, 0, 10)
accentCircle.BackgroundColor3 = TOTAL_DAMAGE_COLOR
accentCircle.BorderSizePixel = 0
accentCircle.Parent = counterFrame

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accentCircle

local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "CounterText"
counterLabel.Size = UDim2.new(1, -25, 0, 16)
counterLabel.Position = UDim2.new(0, 22, 0, 6)
counterLabel.BackgroundTransparency = 1
counterLabel.Text = "TOTAL DAMAGE"
counterLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.Font = FONT_MEDIUM
counterLabel.TextSize = 11
counterLabel.Parent = counterFrame

local damageValue = Instance.new("TextLabel")
damageValue.Name = "DamageValue"
damageValue.Size = UDim2.new(1, -15, 0, 30)
damageValue.Position = UDim2.new(0, 10, 0, 22)
damageValue.BackgroundTransparency = 1
damageValue.Text = "0"
damageValue.TextColor3 = TOTAL_DAMAGE_COLOR
damageValue.TextXAlignment = Enum.TextXAlignment.Right
damageValue.Font = FONT_BOLD
damageValue.TextSize = 32
damageValue.Parent = counterFrame

local function showCounter()
	if not isCounterActive then
		isCounterActive = true
		counterFrame.Visible = true
		counterFrame.BackgroundTransparency = 0.2
		damageValue.TextTransparency = 0
		counterLabel.TextTransparency = 0
		accentCircle.BackgroundTransparency = 0
	end
end

local function hideCounter()
	if isCounterActive then
		isCounterActive = false
		
		local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
		local fadeTween = TweenService:Create(counterFrame, fadeInfo, {
			BackgroundTransparency = 1
		})
		local textFade = TweenService:Create(damageValue, fadeInfo, {
			TextTransparency = 1
		})
		local labelFade = TweenService:Create(counterLabel, fadeInfo, {
			TextTransparency = 1
		})
		local accentFade = TweenService:Create(accentCircle, fadeInfo, {
			BackgroundTransparency = 1
		})
		
		fadeTween:Play()
		textFade:Play()
		labelFade:Play()
		accentFade:Play()
		
		fadeTween.Completed:Connect(function()
			if not isCounterActive then
				counterFrame.Visible = false
				totalDamage = 0
				damageValue.Text = "0"
			end
		end)
	end
end

local function updateCounter(damage)
	totalDamage = totalDamage + damage
	lastHitTime = tick()
	
	showCounter()
	damageValue.Text = tostring(totalDamage)
	
	-- Pulse effect on damage
	local originalSize = counterFrame.Size
	counterFrame.Size = UDim2.new(0, 220, 0, 66)
	
	local pulseTween = TweenService:Create(counterFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = originalSize
	})
	pulseTween:Play()
end

-- Play hit sound at position
local function playHitSound(worldPosition)
	local soundClone = hitSound:Clone()
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = worldPosition
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace
	
	soundClone.Parent = part
	soundClone:Play()
	
	soundClone.Ended:Once(function()
		part:Destroy()
	end)
end

-- Spawn hit VFX at position (plays once, no looping)
local function spawnHitVFX(worldPosition, customVfxPath)
	-- Create attachment at hit position
	local part = Instance.new("Part")
	part.Name = "HitVFXAnchor"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = worldPosition
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace
	
	-- Get VFX to use (custom path or default)
	local vfxSource = NormalHitVFX
	if customVfxPath then
		-- Navigate to custom VFX (supports paths like "skills/thrust-hit")
		local customVfx = VFX
		for pathPart in string.gmatch(customVfxPath, "[^/]+") do
			customVfx = customVfx:FindFirstChild(pathPart)
			if not customVfx then break end
		end
		if customVfx then
			vfxSource = customVfx
		end
	end
	
	-- Clone and parent the VFX
	local vfxClone = vfxSource:Clone()
	vfxClone.Parent = part
	
	-- Emit particles once (disable looping)
	if vfxClone:IsA("ParticleEmitter") then
		vfxClone.Enabled = false -- Disable looping
		local emitCount = vfxClone:GetAttribute("EmitCount") or 15
		vfxClone:Emit(math.max(1, math.floor(emitCount * 0.1)))
	else
		-- If it's a folder/model with multiple emitters
		for _, child in pairs(vfxClone:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false -- Disable looping
				local emitCount = child:GetAttribute("EmitCount") or 10
				child:Emit(math.max(1, math.floor(emitCount * 0.1)))
			end
		end
	end
	
	-- Cleanup after particles fade
	task.delay(2, function()
		part:Destroy()
	end)
end

-- Listen for damage events
DamageRemote.OnClientEvent:Connect(function(damage, worldPosition, targetName, skillVfxPath)
	-- Show damage number at hit position
	createDamageNumber(damage, worldPosition)
	
	-- Spawn hit VFX and sound (use custom VFX if provided)
	spawnHitVFX(worldPosition, skillVfxPath)
	playHitSound(worldPosition)
	
	-- Update total counter
	updateCounter(damage)
	
	print(string.format("[DamageUI] Hit %s for %d damage (Total: %d)", targetName, damage, totalDamage))
end)

-- Check for counter timeout
RunService.Heartbeat:Connect(function()
	if isCounterActive and (tick() - lastHitTime) >= DAMAGE_RESET_TIME then
		hideCounter()
	end
end)

print("[DamageUI] Initialized")
