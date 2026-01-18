--[[
	InventoryManager Module
	Handles inventory logic: 2 tool equip limit
	Place in ReplicatedStorage.Modules
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryManager = {}

-- Configuration
InventoryManager.MAX_EQUIPPED = 2

-- Item categories for filtering
InventoryManager.Categories = {
	ALL = "All",
	WEAPONS = "Weapons",
	ARMOR = "Armor",
	CONSUMABLES = "Consumables",
	MATERIALS = "Materials",
}

-- Item rarity levels
InventoryManager.Rarities = {
	COMMON = { Name = "Common", Color = Color3.fromRGB(180, 180, 180), Order = 1 },
	UNCOMMON = { Name = "Uncommon", Color = Color3.fromRGB(30, 255, 0), Order = 2 },
	RARE = { Name = "Rare", Color = Color3.fromRGB(0, 112, 221), Order = 3 },
	EPIC = { Name = "Epic", Color = Color3.fromRGB(163, 53, 238), Order = 4 },
	LEGENDARY = { Name = "Legendary", Color = Color3.fromRGB(255, 128, 0), Order = 5 },
	MYTHIC = { Name = "Mythic", Color = Color3.fromRGB(255, 0, 128), Order = 6 },
}

-- Get rarity info
function InventoryManager.GetRarity(rarityName)
	return InventoryManager.Rarities[string.upper(rarityName or "COMMON")] or InventoryManager.Rarities.COMMON
end

-- Get all categories
function InventoryManager.GetCategories()
	return InventoryManager.Categories
end

-- Get item category from tool
function InventoryManager.GetItemCategory(tool)
	local category = tool:GetAttribute("Category")
	if category then
		return category
	end
	
	-- Default to Weapons for tools
	if tool:IsA("Tool") then
		return InventoryManager.Categories.WEAPONS
	end
	
	return InventoryManager.Categories.ALL
end

-- Get item rarity from tool
function InventoryManager.GetItemRarity(tool)
	local rarity = tool:GetAttribute("Rarity")
	return InventoryManager.GetRarity(rarity)
end

-- Check if item matches search query
function InventoryManager.MatchesSearch(tool, query)
	if not query or query == "" then
		return true
	end
	
	local lowerQuery = string.lower(query)
	local name = string.lower(tool.Name)
	
	-- Check name
	if string.find(name, lowerQuery) then
		return true
	end
	
	-- Check description
	local desc = tool:GetAttribute("Description")
	if desc and string.find(string.lower(desc), lowerQuery) then
		return true
	end
	
	return false
end

-- Check if item matches category filter
function InventoryManager.MatchesCategory(tool, category)
	if not category or category == InventoryManager.Categories.ALL then
		return true
	end
	
	return InventoryManager.GetItemCategory(tool) == category
end

-- Check if item matches rarity filter
function InventoryManager.MatchesRarity(tool, rarityFilter)
	if not rarityFilter then
		return true
	end
	
	local itemRarity = InventoryManager.GetItemRarity(tool)
	return itemRarity.Name == rarityFilter
end

-- Sort items by various criteria
function InventoryManager.SortItems(items, sortBy, ascending)
	ascending = ascending ~= false -- Default true
	
	local sorted = {}
	for _, item in ipairs(items) do
		table.insert(sorted, item)
	end
	
	table.sort(sorted, function(a, b)
		local valueA, valueB
		
		if sortBy == "Name" then
			valueA = a.Name
			valueB = b.Name
		elseif sortBy == "Rarity" then
			valueA = InventoryManager.GetItemRarity(a).Order
			valueB = InventoryManager.GetItemRarity(b).Order
		elseif sortBy == "Category" then
			valueA = InventoryManager.GetItemCategory(a)
			valueB = InventoryManager.GetItemCategory(b)
		else
			valueA = a.Name
			valueB = b.Name
		end
		
		if ascending then
			return valueA < valueB
		else
			return valueA > valueB
		end
	end)
	
	return sorted
end

-- Filter and sort items
function InventoryManager.FilterItems(items, options)
	options = options or {}
	local searchQuery = options.Search
	local category = options.Category
	local rarity = options.Rarity
	local sortBy = options.SortBy or "Name"
	local ascending = options.Ascending
	
	local filtered = {}
	
	for _, item in ipairs(items) do
		local matches = true
		
		if searchQuery and not InventoryManager.MatchesSearch(item, searchQuery) then
			matches = false
		end
		
		if category and not InventoryManager.MatchesCategory(item, category) then
			matches = false
		end
		
		if rarity and not InventoryManager.MatchesRarity(item, rarity) then
			matches = false
		end
		
		if matches then
			table.insert(filtered, item)
		end
	end
	
	return InventoryManager.SortItems(filtered, sortBy, ascending)
end

return InventoryManager
