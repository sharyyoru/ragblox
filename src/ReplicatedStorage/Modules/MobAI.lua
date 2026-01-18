--[[
	MobAI Module
	Handles NPC artificial intelligence including patrol and combat behavior
	Place in ReplicatedStorage.Modules
	
	States:
	- Idle: Standing still, waiting
	- Patrol: Walking between random points
	- Chase: Running toward target
	- Attack: Attacking target in range
	- Return: Returning to spawn after losing target
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local MobAI = {}
MobAI.__index = MobAI

-- AI States
MobAI.States = {
	IDLE = "Idle",
	PATROL = "Patrol",
	CHASE = "Chase",
	ATTACK = "Attack",
	RETURN = "Return",
	DEAD = "Dead",
}

function MobAI.new(npc, config, spawnPosition)
	local self = setmetatable({}, MobAI)
	
	self.NPC = npc
	self.Config = config
	self.SpawnPosition = spawnPosition
	
	self.Humanoid = npc:FindFirstChildOfClass("Humanoid")
	self.HumanoidRootPart = npc:FindFirstChild("HumanoidRootPart")
	
	self.State = MobAI.States.IDLE
	self.Target = nil
	self.CurrentPath = nil
	self.LastAttackTime = 0
	self.LastPatrolTime = 0
	self.PatrolWaitTime = 0
	self.IsMoving = false
	
	-- Animation tracks
	self.Animator = self.Humanoid and self.Humanoid:FindFirstChildOfClass("Animator")
	self.WalkTrack = nil
	self.RunTrack = nil
	self.IdleTrack = nil
	self.AttackTracks = {}
	
	-- Combo system
	self.CurrentCombo = 0
	self.MaxCombo = 4
	
	self.Active = true
	self.UpdateConnection = nil
	
	return self
end

function MobAI:SetupAnimations(animationLoader)
	self.AnimationLoader = animationLoader
	
	if animationLoader then
		self.IdleTrack = animationLoader:GetTrack("Idle")
		self.RunTrack = animationLoader:GetTrack("Sprint")
		
		-- Store attack tracks
		for i = 1, 4 do
			local trackName = "M" .. i
			self.AttackTracks[i] = animationLoader:GetTrack(trackName)
		end
	end
end

function MobAI:Start()
	self.Active = true
	self:SetState(MobAI.States.IDLE)
	
	-- Start AI loop
	self.UpdateConnection = RunService.Heartbeat:Connect(function(dt)
		if self.Active then
			self:Update(dt)
		end
	end)
	
	-- Listen for death
	if self.Humanoid then
		self.Humanoid.Died:Connect(function()
			self:OnDeath()
		end)
	end
end

function MobAI:Stop()
	self.Active = false
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
		self.UpdateConnection = nil
	end
	self:StopMoving()
end

function MobAI:SetState(newState)
	if self.State == newState then return end
	
	local oldState = self.State
	self.State = newState
	
	-- Handle state transitions
	if newState == MobAI.States.IDLE then
		self:StopMoving()
		self:PlayIdleAnimation()
		self.PatrolWaitTime = math.random(self.Config.PatrolWaitTime[1], self.Config.PatrolWaitTime[2])
		self.LastPatrolTime = tick()
		
	elseif newState == MobAI.States.PATROL then
		self:PlayWalkAnimation()
		
	elseif newState == MobAI.States.CHASE then
		self:PlayRunAnimation()
		
	elseif newState == MobAI.States.ATTACK then
		self:StopMoving()
		
	elseif newState == MobAI.States.RETURN then
		self:PlayWalkAnimation()
		self.Target = nil
		
	elseif newState == MobAI.States.DEAD then
		self:Stop()
	end
end

function MobAI:Update(dt)
	if not self.Active or not self.Humanoid or self.Humanoid.Health <= 0 then
		return
	end
	
	-- Update based on current state
	if self.State == MobAI.States.IDLE then
		self:UpdateIdle(dt)
		
	elseif self.State == MobAI.States.PATROL then
		self:UpdatePatrol(dt)
		
	elseif self.State == MobAI.States.CHASE then
		self:UpdateChase(dt)
		
	elseif self.State == MobAI.States.ATTACK then
		self:UpdateAttack(dt)
		
	elseif self.State == MobAI.States.RETURN then
		self:UpdateReturn(dt)
	end
	
	-- Always check for targets (except when dead or returning)
	if self.State ~= MobAI.States.DEAD and self.State ~= MobAI.States.RETURN then
		self:CheckForTargets()
	end
end

function MobAI:UpdateIdle(dt)
	-- Wait for patrol timer
	if tick() - self.LastPatrolTime >= self.PatrolWaitTime then
		self:SetState(MobAI.States.PATROL)
		self:StartPatrol()
	end
end

function MobAI:UpdatePatrol(dt)
	-- Check if reached patrol destination
	if not self.IsMoving then
		self:SetState(MobAI.States.IDLE)
	end
end

function MobAI:UpdateChase(dt)
	if not self.Target then
		self:SetState(MobAI.States.RETURN)
		return
	end
	
	local targetHRP = self.Target:FindFirstChild("HumanoidRootPart")
	if not targetHRP then
		self.Target = nil
		self:SetState(MobAI.States.RETURN)
		return
	end
	
	local distance = (targetHRP.Position - self.HumanoidRootPart.Position).Magnitude
	
	-- Check if target is out of deaggro range
	if distance > self.Config.DeaggroRange then
		self.Target = nil
		self:SetState(MobAI.States.RETURN)
		return
	end
	
	-- Check if target is dead
	local targetHumanoid = self.Target:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		self.Target = nil
		self:SetState(MobAI.States.RETURN)
		return
	end
	
	-- Check if in attack range
	if distance <= self.Config.AttackRange then
		self:SetState(MobAI.States.ATTACK)
		return
	end
	
	-- Move toward target
	self:MoveToTarget(targetHRP.Position)
end

function MobAI:UpdateAttack(dt)
	if not self.Target then
		self:SetState(MobAI.States.IDLE)
		return
	end
	
	local targetHRP = self.Target:FindFirstChild("HumanoidRootPart")
	if not targetHRP then
		self.Target = nil
		self:SetState(MobAI.States.IDLE)
		return
	end
	
	local distance = (targetHRP.Position - self.HumanoidRootPart.Position).Magnitude
	
	-- Check if target moved out of attack range
	if distance > self.Config.AttackRange * 1.5 then
		self:SetState(MobAI.States.CHASE)
		return
	end
	
	-- Check if target is dead
	local targetHumanoid = self.Target:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		self.Target = nil
		self:SetState(MobAI.States.IDLE)
		return
	end
	
	-- Face target
	self:FaceTarget(targetHRP.Position)
	
	-- Attack if cooldown is ready
	local currentTime = tick()
	if currentTime - self.LastAttackTime >= self.Config.AttackCooldown then
		self:PerformAttack()
		self.LastAttackTime = currentTime
	end
end

function MobAI:UpdateReturn(dt)
	local distance = (self.SpawnPosition - self.HumanoidRootPart.Position).Magnitude
	
	-- Check if back at spawn
	if distance <= 3 then
		self:SetState(MobAI.States.IDLE)
		return
	end
	
	-- Continue moving to spawn
	if not self.IsMoving then
		self:MoveTo(self.SpawnPosition)
	end
end

function MobAI:CheckForTargets()
	if self.Target then return end -- Already has a target
	
	local closestTarget = nil
	local closestDistance = self.Config.AggroRange
	
	local myPosition = self.HumanoidRootPart.Position
	
	-- Check all players
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local hrp = character:FindFirstChild("HumanoidRootPart")
			
			if humanoid and hrp and humanoid.Health > 0 then
				local distance = (hrp.Position - myPosition).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestTarget = character
				end
			end
		end
	end
	
	if closestTarget then
		self.Target = closestTarget
		self:SetState(MobAI.States.CHASE)
	end
end

function MobAI:StartPatrol()
	-- Pick random point within patrol radius
	local randomAngle = math.random() * math.pi * 2
	local randomRadius = math.random() * self.Config.PatrolRadius
	
	local patrolPoint = self.SpawnPosition + Vector3.new(
		math.cos(randomAngle) * randomRadius,
		0,
		math.sin(randomAngle) * randomRadius
	)
	
	self:MoveTo(patrolPoint)
end

function MobAI:MoveTo(position)
	if not self.Humanoid then return end
	
	self.IsMoving = true
	self.Humanoid.WalkSpeed = self.Config.WalkSpeed
	
	-- Use pathfinding for complex navigation
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	
	local success, errorMessage = pcall(function()
		path:ComputeAsync(self.HumanoidRootPart.Position, position)
	end)
	
	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		
		for _, waypoint in ipairs(waypoints) do
			if not self.Active then break end
			if self.State == MobAI.States.CHASE or self.State == MobAI.States.ATTACK then break end
			
			self.Humanoid:MoveTo(waypoint.Position)
			
			local reached = self.Humanoid.MoveToFinished:Wait()
			if not reached then break end
		end
	else
		-- Fallback to direct movement
		self.Humanoid:MoveTo(position)
		self.Humanoid.MoveToFinished:Wait()
	end
	
	self.IsMoving = false
end

function MobAI:MoveToTarget(position)
	if not self.Humanoid then return end
	
	self.Humanoid.WalkSpeed = self.Config.RunSpeed
	self.Humanoid:MoveTo(position)
end

function MobAI:StopMoving()
	if self.Humanoid then
		self.Humanoid:MoveTo(self.HumanoidRootPart.Position)
	end
	self.IsMoving = false
end

function MobAI:FaceTarget(targetPosition)
	if not self.HumanoidRootPart then return end
	
	local direction = (targetPosition - self.HumanoidRootPart.Position).Unit
	local lookAt = self.HumanoidRootPart.Position + Vector3.new(direction.X, 0, direction.Z)
	
	self.HumanoidRootPart.CFrame = CFrame.lookAt(self.HumanoidRootPart.Position, lookAt)
end

function MobAI:PerformAttack()
	-- Increment combo
	self.CurrentCombo = self.CurrentCombo + 1
	if self.CurrentCombo > self.MaxCombo then
		self.CurrentCombo = 1
	end
	
	-- Play attack animation
	local attackTrack = self.AttackTracks[self.CurrentCombo]
	if attackTrack then
		attackTrack:Play(0.1)
	elseif self.AnimationLoader then
		self.AnimationLoader:PlayAnimation("M" .. self.CurrentCombo, 0.1)
	end
	
	-- Deal damage after hit timing
	task.delay(0.2, function()
		if self.Target and self.Active then
			local targetHumanoid = self.Target:FindFirstChildOfClass("Humanoid")
			local targetHRP = self.Target:FindFirstChild("HumanoidRootPart")
			
			if targetHumanoid and targetHRP then
				local distance = (targetHRP.Position - self.HumanoidRootPart.Position).Magnitude
				if distance <= self.Config.AttackRange * 1.2 then
					targetHumanoid:TakeDamage(self.Config.BaseDamage)
				end
			end
		end
	end)
end

function MobAI:PlayIdleAnimation()
	self:StopAllAnimations()
	if self.IdleTrack then
		self.IdleTrack:Play(0.2)
	elseif self.AnimationLoader then
		self.AnimationLoader:PlayAnimation("Idle", 0.2)
	end
end

function MobAI:PlayWalkAnimation()
	self:StopAllAnimations()
	-- Use default walk (Roblox handles this automatically via Humanoid)
end

function MobAI:PlayRunAnimation()
	self:StopAllAnimations()
	if self.RunTrack then
		self.RunTrack:Play(0.2)
	elseif self.AnimationLoader then
		self.AnimationLoader:PlayAnimation("Sprint", 0.2)
	end
end

function MobAI:StopAllAnimations()
	if self.IdleTrack then self.IdleTrack:Stop(0.1) end
	if self.RunTrack then self.RunTrack:Stop(0.1) end
	for _, track in pairs(self.AttackTracks) do
		if track then track:Stop(0.1) end
	end
end

function MobAI:OnDeath()
	self:SetState(MobAI.States.DEAD)
	self:StopAllAnimations()
	
	-- Fire death event for spawner to handle respawn
	if self.OnDeathCallback then
		self.OnDeathCallback(self)
	end
end

function MobAI:SetOnDeathCallback(callback)
	self.OnDeathCallback = callback
end

function MobAI:Destroy()
	self:Stop()
	self:StopAllAnimations()
	self.Target = nil
	self.NPC = nil
end

return MobAI
