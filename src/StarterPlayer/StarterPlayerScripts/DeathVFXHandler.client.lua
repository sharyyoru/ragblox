--[[
	DeathVFXHandler (Client)
	Handles death visual effects for all characters (players and NPCs)
	Place in StarterPlayer.StarterPlayerScripts
	
	VFX expected at: ReplicatedStorage.vfx.ondeath.Sparkles
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local DeathVFX = require(Modules:WaitForChild("DeathVFX"))

-- Track connected humanoids to avoid duplicate connections
local connectedHumanoids = {}

-- Connect death handler to a humanoid
local function connectDeathHandler(humanoid, character)
	if connectedHumanoids[humanoid] then return end
	connectedHumanoids[humanoid] = true
	
	humanoid.Died:Connect(function()
		-- Play death VFX (client-side visual)
		DeathVFX.Play(character)
		
		-- Clean up tracking
		connectedHumanoids[humanoid] = nil
		
		print("[DeathVFXHandler] Death VFX played for: " .. character.Name)
	end)
end

-- Scan for humanoids in a model
local function scanForHumanoid(model)
	if not model:IsA("Model") then return end
	
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		connectDeathHandler(humanoid, model)
	end
end

-- Setup for player characters
local function setupPlayerCharacter(player)
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			connectDeathHandler(humanoid, character)
		end
	end
	
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- Monitor workspace for NPCs/Mobs
local function monitorWorkspace()
	-- Check SpawnedMobs folder specifically
	local spawnedMobsFolder = workspace:FindFirstChild("SpawnedMobs")
	if spawnedMobsFolder then
		for _, mob in pairs(spawnedMobsFolder:GetChildren()) do
			scanForHumanoid(mob)
		end
		
		spawnedMobsFolder.ChildAdded:Connect(function(child)
			task.wait() -- Wait for humanoid to be added
			scanForHumanoid(child)
		end)
	end
	
	-- Also monitor workspace for any new models with humanoids
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "SpawnedMobs" then
			-- New SpawnedMobs folder created
			child.ChildAdded:Connect(function(mob)
				task.wait()
				scanForHumanoid(mob)
			end)
			
			-- Scan existing
			for _, mob in pairs(child:GetChildren()) do
				scanForHumanoid(mob)
			end
		else
			task.wait()
			scanForHumanoid(child)
		end
	end)
	
	-- Scan all existing models in workspace
	for _, child in pairs(workspace:GetDescendants()) do
		if child:IsA("Humanoid") then
			local character = child.Parent
			if character and not Players:GetPlayerFromCharacter(character) then
				connectDeathHandler(child, character)
			end
		end
	end
end

-- Initialize
local function initialize()
	-- Setup all current players
	for _, player in pairs(Players:GetPlayers()) do
		setupPlayerCharacter(player)
	end
	
	-- Setup new players
	Players.PlayerAdded:Connect(setupPlayerCharacter)
	
	-- Monitor workspace for NPCs
	monitorWorkspace()
	
	print("[DeathVFXHandler] Initialized")
end

initialize()
