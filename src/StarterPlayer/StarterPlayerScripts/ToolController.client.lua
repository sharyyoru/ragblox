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
local SkillHandler = require(Modules:WaitForChild("SkillHandler"))
local SkillRegistry = require(Modules:WaitForChild("SkillRegistry"))

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
local skillHandler = nil
local isSprinting = false
local isEquipped = false
local isUsingSkill = false
local currentWeaponStyle = "1h"
local currentWeaponName = nil

-- Channeled skill state
local channeledSkillActive = false
local channeledSlotKey = nil
local channeledSkillInfo = nil
local channeledTrack = nil
local channeledStartTime = 0
local channeledDamageThread = nil

-- Skill key mappings
local SKILL_KEYS = {
	[Enum.KeyCode.Z] = "Z",
	[Enum.KeyCode.X] = "X",
	[Enum.KeyCode.C] = "C",
	[Enum.KeyCode.V] = "V",
	[Enum.KeyCode.F] = "F",
}

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

-- Helper function to play a sound at a position (creates a temporary clone)
local function playSound(soundId, volume, parent)
	if not parent then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

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
	currentWeaponName = getWeaponId(tool)
	print("[ToolController] Weapon style: " .. currentWeaponStyle)
	
	-- Initialize skill handler for this weapon
	skillHandler = SkillHandler.new()
	skillHandler:SetWeapon(currentWeaponName)
	
	-- Setup skill cooldown callback for UI
	skillHandler.OnCooldownStart = function(slotKey, duration, skillName)
		local cooldownEvent = Player:FindFirstChild("SkillCooldownEvent")
		if cooldownEvent then
			cooldownEvent:Fire(slotKey, duration)
		end
	end
	
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
			local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
			playSound(EQUIP_SOUND_ID, 0.4, rootPart)
			
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
		isUsingSkill = false
		
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
		
		-- Clean up skill handler
		skillHandler = nil
		currentWeaponName = nil
		
		currentTool = nil
	end
end

-- Apply skill dash (for Thrust-like skills)
local function applySkillDash(skillInfo)
	if not skillInfo.DashForward or skillInfo.DashForward <= 0 then return end
	if not Character then return end
	
	local hrp = Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local dashDistance = skillInfo.DashForward
	local dashDuration = skillInfo.DashDuration or 0.15
	
	-- Create trail effect if enabled
	local trail = nil
	if skillInfo.LeaveTrail then
		-- Try to find existing trail on weapon or create one
		local tool = Character:FindFirstChildOfClass("Tool")
		if tool then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				-- Create temporary trail
				local attachment0 = Instance.new("Attachment")
				attachment0.Position = Vector3.new(0, 0, -1)
				attachment0.Parent = handle
				
				local attachment1 = Instance.new("Attachment")
				attachment1.Position = Vector3.new(0, 0, 1)
				attachment1.Parent = handle
				
				trail = Instance.new("Trail")
				trail.Attachment0 = attachment0
				trail.Attachment1 = attachment1
				trail.Lifetime = 0.3
				trail.MinLength = 0.1
				trail.FaceCamera = true
				trail.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
				trail.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.3),
					NumberSequenceKeypoint.new(1, 1),
				})
				trail.WidthScale = NumberSequence.new(1)
				trail.Parent = handle
			end
		end
	end
	
	-- Apply dash using BodyVelocity
	local dashDirection = hrp.CFrame.LookVector
	local dashVelocity = (dashDistance / dashDuration)
	
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
	bodyVelocity.Velocity = dashDirection * dashVelocity
	bodyVelocity.Parent = hrp
	
	-- Clean up after dash
	task.delay(dashDuration, function()
		bodyVelocity:Destroy()
		
		-- Remove trail after a short delay
		if trail then
			task.delay(0.3, function()
				if trail.Parent then
					trail.Attachment0:Destroy()
					trail.Attachment1:Destroy()
					trail:Destroy()
				end
			end)
		end
	end)
