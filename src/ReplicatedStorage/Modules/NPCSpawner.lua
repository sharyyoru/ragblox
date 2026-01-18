--[[
	NPCSpawner Module
	Handles spawning and managing NPCs/Mobs at designated spawn points
	Place in ReplicatedStorage.Modules
	
	Structure expected:
	- ReplicatedStorage.Mobs.[AreaName].[MobName] (mob templates)
	- Workspace.World1.[AreaName] (spawn points named Spawn1, Spawn2, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local MobConfig = require(Modules:WaitForChild("MobConfig"))
local MobAI = require(Modules:WaitForChild("MobAI"))
local WeaponRegistry = require(Modules:WaitForChild("WeaponRegistry"))
local AnimationLoader = require(Modules:WaitForChild("AnimationLoader"))
local DeathVFX = require(Modules:WaitForChild("DeathVFX"))

local NPCSpawner = {}
NPCSpawner.__index = NPCSpawner

-- Store all active spawners
local activeSpawners = {}

-- Character animations (same as player)
local CHARACTER_ANIMATIONS = {
	Walk = "rbxassetid://180426354", -- Default Roblox walk
	Run = "rbxassetid://180426354",
	Idle = "rbxassetid://180435571",
}

function NPCSpawner.new(worldName)
	local self = setmetatable({}, NPCSpawner)
	
	self.WorldName = worldName or "World1"
	self.SpawnedMobs = {} -- Track all spawned mobs
	self.SpawnPoints = {} -- Cache spawn points by area
	self.MobTemplates = {} -- Cache mob templates
	self.ActiveAIs = {} -- Track AI instances
	
	return self
end

function NPCSpawner:Initialize()
	print("[NPCSpawner] Initializing for world: " .. self.WorldName)
	
	-- Cache mob templates from ReplicatedStorage
	local mobsFolder = ReplicatedStorage:FindFirstChild("Mobs")
	if mobsFolder then
		for _, areaFolder in ipairs(mobsFolder:GetChildren()) do
			self.MobTemplates[areaFolder.Name] = {}
			for _, mobTemplate in ipairs(areaFolder:GetChildren()) do
				self.MobTemplates[areaFolder.Name][mobTemplate.Name] = mobTemplate
				print("[NPCSpawner] Cached template: " .. areaFolder.Name .. "/" .. mobTemplate.Name)
			end
		end
	else
		warn("[NPCSpawner] Mobs folder not found in ReplicatedStorage")
	end
	
	-- Cache spawn points from World folder
	local worldFolder = workspace:FindFirstChild(self.WorldName)
	if worldFolder then
		for _, areaFolder in ipairs(worldFolder:GetChildren()) do
			self.SpawnPoints[areaFolder.Name] = {}
			for _, child in ipairs(areaFolder:GetChildren()) do
				if child.Name:match("^Spawn%d+$") then
					table.insert(self.SpawnPoints[areaFolder.Name], child)
					print("[NPCSpawner] Cached spawn point: " .. areaFolder.Name .. "/" .. child.Name)
				end
			end
		end
	else
		warn("[NPCSpawner] World folder not found: " .. self.WorldName)
	end
	
	return self
end

function NPCSpawner:SpawnAllAreas()
	for areaName, spawnPoints in pairs(self.SpawnPoints) do
		self:SpawnArea(areaName)
	end
end

function NPCSpawner:SpawnArea(areaName)
	local spawnPoints = self.SpawnPoints[areaName]
	local templates = self.MobTemplates[areaName]
	
	if not spawnPoints or #spawnPoints == 0 then
		warn("[NPCSpawner] No spawn points for area: " .. areaName)
		return
	end
	
	if not templates then
		warn("[NPCSpawner] No mob templates for area: " .. areaName)
		return
	end
	
	-- Get list of available mob names
	local mobNames = {}
	for mobName, _ in pairs(templates) do
		table.insert(mobNames, mobName)
	end
	
	if #mobNames == 0 then
		warn("[NPCSpawner] No mobs defined for area: " .. areaName)
		return
	end
	
	-- Spawn a mob at each spawn point
	for i, spawnPoint in ipairs(spawnPoints) do
		-- Cycle through mob types or pick randomly
		local mobName = mobNames[((i - 1) % #mobNames) + 1]
		self:SpawnMob(areaName, mobName, spawnPoint)
	end
	
	print("[NPCSpawner] Spawned " .. #spawnPoints .. " mobs in " .. areaName)
end

function NPCSpawner:SpawnMob(areaName, mobName, spawnPoint)
	local template = self.MobTemplates[areaName] and self.MobTemplates[areaName][mobName]
	if not template then
		warn("[NPCSpawner] Template not found: " .. areaName .. "/" .. mobName)
		return nil
	end
	
	local config = MobConfig.GetMob(areaName, mobName)
	
	-- Clone the template
	local npc = template:Clone()
	
	-- Get spawn position
	local spawnPosition
	if spawnPoint:IsA("BasePart") then
		spawnPosition = spawnPoint.Position + Vector3.new(0, 3, 0)
	elseif spawnPoint:IsA("Model") then
		local primaryPart = spawnPoint.PrimaryPart or spawnPoint:FindFirstChildWhichIsA("BasePart")
		if primaryPart then
			spawnPosition = primaryPart.Position + Vector3.new(0, 3, 0)
		else
			spawnPosition = Vector3.new(0, 5, 0)
		end
	else
		spawnPosition = Vector3.new(0, 5, 0)
	end
	
	-- Position the NPC
	if npc:IsA("Model") then
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		if hrp then
			npc:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
		else
			-- Try to find any part to position
			local part = npc:FindFirstChildWhichIsA("BasePart")
			if part then
				local offset = part.Position - (npc:GetBoundingBox().Position)
				npc:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
			end
		end
	end
	
	-- Setup Humanoid
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = config.MaxHealth
		humanoid.Health = config.MaxHealth
		humanoid.WalkSpeed = config.WalkSpeed
		humanoid.BreakJointsOnDeath = false -- Disable default death animation
	else
		-- Create Humanoid if not exists
		humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth = config.MaxHealth
		humanoid.Health = config.MaxHealth
		humanoid.WalkSpeed = config.WalkSpeed
		humanoid.BreakJointsOnDeath = false -- Disable default death animation
		humanoid.Parent = npc
	end
	
	-- Ensure Animator exists
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	-- Set attributes for identification
	npc:SetAttribute("MobName", mobName)
	npc:SetAttribute("AreaName", areaName)
	npc:SetAttribute("SpawnPointName", spawnPoint.Name)
	npc:SetAttribute("IsNPC", true)
	
	-- Parent to workspace
	local mobsContainer = workspace:FindFirstChild("SpawnedMobs")
	if not mobsContainer then
		mobsContainer = Instance.new("Folder")
		mobsContainer.Name = "SpawnedMobs"
		mobsContainer.Parent = workspace
	end
	npc.Parent = mobsContainer
	
	-- Equip weapon
	self:EquipWeapon(npc, config.WeaponName)
	
	-- Setup AI
	local weaponStyle = WeaponRegistry.GetWeaponStyle(config.WeaponName)
	local animLoader = AnimationLoader.new(npc, weaponStyle)
	animLoader:LoadAnimations()
	
	local ai = MobAI.new(npc, config, spawnPosition)
	ai:SetupAnimations(animLoader)
	ai:Start()
	
	-- Handle respawn on death
	ai:SetOnDeathCallback(function()
		self:OnMobDeath(npc, areaName, mobName, spawnPoint, config)
	end)
	
	-- Track the spawned mob
	local spawnId = areaName .. "_" .. spawnPoint.Name
	self.SpawnedMobs[spawnId] = npc
	self.ActiveAIs[spawnId] = ai
	
	print("[NPCSpawner] Spawned: " .. mobName .. " at " .. spawnPoint.Name)
	
	return npc
end

function NPCSpawner:EquipWeapon(npc, weaponName)
	-- Find weapon in ReplicatedStorage.Weapons
	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	if not weaponsFolder then return end
	
	local weaponTool = nil
	
	-- Check 1h folder
	local folder1h = weaponsFolder:FindFirstChild("1h")
	if folder1h then
		weaponTool = folder1h:FindFirstChild(weaponName)
	end
	
	-- Check 2h folder if not found
	if not weaponTool then
		local folder2h = weaponsFolder:FindFirstChild("2h")
		if folder2h then
			weaponTool = folder2h:FindFirstChild(weaponName)
		end
	end
	
	if weaponTool then
		local clonedWeapon = weaponTool:Clone()
		
		-- For NPCs, we just attach the weapon visually (not as a Tool)
		-- Find the Handle part
		local handle = clonedWeapon:FindFirstChild("Handle")
		if handle then
			local rightArm = npc:FindFirstChild("Right Arm") or npc:FindFirstChild("RightHand")
			if rightArm then
				-- Weld weapon to hand
				local weld = Instance.new("Weld")
				weld.Part0 = rightArm
				weld.Part1 = handle
				weld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
				weld.Parent = handle
				
				handle.Anchored = false
				handle.CanCollide = false
				clonedWeapon.Parent = npc
			end
		else
			-- If it's a model without Handle, parent it to NPC
			clonedWeapon.Parent = npc
		end
		
		npc:SetAttribute("WeaponName", weaponName)
	end
end

function NPCSpawner:OnMobDeath(npc, areaName, mobName, spawnPoint, config)
	local spawnId = areaName .. "_" .. spawnPoint.Name
	
	-- Clean up AI
	if self.ActiveAIs[spawnId] then
		self.ActiveAIs[spawnId]:Destroy()
		self.ActiveAIs[spawnId] = nil
	end
	
	-- Remove from tracking
	self.SpawnedMobs[spawnId] = nil
	
	-- Body is hidden immediately by client-side DeathVFXHandler
	-- Just schedule respawn
	task.delay(config.RespawnTime, function()
		-- Respawn at spawn point
		self:SpawnMob(areaName, mobName, spawnPoint)
	end)
	
	print("[NPCSpawner] " .. mobName .. " died, respawning in " .. config.RespawnTime .. "s")
end

function NPCSpawner:DespawnAll()
	for spawnId, npc in pairs(self.SpawnedMobs) do
		if self.ActiveAIs[spawnId] then
			self.ActiveAIs[spawnId]:Destroy()
		end
		if npc and npc.Parent then
			npc:Destroy()
		end
	end
	
	self.SpawnedMobs = {}
	self.ActiveAIs = {}
	
	print("[NPCSpawner] All mobs despawned")
end

function NPCSpawner:DespawnArea(areaName)
	for spawnId, npc in pairs(self.SpawnedMobs) do
		if spawnId:match("^" .. areaName .. "_") then
			if self.ActiveAIs[spawnId] then
				self.ActiveAIs[spawnId]:Destroy()
				self.ActiveAIs[spawnId] = nil
			end
			if npc and npc.Parent then
				npc:Destroy()
			end
			self.SpawnedMobs[spawnId] = nil
		end
	end
	
	print("[NPCSpawner] Area " .. areaName .. " despawned")
end

function NPCSpawner:GetMobCount()
	local count = 0
	for _, _ in pairs(self.SpawnedMobs) do
		count = count + 1
	end
	return count
end

function NPCSpawner:GetMobCountByArea(areaName)
	local count = 0
	for spawnId, _ in pairs(self.SpawnedMobs) do
		if spawnId:match("^" .. areaName .. "_") then
			count = count + 1
		end
	end
	return count
end

-- Static method to create and register a spawner
function NPCSpawner.CreateSpawner(worldName)
	local spawner = NPCSpawner.new(worldName)
	spawner:Initialize()
	activeSpawners[worldName] = spawner
	return spawner
end

-- Get an existing spawner
function NPCSpawner.GetSpawner(worldName)
	return activeSpawners[worldName]
end

return NPCSpawner
