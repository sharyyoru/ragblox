--[[
	FlightModule - Handles flying mechanics for Flight skill
	Used by ToolController for channeled flight ability
]]

local FlightModule = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
	
	self.idleTrack = animator:LoadAnimation(idleAnim)
	self.moveTrack = animator:LoadAnimation(moveAnim)
	
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
	self.connection = nil
	self.flightSpeed = 90
	
	function self:Start()
		if self.isFlying then return end
		self.isFlying = true
		
		self.bv.Parent = rootPart
		self.bg.Parent = rootPart
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		self.idleTrack:Play()
		
		if self.sound then
			self.sound:Play()
		end
		
		self.connection = RunService.RenderStepped:Connect(function()
			if not self.isFlying then return end
			
			self.bg.CFrame = camera.CFrame
			local moveDir = humanoid.MoveDirection
			self.bv.Velocity = moveDir * self.flightSpeed
			
			if moveDir.Magnitude > 0 then
				if not self.moveTrack.IsPlaying then
					self.idleTrack:Stop()
					self.moveTrack:Play()
				end
			else
				if not self.idleTrack.IsPlaying then
					self.moveTrack:Stop()
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
		
		self.bv.Parent = nil
		self.bg.Parent = nil
		self.idleTrack:Stop()
		self.moveTrack:Stop()
		
		if self.sound then
			self.sound:Stop()
		end
		
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		
		print("[FlightModule] Flight stopped")
	end
	
	function self:Destroy()
		self:Stop()
		
		if self.bv then self.bv:Destroy() end
		if self.bg then self.bg:Destroy() end
		if self.sound then self.sound:Destroy() end
		if self.idleTrack then self.idleTrack:Destroy() end
		if self.moveTrack then self.moveTrack:Destroy() end
	end
	
	return self
end

return FlightModule