end

-- Play hit VFX for skills
local function playSkillHitVFX(skillInfo, hitPosition)
	if not skillInfo.VFX or not skillInfo.VFX.OnHit then return end
	
	local vfxPath = skillInfo.VFX.OnHit
	local vfxFolder = ReplicatedStorage:FindFirstChild("vfx")
	if not vfxFolder then return end
	
	-- Navigate to VFX (supports paths like "skills/thrust-hit")
	local vfx = vfxFolder
	for part in string.gmatch(vfxPath, "[^/]+") do
		vfx = vfx:FindFirstChild(part)
		if not vfx then return end
	end
	
	-- Clone and position VFX
	local vfxClone = vfx:Clone()
	
	-- Create anchor part at hit position
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = hitPosition
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace
	
	vfxClone.Parent = anchor
	
	-- Emit particles
	if vfxClone:IsA("ParticleEmitter") then
		vfxClone.Enabled = false
		vfxClone:Emit(vfxClone:GetAttribute("EmitCount") or 15)
	else
		for _, child in pairs(vfxClone:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
				child:Emit(child:GetAttribute("EmitCount") or 10)
			end
		end
	end
	
	-- Cleanup
	task.delay(2, function()
		anchor:Destroy()
	end)
end

-- Stop channeled skill
local function stopChanneledSkill()
	if not channeledSkillActive then return end
	
	print("[ToolController] Stopping channeled skill: " .. (channeledSkillInfo and channeledSkillInfo.DisplayName or "Unknown"))
	
	-- Set flag to stop the damage loop (flag-based cancellation)
	channeledSkillActive = false
	
	-- Clear thread reference (don't try to cancel, just let it exit via flag)
	channeledDamageThread = nil
	
	-- Stop animation
	if channeledTrack then
		channeledTrack:Stop(0.2)
		channeledTrack = nil
	end
	
	-- Reset state
	channeledSlotKey = nil
	channeledSkillInfo = nil
	isUsingSkill = false
	
	-- Return to idle
	if animLoader and not isSprinting then
		animLoader:PlayAnimation("Idle", 0.2)
	end
end

-- Start channeled skill (Whirlwind)
local function startChanneledSkill(slotKey, skillInfo)
	print("[ToolController] Starting channeled skill: " .. skillInfo.DisplayName)
	
	channeledSkillActive = true
	channeledSlotKey = slotKey
	channeledSkillInfo = skillInfo
	channeledStartTime = tick()
	isUsingSkill = true
	
	-- Play looping animation
	local track, _ = skillHandler:PlayAnimation(Humanoid, slotKey)
	if track then
		track.Looped = true
		channeledTrack = track
	end
	
	-- Start damage interval thread
	local damageInterval = skillInfo.DamageInterval or 1.0
	local maxDuration = skillInfo.Duration or 5
	local hitCount = 0
	local localStartTime = channeledStartTime
	
	channeledDamageThread = task.spawn(function()
		-- Deal damage immediately on first hit, then every interval
		while channeledSkillActive do
			-- Check if we should stop before dealing damage
			local elapsed = tick() - localStartTime
			if elapsed >= maxDuration then
				print("[ToolController] Channeled skill reached max duration (" .. maxDuration .. "s)")
				-- Use task.defer to avoid calling stopChanneledSkill from within thread
				task.defer(stopChanneledSkill)
				break
			end
			
			if not channeledSkillActive then break end
			
			hitCount = hitCount + 1
			
			-- Play swing sound
			if Character then
				local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
				playSound(SWING_SOUND_ID, 0.4, rootPart)
			end
			
			-- Fire to server for hit detection
			AttackRemote:FireServer("Skill_" .. slotKey, skillInfo.SkillName, hitCount)
			print("[ToolController] Channeled hit " .. hitCount .. " at " .. string.format("%.1f", elapsed) .. "s")
			
			-- Wait for next damage interval
			task.wait(damageInterval)
		end
	end)
end

-- Skill execution handler
local function handleSkill(slotKey)
	if not isEquipped or not skillHandler then return end
	if isDashing or isUsingSkill then return end
	if combatHandler and combatHandler:IsCurrentlyAttacking() then return end
	
	-- Try to use the skill
	local skillInfo, result = skillHandler:UseSkill(slotKey)
	
	if not skillInfo then
		print("[ToolController] Skill not available: " .. result)
		return
	end
	
	print("[ToolController] Using skill: " .. skillInfo.DisplayName .. " (" .. slotKey .. ")")
	
	-- Handle channeled skills differently
	if skillInfo.IsChanneled then
		startChanneledSkill(slotKey, skillInfo)
		return
	end
	
	isUsingSkill = true
	
	-- Apply dash if skill has it (Thrust)
	if skillInfo.DashForward then
		applySkillDash(skillInfo)
	end
	
	-- Play skill animation
	local track, hitTime = skillHandler:PlayAnimation(Humanoid, slotKey)
	
	if track then
		-- Handle multi-hit skills (Sweep)
		if skillInfo.IsMultiHit and skillInfo.HitTimes then
			for i, hitT in ipairs(skillInfo.HitTimes) do
				task.delay(hitT, function()
					if Character then
						local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
						playSound(SWING_SOUND_ID, 0.5, rootPart)
					end
					
					-- Fire to server for hit detection (with hit index)
					AttackRemote:FireServer("Skill_" .. slotKey, skillInfo.SkillName, i)
				end)
			end
		else
			-- Single hit skill
			task.delay(hitTime or 0.2, function()
				if Character then
					local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
					playSound(SWING_SOUND_ID, 0.5, rootPart)
				end
				
				-- Fire to server for hit detection
				AttackRemote:FireServer("Skill_" .. slotKey, skillInfo.SkillName)
			end)
		end
		
		-- Wait for animation to finish
		track.Stopped:Once(function()
			isUsingSkill = false
			-- Return to idle if not moving
			if animLoader and not isSprinting then
				animLoader:PlayAnimation("Idle", 0.2)
			end
		end)
		
		-- Fallback: reset after duration
		task.delay(skillInfo.Duration or 1, function()
			isUsingSkill = false
		end)
	else
		isUsingSkill = false
	end
end

-- Handle skill key release (for channeled skills)
local function handleSkillRelease(slotKey)
	if channeledSkillActive and channeledSlotKey == slotKey then
		-- Check minimum duration
		local elapsed = tick() - channeledStartTime
		local minDuration = channeledSkillInfo and channeledSkillInfo.MinDuration or 0.5
		
		if elapsed >= minDuration then
			stopChanneledSkill()
		else
			-- Wait for minimum duration then stop
			task.delay(minDuration - elapsed, function()
				if channeledSkillActive and channeledSlotKey == slotKey then
					stopChanneledSkill()
				end
			end)
		end
	end
end

local function handleAttack()
	if not isEquipped or not combatHandler then 
		print("[ToolController] Attack blocked - isEquipped: " .. tostring(isEquipped) .. ", combatHandler: " .. tostring(combatHandler ~= nil))
		return 
	end
	
	if isDashing or isUsingSkill then return end -- Can't attack while dashing or using skill
	
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
				local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
				playSound(SWING_SOUND_ID, 0.5, rootPart)
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
		playSound(DASH_SOUND_ID, 0.5, hrp)
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
	
	-- Skill keys (Z, X, C, V, F)
	local slotKey = SKILL_KEYS[input.KeyCode]
	if slotKey then
		handleSkill(slotKey)
	end
end)

-- Handle key release for channeled skills
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	local slotKey = SKILL_KEYS[input.KeyCode]
	if slotKey then
		handleSkillRelease(slotKey)
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
