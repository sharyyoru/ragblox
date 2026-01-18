--[[
	FlightModule - Handles flying mechanics for Flight skill
	Used by ToolController for channeled flight ability
	Features: Spacebar altitude, WASD movement, trail VFX
]]

local FlightModule = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Flight VFX path
local VFX_FOLDER_PATH = "vfx/flight"

function FlightModule.new(player, idleAnimId, moveAnimId, soundId)
	local self = {}
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	
	-- Create Physics Objects
	self.bv = Instance.new("BodyVelocity")
	self.bv.MaxForce = Vector3.new(1, 1, 1) * 10^6
	self.bv.Velocity = Vector3.zero
	
	self.bg = Instance.new("BodyGyro")
	self.bg.MaxTorque = Vector3.new(1, 1, 1) * 10^6
	self.bg.CFrame = rootPart.CFrame

	-- Animation Setup
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
	
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = idleAnimId
	local moveAnim = Instance.new("Animation")
	moveAnim.AnimationId = moveAnimId
	local fallAnim = Instance.new("Animation")
	fallAnim.AnimationId = "rbxassetid://85082207161803"
	local landingAnim = Instance.new("Animation")
	landingAnim.AnimationId = "rbxassetid://88443617112385"
	
	self.idleTrack = animator:LoadAnimation(idleAnim)
	self.moveTrack = animator:LoadAnimation(moveAnim)
	self.fallTrack = animator:LoadAnimation(fallAnim)
	self.landingTrack = animator:LoadAnimation(landingAnim)
	
	-- Sound Setup
	self.sound = nil
	if soundId then
		self.sound = Instance.new("Sound")
		self.sound.SoundId = soundId
		self.sound.Looped = true
		self.sound.Volume = 0.5
		self.sound.Parent = rootPart
	end
	
	self.isFlying = false
	self.isFalling = false
	self.connection = nil
	self.flightSpeed = 90
	self.verticalSpeed = 60
	self.trailEmitters = {}
	self.trailConnection = nil
	self.groundCheckDistance = 10 -- Distance to detect ground for fall animation
	
	-- Setup trail VFX
	local function setupTrailVFX()
		local vfxFolder = ReplicatedStorage:FindFirstChild("vfx")
		if not vfxFolder then return end
		
		local flightFolder = vfxFolder:FindFirstChild("flight")
		if not flightFolder then return end
		
		-- Clone trail emitters and attach to character
		for _, vfx in ipairs(flightFolder:GetChildren()) do
			local clone = vfx:Clone()
			clone.Parent = rootPart
			
			if clone:IsA("ParticleEmitter") then
				-- Scale star size to 0.3 of original
				if clone.Name:lower():find("star") then
					clone.Size = NumberSequence.new(clone.Size.Keypoints[1].Value * 0.3)
				end
				
				-- Set opacity to 0.4 (transparency)
				clone.Transparency = NumberSequence.new(0.6) -- 0.6 transparency = 0.4 opacity
				
				-- Make particles emit from back (negative Z direction)
				clone.EmissionDirection = Enum.NormalId.Back
				
				clone.Enabled = false
				table.insert(self.trailEmitters, clone)
			elseif clone:IsA("Trail") then
				-- Set trail opacity to 0.4
				clone.Transparency = NumberSequence.new(0.6)
				
				-- Setup trail attachments along Z-axis (back of character)
				local attachment0 = Instance.new("Attachment")
				attachment0.Name = "TrailAttachment0"
				attachment0.Position = Vector3.new(0, 0, -1.5) -- Back of character
				attachment0.Parent = rootPart
				
				local attachment1 = Instance.new("Attachment")
				attachment1.Name = "TrailAttachment1"
				attachment1.Position = Vector3.new(0, 0, -2.5) -- Further back
				attachment1.Parent = rootPart
				
				clone.Attachment0 = attachment0
				clone.Attachment1 = attachment1
				clone.Enabled = false
				table.insert(self.trailEmitters, clone)
				table.insert(self.trailEmitters, attachment0)
				table.insert(self.trailEmitters, attachment1)
			end
		end
		
		print("[FlightModule] Trail VFX setup complete: " .. #self.trailEmitters .. " effects")
	end
	
	-- Enable/disable trail effects
	local function setTrailEnabled(enabled)
		for _, emitter in ipairs(self.trailEmitters) do
			if emitter:IsA("ParticleEmitter") or emitter:IsA("Trail") then
				emitter.Enabled = enabled
			end
		end
	end
	
	-- Cleanup trail effects
	local function cleanupTrailVFX()
		for _, emitter in ipairs(self.trailEmitters) do
			if emitter then
				emitter:Destroy()
			end
		end
		self.trailEmitters = {}
	end
	
	function self:Start()
		if self.isFlying then return end
		self.isFlying = true
		
		-- Setup trail VFX
		setupTrailVFX()
		
		self.bv.Parent = rootPart
		self.bg.Parent = rootPart
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		self.idleTrack:Play()
		
		if self.sound then
			self.sound:Play()
		end
		
		-- Enable trail effects
		setTrailEnabled(true)
		
		self.connection = RunService.RenderStepped:Connect(function()
			if not self.isFlying then return end
			
			self.bg.CFrame = camera.CFrame
			
			-- Horizontal movement from WASD
			local moveDir = humanoid.MoveDirection
			local horizontalVelocity = Vector3.new(moveDir.X, 0, moveDir.Z) * self.flightSpeed
			
			-- Vertical movement from Space (up) and LeftControl (down)
			local verticalVelocity = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				verticalVelocity = self.verticalSpeed
			elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				verticalVelocity = -self.verticalSpeed
			end
			
			-- Combine velocities
			self.bv.Velocity = Vector3.new(horizontalVelocity.X, verticalVelocity, horizontalVelocity.Z)
			
			-- Check distance to ground for fall animation
			local rayOrigin = rootPart.Position
			local rayDirection = Vector3.new(0, -100, 0)
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {character}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			
			local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
			local distanceToGround = rayResult and (rootPart.Position.Y - rayResult.Position.Y) or 100
			
			-- Animation switching based on movement and altitude
			local isMoving = moveDir.Magnitude > 0 or verticalVelocity ~= 0
			local isDescending = verticalVelocity < 0 or (distanceToGround < self.groundCheckDistance and self.bv.Velocity.Y <= 0)
			
			if isDescending and distanceToGround < self.groundCheckDistance then
				-- Play fall animation when close to ground and descending
				if not self.fallTrack.IsPlaying then
					self.idleTrack:Stop()
					self.moveTrack:Stop()
					self.fallTrack:Play()
					self.isFalling = true
				end
			elseif isMoving then
				if not self.moveTrack.IsPlaying then
					self.idleTrack:Stop()
					self.fallTrack:Stop()
					self.moveTrack:Play()
					self.isFalling = false
				end
			else
				if not self.idleTrack.IsPlaying and not self.isFalling then
					self.moveTrack:Stop()
					self.fallTrack:Stop()
					self.idleTrack:Play()
				end
			end
		end)
		
		print("[FlightModule] Flight started")
	end
	
	function self:Stop()
		if not self.isFlying then return end
		self.isFlying = false
		
		if self.connection then 
			self.connection:Disconnect()
			self.connection = nil
		end
		
		-- Disable and cleanup trail effects
		setTrailEnabled(false)
		task.delay(0.5, function()
			cleanupTrailVFX()
		end)
		
		self.bv.Parent = nil
		self.bg.Parent = nil
		self.idleTrack:Stop()
		self.moveTrack:Stop()
		self.fallTrack:Stop()
		
		if self.sound then
			self.sound:Stop()
		end
		
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		
		-- Play superhero landing animation
		self.landingTrack:Play()
		self.landingTrack.Stopped:Wait()
		
		print("[FlightModule] Flight stopped with landing")
	end
	
	function self:Destroy()
		self:Stop()
		cleanupTrailVFX()
		
		if self.bv then self.bv:Destroy() end
		if self.bg then self.bg:Destroy() end
		if self.sound then self.sound:Destroy() end
		if self.idleTrack then self.idleTrack:Destroy() end
		if self.moveTrack then self.moveTrack:Destroy() end
		if self.fallTrack then self.fallTrack:Destroy() end
		if self.landingTrack then self.landingTrack:Destroy() end
	end
	
	return self
end

return FlightModule
