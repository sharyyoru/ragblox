--[[
	CharacterAnimations (Client)
	Handles default character animations when no weapon is equipped
	- Idle animation plays when standing still (no weapon)
	- Run animation plays ONLY when shift is held (no weapon)
	- Default walk is preserved (Roblox default)
	Place in StarterPlayer.StarterPlayerScripts
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- Animation IDs
local DEFAULT_IDLE_ID = "rbxassetid://97439805068239"
local DEFAULT_WALK_ID = "rbxassetid://131925541863427"
local DEFAULT_RUN_ID = "rbxassetid://93332996113779"

-- Speed constants
local WALK_SPEED = 16
local RUN_SPEED = 24

-- State
local Character = nil
local Humanoid = nil
local Animator = nil
local idleTrack = nil
local walkTrack = nil
local runTrack = nil
local isWalking = false
local isSprinting = false
local hasWeaponEquipped = false

local function setupAnimations()
	if not Character or not Humanoid then return end
	
	Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end
	
	-- Create idle animation
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = DEFAULT_IDLE_ID
	idleTrack = Animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack.Looped = true
	
	-- Create walk animation
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = DEFAULT_WALK_ID
	walkTrack = Animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	walkTrack.Looped = true
	
	-- Create run/sprint animation (only plays with shift held)
	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = DEFAULT_RUN_ID
	runTrack = Animator:LoadAnimation(runAnim)
	runTrack.Priority = Enum.AnimationPriority.Action
	runTrack.Looped = true
	
	-- Start idle if no weapon
	if not hasWeaponEquipped then
		idleTrack:Play(0.2)
	end
	
	print("[CharacterAnimations] Default animations loaded")
end

local function onToolEquipped(tool)
	hasWeaponEquipped = true
	isSprinting = false
	isWalking = false
	
	-- Stop default animations
	if idleTrack and idleTrack.IsPlaying then
		idleTrack:Stop(0.2)
	end
	if walkTrack and walkTrack.IsPlaying then
		walkTrack:Stop(0.2)
	end
	if runTrack and runTrack.IsPlaying then
		runTrack:Stop(0.2)
	end
	
	-- Reset speed
	if Humanoid then
		Humanoid.WalkSpeed = WALK_SPEED
	end
end

local function onToolUnequipped(tool)
	-- Check if any tool is still equipped
	if Character then
		local equippedTool = Character:FindFirstChildOfClass("Tool")
		if not equippedTool then
			hasWeaponEquipped = false
			isSprinting = false
			isWalking = false
			
			-- Resume idle animation
			if idleTrack then
				idleTrack:Play(0.2)
			end
			
			-- Reset speed
			if Humanoid then
				Humanoid.WalkSpeed = WALK_SPEED
			end
		end
	end
end

local function updateMovement()
	if hasWeaponEquipped or not Humanoid or not idleTrack or not walkTrack or not runTrack then return end
	
	local moveDirection = Humanoid.MoveDirection
	local isMoving = moveDirection.Magnitude > 0.1
	local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	
	-- Sprint only when moving AND shift is held
	local shouldSprint = isMoving and shiftHeld
	local shouldWalk = isMoving and not shiftHeld
	
	if shouldSprint and not isSprinting then
		-- Start sprinting
		isSprinting = true
		isWalking = false
		Humanoid.WalkSpeed = RUN_SPEED
		idleTrack:Stop(0.2)
		walkTrack:Stop(0.2)
		runTrack:Play(0.2)
	elseif shouldWalk and not isWalking then
		-- Start walking
		isWalking = true
		isSprinting = false
		Humanoid.WalkSpeed = WALK_SPEED
		idleTrack:Stop(0.2)
		runTrack:Stop(0.2)
		walkTrack:Play(0.2)
	elseif not isMoving and (isWalking or isSprinting) then
		-- Stop moving - return to idle
		isWalking = false
		isSprinting = false
		Humanoid.WalkSpeed = WALK_SPEED
		walkTrack:Stop(0.2)
		runTrack:Stop(0.2)
		idleTrack:Play(0.2)
	elseif not isMoving and not isWalking and not isSprinting then
		-- Ensure idle plays when standing still
		if not idleTrack.IsPlaying then
			idleTrack:Play(0.2)
		end
	end
end

local function onCharacterAdded(character)
	Character = character
	Humanoid = character:WaitForChild("Humanoid")
	hasWeaponEquipped = false
	isSprinting = false
	isWalking = false
	
	-- Wait for animator to be ready
	task.wait(0.1)
	setupAnimations()
	
	-- Listen for tool equip/unequip
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end)
	
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			onToolUnequipped(child)
		end
	end)
	
	-- Check if already has a tool
	local existingTool = character:FindFirstChildOfClass("Tool")
	if existingTool then
		onToolEquipped(existingTool)
	end
end

-- Initialize
if Player.Character then
	onCharacterAdded(Player.Character)
end
Player.CharacterAdded:Connect(onCharacterAdded)

-- Update loop for movement detection
RunService.Heartbeat:Connect(updateMovement)

print("[CharacterAnimations] Initialized")
