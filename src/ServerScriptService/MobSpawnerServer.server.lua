--[[
	MobSpawnerServer (Server)
	Initializes and manages the NPC spawning system
	Place in ServerScriptService
	
	This script:
	- Creates the spawner for World1
	- Spawns mobs at designated spawn points
	- Handles mob respawning automatically
	
	Expected structure:
	- ReplicatedStorage.Mobs.[AreaName].[MobName] (R15 character models)
	- Workspace.World1.[AreaName].Spawn1, Spawn2, etc. (spawn point parts)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for modules to be available
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NPCSpawner = require(Modules:WaitForChild("NPCSpawner"))
local MobConfig = require(Modules:WaitForChild("MobConfig"))

-- Configuration
local WORLD_NAME = "World1"
local SPAWN_DELAY = 2 -- Seconds to wait before initial spawn

-- Create the spawner
local spawner = nil

local function initializeSpawner()
	print("[MobSpawnerServer] Initializing mob spawner system...")
	
	-- Create and initialize the spawner
	spawner = NPCSpawner.CreateSpawner(WORLD_NAME)
	
	-- Wait a moment for everything to load
	task.wait(SPAWN_DELAY)
	
	-- Spawn all mobs in all areas
	spawner:SpawnAllAreas()
	
	print("[MobSpawnerServer] Mob spawner system initialized!")
	print("[MobSpawnerServer] Total mobs spawned: " .. spawner:GetMobCount())
end

-- Admin commands (optional, for testing)
local function setupAdminCommands()
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			-- Only allow admin commands from specific players or during testing
			local args = string.split(message, " ")
			local command = args[1]:lower()
			
			if command == "/spawndebug" then
				print("[MobSpawnerServer] Debug Info:")
				print("  - Total mobs: " .. spawner:GetMobCount())
				for areaName, _ in pairs(spawner.SpawnPoints) do
					print("  - " .. areaName .. ": " .. spawner:GetMobCountByArea(areaName))
				end
				
			elseif command == "/respawnall" then
				spawner:DespawnAll()
				task.wait(1)
				spawner:SpawnAllAreas()
				print("[MobSpawnerServer] All mobs respawned")
				
			elseif command == "/respawnarea" and args[2] then
				local areaName = args[2]
				spawner:DespawnArea(areaName)
				task.wait(1)
				spawner:SpawnArea(areaName)
				print("[MobSpawnerServer] Area " .. areaName .. " respawned")
			end
		end)
	end)
end

-- Initialize on server start
initializeSpawner()
setupAdminCommands()

print("[MobSpawnerServer] Server script loaded successfully")
