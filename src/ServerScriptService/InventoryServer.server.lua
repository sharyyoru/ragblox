--[[
	InventoryServer Script
	Handles server-side inventory logic: 2 tool limit
	Place in ServerScriptService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryManager = require(Modules:WaitForChild("InventoryManager"))

-- Create RemoteEvents
local InventoryFolder = Instance.new("Folder")
InventoryFolder.Name = "InventoryRemotes"
InventoryFolder.Parent = ReplicatedStorage

local EquipToolEvent = Instance.new("RemoteEvent")
EquipToolEvent.Name = "EquipTool"
EquipToolEvent.Parent = InventoryFolder

local UnequipToolEvent = Instance.new("RemoteEvent")
UnequipToolEvent.Name = "UnequipTool"
UnequipToolEvent.Parent = InventoryFolder

local GetInventoryEvent = Instance.new("RemoteFunction")
GetInventoryEvent.Name = "GetInventory"
GetInventoryEvent.Parent = InventoryFolder

local InventoryUpdatedEvent = Instance.new("RemoteEvent")
InventoryUpdatedEvent.Name = "InventoryUpdated"
InventoryUpdatedEvent.Parent = InventoryFolder

-- Player data storage
local PlayerData = {}

-- Initialize player data
local function initPlayerData(player)
	PlayerData[player] = {
		EquippedTools = {}, -- List of equipped tool names (max 2)
		Inventory = {}, -- All owned items
	}
end

-- Get equipped tool count
local function getEquippedCount(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local count = 0
	
	if backpack then
		count = count + #backpack:GetChildren()
	end
	
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				count = count + 1
			end
		end
	end
	
	return count
end

-- Get all equipped tools
local function getEquippedTools(player)
	local tools = {}
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end
	
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end
	
	return tools
end

-- Equip a tool from storage
local function equipTool(player, toolName)
	local data = PlayerData[player]
	if not data then return false, "Player data not found" end
	
	-- Check equip limit
	local equippedCount = getEquippedCount(player)
	if equippedCount >= InventoryManager.MAX_EQUIPPED then
		return false, "Maximum " .. InventoryManager.MAX_EQUIPPED .. " tools can be equipped"
	end
	
	-- Find the tool in player's inventory storage
	local playerStorage = ReplicatedStorage:FindFirstChild("PlayerInventories")
	if not playerStorage then
		playerStorage = Instance.new("Folder")
		playerStorage.Name = "PlayerInventories"
		playerStorage.Parent = ReplicatedStorage
	end
	
	local playerFolder = playerStorage:FindFirstChild(tostring(player.UserId))
	if not playerFolder then
		return false, "Inventory not found"
	end
	
	local tool = playerFolder:FindFirstChild(toolName)
	if not tool then
		return false, "Tool not found in inventory"
	end
	
	-- Clone and give to player
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false, "Backpack not found"
	end
	
	local toolClone = tool:Clone()
	toolClone.Parent = backpack
	
	-- Notify client of inventory update
	InventoryUpdatedEvent:FireClient(player)
	
	return true, "Tool equipped"
end

-- Unequip a tool to storage
local function unequipTool(player, toolName)
	local data = PlayerData[player]
	if not data then return false, "Player data not found" end
	
	-- Find the tool in backpack or character
	local tool = nil
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	
	if backpack then
		tool = backpack:FindFirstChild(toolName)
	end
	
	if not tool and character then
		tool = character:FindFirstChild(toolName)
		if tool and not tool:IsA("Tool") then
			tool = nil
		end
	end
	
	if not tool then
		return false, "Tool not found in equipped items"
	end
	
	-- Move to player storage
	local playerStorage = ReplicatedStorage:FindFirstChild("PlayerInventories")
	if not playerStorage then
		playerStorage = Instance.new("Folder")
		playerStorage.Name = "PlayerInventories"
		playerStorage.Parent = ReplicatedStorage
	end
	
	local playerFolder = playerStorage:FindFirstChild(tostring(player.UserId))
	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = tostring(player.UserId)
		playerFolder.Parent = playerStorage
	end
	
	tool.Parent = playerFolder
	
	-- Notify client of inventory update
	InventoryUpdatedEvent:FireClient(player)
	
	return true, "Tool unequipped"
end

-- Get player inventory data
local function getInventoryData(player)
	local equipped = {}
	local stored = {}
	
	-- Get equipped tools
	for _, tool in ipairs(getEquippedTools(player)) do
		table.insert(equipped, {
			Name = tool.Name,
			Category = tool:GetAttribute("Category") or "Weapons",
			Rarity = tool:GetAttribute("Rarity") or "Common",
			Description = tool:GetAttribute("Description") or "",
			Icon = tool.TextureId or "",
		})
	end
	
	-- Get stored tools
	local playerStorage = ReplicatedStorage:FindFirstChild("PlayerInventories")
	if playerStorage then
		local playerFolder = playerStorage:FindFirstChild(tostring(player.UserId))
		if playerFolder then
			for _, tool in ipairs(playerFolder:GetChildren()) do
				if tool:IsA("Tool") then
					table.insert(stored, {
						Name = tool.Name,
						Category = tool:GetAttribute("Category") or "Weapons",
						Rarity = tool:GetAttribute("Rarity") or "Common",
						Description = tool:GetAttribute("Description") or "",
						Icon = tool.TextureId or "",
					})
				end
			end
		end
	end
	
	local remainingCooldown = getRemainingCooldown(player)
	
	return {
		Equipped = equipped,
		Stored = stored,
		MaxEquipped = InventoryManager.MAX_EQUIPPED,
		EquippedCount = #equipped,
		RemainingCooldown = remainingCooldown,
	}
end

-- Handle equip request
EquipToolEvent.OnServerEvent:Connect(function(player, toolName)
	local success, message = equipTool(player, toolName)
	if not success then
		warn("[InventoryServer] Equip failed for " .. player.Name .. ": " .. message)
	end
end)

-- Handle unequip request
UnequipToolEvent.OnServerEvent:Connect(function(player, toolName)
	local success, message = unequipTool(player, toolName)
	if not success then
		warn("[InventoryServer] Unequip failed for " .. player.Name .. ": " .. message)
	end
end)

-- Handle inventory request
GetInventoryEvent.OnServerInvoke = function(player)
	return getInventoryData(player)
end

-- Player setup
local function onPlayerAdded(player)
	initPlayerData(player)
	
	-- Create player storage folder
	local playerStorage = ReplicatedStorage:FindFirstChild("PlayerInventories")
	if not playerStorage then
		playerStorage = Instance.new("Folder")
		playerStorage.Name = "PlayerInventories"
		playerStorage.Parent = ReplicatedStorage
	end
	
	local playerFolder = playerStorage:FindFirstChild(tostring(player.UserId))
	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = tostring(player.UserId)
		playerFolder.Parent = playerStorage
	end
	
	print("[InventoryServer] Player initialized: " .. player.Name)
end

local function onPlayerRemoving(player)
	PlayerData[player] = nil
end

-- Initialize
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[InventoryServer] Inventory system initialized")
