--[[
	ToolController (Client)
	Handles tool equip/unequip, animations, and input for combat
	Place in StarterPlayer.StarterPlayerScripts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

print("[ToolController] Starting...")

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationLoader = require(Modules:WaitForChild("AnimationLoader"))
local CombatHandler = require(Modules:WaitForChild("CombatHandler"))
local WeaponRegistry = require(Modules:WaitForChild("WeaponRegistry"))

print("[ToolController] Modules loaded")

-- Remote events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRemote = Remotes:WaitForChild("Attack")

print("[ToolController] Remotes loaded")

-- State
local Character = nil
local Humanoid = nil
local currentTool = nil
local animLoader = nil
local combatHandler = nil
local isSprinting = false
local isEquipped = false
local currentWeaponStyle = "1h"

-- Constants
local SPRINT_SPEED = 24
local WALK_SPEED = 16
local SWING_SOUND_ID = "rbxassetid://78344477605037"
local EQUIP_SOUND_ID = "rbxassetid://92335651352179"
local DASH_SOUND_ID = "rbxassetid://82748103106614"
local EQUIP_ANIM_ID = "rbxassetid://74241316366088"
local DASH_ANIM_ID = "rbxassetid://87044822854350"
local DASH_COOLDOWN = 5
local DASH_FORCE = 80
local DASH_DURATION = 0.3

-- Create swing sound
local swingSound = Instance.new("Sound")
swingSound.SoundId = SWING_SOUND_ID
swingSound.Volume = 0.5
swingSound.Name = "SwingSound"

-- Create equip sound
local equipSound = Instance.new("Sound")
equipSound.SoundId = EQUIP_SOUND_ID
equipSound.Volume = 0.4
equipSound.Name = "EquipSound"

-- Create dash sound
local dashSound = Instance.new("Sound")
dashSound.SoundId = DASH_SOUND_ID
dashSound.Volume = 0.5
dashSound.Name = "DashSound"

-- Dash state
local isDashing = false
local lastDashTime = 0
local equipTrack = nil
local dashTrack = nil
local globalDashTrack = nil -- For dash without weapon

-- Create DashRemote for cooldown sync
local DashRemote = Remotes:FindFirstChild("Dash")
if not DashRemote then
	-- Will be created by server, wait for it or create locally for UI
end

local function getWeaponStyle(tool)
	-- Get weapon style from folder structure via WeaponRegistry
	local weaponId = tool:GetAttribute("WeaponId") or tool.Name
	return WeaponRegistry.GetWeaponStyle(weaponId)
end

local function getWeaponId(tool)
	-- Get weapon ID for WeaponRegistry lookup
	return tool:GetAttribute("WeaponId") or tool.Name
end

local function onToolEquipped(tool)
	-- Prevent duplicate equips
	if currentTool == tool and isEquipped then
		print("[ToolController] Tool already equipped, skipping: " .. tool.Name)
		return
	end
	
	print("[ToolController] Tool equipped: " .. tool.Name)
	
	if not Character or not Humanoid then
		Character = Player.Character
		Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			warn("[ToolController] No humanoid found!")
			return
		end
	end
	
	-- Clean up previous tool if any
	if animLoader then
		animLoader:Destroy()
		animLoader = nil
	end
	if combatHandler then
		combatHandler:Destroy()
		combatHandler = nil
	end
	
	currentTool = tool
	isEquipped = true
	
	currentWeaponStyle = getWeaponStyle(tool)
	print("[ToolController] Weapon style: " .. currentWeaponStyle)
	
	-- Create animation loader for this weapon style
	animLoader = AnimationLoader.new(Character, currentWeaponStyle)
	local success = animLoader:LoadAnimations()
	
	print("[ToolController] LoadAnimations success: " .. tostring(success))
	
	if success then
		-- Create combat handler with weapon ID for WeaponRegistry lookup
		local weaponId = getWeaponId(tool)
		print("[ToolController] Weapon ID: " .. weaponId)
		combatHandler = CombatHandler.new(animLoader, weaponId)
		
		-- Load and play equip animation
		local Animator = Humanoid:FindFirstChildOfClass("Animator")
		if Animator then
			local equipAnim = Instance.new("Animation")
			equipAnim.AnimationId = EQUIP_ANIM_ID
			equipTrack = Animator:LoadAnimation(equipAnim)
			equipTrack.Priority = Enum.AnimationPriority.Action
			equipTrack:Play(0.1)
			
			-- Play equip sound
			equipSound.Parent = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
			equipSound:Play()
			
			print("[ToolController] Playing equip animation")
			
			-- Load dash animation
			local dashAnim = Instance.new("Animation")
			dashAnim.AnimationId = DASH_ANIM_ID
			dashTrack = Animator:LoadAnimation(dashAnim)
			dashTrack.Priority = Enum.AnimationPriority.Action4
			
			-- Wait for equip animation then play idle
			equipTrack.Stopped:Once(function()
				if isEquipped then
					animLoader:PlayAnimation("Idle", 0.2)
				end
			end)
		else
			-- No animator, just play idle
			animLoader:PlayAnimation("Idle", 0.2)
		end
		
		print("[ToolController] Tool setup complete")
	else
		warn("[ToolController] Failed to load animations for weapon style: " .. weaponStyle)
	end
end

local function onToolUnequipped(tool)
	print("[ToolController] Tool unequipped: " .. tool.Name)
	
	if tool == currentTool then
		isEquipped = false
		isSprinting = false
		
		if Humanoid then
			Humanoid.WalkSpeed = WALK_SPEED
		end
		
		if combatHandler then
			combatHandler:Destroy()
			combatHandler = nil
		end
		
		if animLoader then
			animLoader:Destroy()
			animLoader = nil
		end
		
		currentTool = nil
	end
end

local function handleAttack()
	if not isEquipped or not combatHandler then 
		print("[ToolController] Attack blocked - isEquipped: " .. tostring(isEquipped) .. ", combatHandler: " .. tostring(combatHandler ~= nil))
		return 
	end
	
	if isDashing then return end -- Can't attack while dashing
	
	print("[ToolController] Attacking...")
	local success, skillName, animName = combatHandler:Attack()
	print("[ToolController] Attack result - success: " .. tostring(success) .. ", skill: " .. tostring(skillName))
	
	if success then
		-- Get hit timing for this attack to sync sound with animation
		local hitTiming = WeaponRegistry.GetHitTiming(currentWeaponStyle, skillName)
		
		-- Delay sound and hit detection to match animation timing
		task.delay(hitTiming, function()
			-- Play swing sound at the moment of impact
			if Character then
				swingSound.Parent = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
				swingSound:Play()
			end
			
			-- Fire to server for hit detection at the moment of impact
			AttackRemote:FireServer(skillName)
		end)
	end
end

-- Bindable event for dash cooldown UI updates
local DashCooldownEvent = Instance.new("BindableEvent")
DashCooldownEvent.Name = "DashCooldownEvent"
DashCooldownEvent.Parent = Player

local function handleDash()
	-- Allow dash with or without weapon equipped
	if not Character or not Humanoid then return end
	if isDashing then return end
	
	-- Check cooldown
	local currentTime = tick()
	local timeSinceLastDash = currentTime - lastDashTime
	
	if timeSinceLastDash < DASH_COOLDOWN then
		print("[ToolController] Dash on cooldown: " .. string.format("%.1f", DASH_COOLDOWN - timeSinceLastDash) .. "s remaining")
		return
	end
	
	-- Start dash
	isDashing = true
	lastDashTime = currentTime
	
	print("[ToolController] Dashing!")
	
	-- Fire cooldown event for UI
	DashCooldownEvent:Fire(DASH_COOLDOWN)
	
	-- Play dash sound
	local hrp = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
	if hrp then
		dashSound.Parent = hrp
		dashSound:Play()
	end
	
	-- Play dash animation (use weapon dash track or load global one)
	local trackToUse = dashTrack
	if not trackToUse then
		-- Load global dash animation if no weapon equipped
		local Animator = Humanoid:FindFirstChildOfClass("Animator")
		if Animator and not globalDashTrack then
			local dashAnim = Instance.new("Animation")
			dashAnim.AnimationId = DASH_ANIM_ID
			globalDashTrack = Animator:LoadAnimation(dashAnim)
			globalDashTrack.Priority = Enum.AnimationPriority.Action4
		end
		trackToUse = globalDashTrack
	end
	
	if trackToUse then
		trackToUse:Play(0.1)
	end
	
	-- Apply dash force
	local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		-- Get dash direction (forward or movement direction)
		local moveDir = Humanoid.MoveDirection
		local dashDirection = moveDir.Magnitude > 0.1 and moveDir.Unit or humanoidRootPart.CFrame.LookVector
		
		-- Create body velocity for dash
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
		bodyVelocity.Velocity = dashDirection * DASH_FORCE
		bodyVelocity.Parent = humanoidRootPart
		
		-- Remove after dash duration and stop animation
		task.delay(DASH_DURATION, function()
			bodyVelocity:Destroy()
			isDashing = false
			if trackToUse then
				trackToUse:Stop(0.2)
			end
		end)
	else
		isDashing = false
	end
end

local function updateSprint()
	if not isEquipped or not animLoader or not combatHandler or not Humanoid then return end
	
	local moveDirection = Humanoid.MoveDirection
	local isMoving = moveDirection.Magnitude > 0.1
	local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	
	local shouldSprint = isMoving and shiftHeld and not combatHandler:IsCurrentlyAttacking()
	
	if shouldSprint and not isSprinting then
		-- Start sprinting
		isSprinting = true
		Humanoid.WalkSpeed = SPRINT_SPEED
		animLoader:StopAnimation("Idle", 0.2)
		animLoader:PlayAnimation("Sprint", 0.2)
	elseif not shouldSprint and isSprinting then
		-- Stop sprinting
		isSprinting = false
		Humanoid.WalkSpeed = WALK_SPEED
		animLoader:StopAnimation("Sprint", 0.2)
		if not combatHandler:IsCurrentlyAttacking() then
			animLoader:PlayAnimation("Idle", 0.2)
		end
	elseif not isMoving and not isSprinting and not combatHandler:IsCurrentlyAttacking() then
		-- Ensure idle is playing when stationary
		local idleTrack = animLoader:GetTrack("Idle")
		if idleTrack and not idleTrack.IsPlaying then
			animLoader:PlayAnimation("Idle", 0.2)
		end
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Left mouse button for attack
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handleAttack()
	end
	
	-- Q key for dash
	if input.KeyCode == Enum.KeyCode.Q then
		handleDash()
	end
end)

-- Tool connection handler
local function connectTool(tool)
	print("[ToolController] Connecting tool: " .. tool.Name)
	
	tool.Equipped:Connect(function()
		onToolEquipped(tool)
	end)
	
	tool.Unequipped:Connect(function()
		onToolUnequipped(tool)
	end)
end

-- Backpack setup to monitor tools
local function setupBackpack()
	local Backpack = Player:WaitForChild("Backpack")
	
	-- Connect existing tools in backpack
	for _, tool in ipairs(Backpack:GetChildren()) do
		if tool:IsA("Tool") then
			connectTool(tool)
		end
	end
	
	-- Connect new tools added to backpack
	Backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			connectTool(child)
		end
	end)
end

-- Character setup
local function setupCharacter(char)
	print("[ToolController] Character setup: " .. char.Name)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	
	-- Check for already equipped tool in character
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			connectTool(child)
			-- If tool is already in character, it's equipped
			onToolEquipped(child)
			break
		end
	end
	
	-- Also watch for tools added directly to character
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			connectTool(child)
		end
	end)
	
	-- Setup backpack monitoring
	setupBackpack()
end

-- Initial setup
local char = Player.Character or Player.CharacterAdded:Wait()
setupCharacter(char)
Player.CharacterAdded:Connect(setupCharacter)

-- Sprint update loop
RunService.Heartbeat:Connect(updateSprint)

print("[ToolController] Initialized")
