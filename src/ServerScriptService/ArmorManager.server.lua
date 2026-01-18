--[[
	ArmorManager (Server)
	Applies default starting armor (Shirt/Pants) to players on spawn
	Can be overridden when players equip other armor
	Reapplies defaults if player removes their equipment
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get starting armor folder
local StartingArmor = ReplicatedStorage:WaitForChild("StartingArmor")
local DefaultShirt = StartingArmor:WaitForChild("Armor") -- Armor is a Shirt
local DefaultPants = StartingArmor:WaitForChild("Pants")

local function applyDefaultShirt(character)
	local existingShirt = character:FindFirstChildOfClass("Shirt")
	if existingShirt then
		existingShirt:Destroy()
	end
	
	local shirt = Instance.new("Shirt")
	shirt.Name = "Shirt"
	shirt.ShirtTemplate = DefaultShirt.ShirtTemplate
	shirt.Parent = character
	print("[ArmorManager] Applied default shirt to " .. character.Name)
end

local function applyDefaultPants(character)
	local existingPants = character:FindFirstChildOfClass("Pants")
	if existingPants then
		existingPants:Destroy()
	end
	
	local pants = Instance.new("Pants")
	pants.Name = "Pants"
	pants.PantsTemplate = DefaultPants.PantsTemplate
	pants.Parent = character
	print("[ArmorManager] Applied default pants to " .. character.Name)
end

local function applyDefaultArmor(character)
	applyDefaultShirt(character)
	applyDefaultPants(character)
end

local function setupCharacter(character)
	-- Apply default armor on spawn
	applyDefaultArmor(character)
	
	-- Monitor for armor removal - reapply defaults if removed
	character.ChildRemoved:Connect(function(child)
		-- Small delay to check if it was replaced or just removed
		task.wait(0.1)
		
		if child:IsA("Shirt") then
			-- Check if there's no shirt now
			if not character:FindFirstChildOfClass("Shirt") then
				applyDefaultShirt(character)
			end
		elseif child:IsA("Pants") then
			-- Check if there's no pants now
			if not character:FindFirstChildOfClass("Pants") then
				applyDefaultPants(character)
			end
		end
	end)
end

local function onPlayerAdded(player)
	-- Handle existing character
	if player.Character then
		setupCharacter(player.Character)
	end
	
	-- Handle future respawns
	player.CharacterAdded:Connect(function(character)
		-- Wait for humanoid to ensure character is fully loaded
		character:WaitForChild("Humanoid")
		setupCharacter(character)
	end)
end

-- Initialize for existing players
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Listen for new players
Players.PlayerAdded:Connect(onPlayerAdded)

print("[ArmorManager] Initialized - Default armor system active")
