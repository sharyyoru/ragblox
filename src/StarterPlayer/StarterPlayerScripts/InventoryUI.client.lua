--[[
	InventoryUI Client Script
	Modern inventory interface with tabs, search, and filters
	3 tool equip limit, 12 second switch cooldown
	Place in StarterPlayerScripts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Wait for remotes
local InventoryRemotes = ReplicatedStorage:WaitForChild("InventoryRemotes", 10)
local EquipToolEvent = InventoryRemotes and InventoryRemotes:WaitForChild("EquipTool")
local UnequipToolEvent = InventoryRemotes and InventoryRemotes:WaitForChild("UnequipTool")
local GetInventoryEvent = InventoryRemotes and InventoryRemotes:WaitForChild("GetInventory")
local InventoryUpdatedEvent = InventoryRemotes and InventoryRemotes:WaitForChild("InventoryUpdated")
local SwitchCooldownEvent = InventoryRemotes and InventoryRemotes:WaitForChild("SwitchCooldown")

-- Configuration
local CONFIG = {
	-- Colors
	BackgroundColor = Color3.fromRGB(18, 18, 24),
	PanelColor = Color3.fromRGB(25, 25, 35),
	CardColor = Color3.fromRGB(35, 35, 48),
	CardHoverColor = Color3.fromRGB(45, 45, 62),
	AccentColor = Color3.fromRGB(99, 102, 241), -- Indigo
	AccentHoverColor = Color3.fromRGB(129, 132, 255),
	TextColor = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(156, 163, 175),
	BorderColor = Color3.fromRGB(55, 55, 70),
	SuccessColor = Color3.fromRGB(34, 197, 94),
	WarningColor = Color3.fromRGB(251, 191, 36),
	ErrorColor = Color3.fromRGB(239, 68, 68),
	
	-- Rarity Colors
	RarityColors = {
		Common = Color3.fromRGB(156, 163, 175),
		Uncommon = Color3.fromRGB(34, 197, 94),
		Rare = Color3.fromRGB(59, 130, 246),
		Epic = Color3.fromRGB(168, 85, 247),
		Legendary = Color3.fromRGB(249, 115, 22),
		Mythic = Color3.fromRGB(236, 72, 153),
	},
	
	-- Animation
	TweenSpeed = 0.2,
	
	-- Layout
	MaxEquipped = 3,
	SwitchCooldown = 12,
}

-- State
local isOpen = false
local currentTab = "All"
local searchQuery = ""
local sortBy = "Name"
local sortAscending = true
local switchCooldownEnd = 0
local inventoryData = nil

-- UI References
local ScreenGui, MainFrame, ItemsContainer, EquippedContainer
local SearchBox, TabButtons, CooldownLabel

-- Utility Functions
local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or CONFIG.BorderColor
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function createPadding(parent, padding)
	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingTop = UDim.new(0, padding)
	uiPadding.PaddingBottom = UDim.new(0, padding)
	uiPadding.PaddingLeft = UDim.new(0, padding)
	uiPadding.PaddingRight = UDim.new(0, padding)
	uiPadding.Parent = parent
	return uiPadding
end

local function tweenProperty(object, properties, duration)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(duration or CONFIG.TweenSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		properties
	)
	tween:Play()
	return tween
end

local function getRarityColor(rarity)
	return CONFIG.RarityColors[rarity] or CONFIG.RarityColors.Common
end

-- Create the inventory button (above HP bar)
local function createInventoryButton()
	local buttonGui = Instance.new("ScreenGui")
	buttonGui.Name = "InventoryButton"
	buttonGui.ResetOnSpawn = false
	buttonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	buttonGui.IgnoreGuiInset = true
	buttonGui.Parent = PlayerGui
	
	-- Button positioned above HP bar (HP bar is at bottom-left, Y = -110)
	local button = Instance.new("ImageButton")
	button.Name = "OpenInventory"
	button.Size = UDim2.new(0, 50, 0, 50)
	button.Position = UDim2.new(0, 20, 1, -175) -- Above HP bar
	button.BackgroundColor3 = CONFIG.PanelColor
	button.AutoButtonColor = false
	button.Parent = buttonGui
	
	createCorner(button, 12)
	createStroke(button, CONFIG.BorderColor, 2)
	
	-- Backpack icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🎒"
	icon.TextColor3 = CONFIG.TextColor
	icon.TextSize = 24
	icon.Font = Enum.Font.GothamBold
	icon.Parent = button
	
	-- Hover effects
	button.MouseEnter:Connect(function()
		tweenProperty(button, {BackgroundColor3 = CONFIG.CardHoverColor})
	end)
	
	button.MouseLeave:Connect(function()
		tweenProperty(button, {BackgroundColor3 = CONFIG.PanelColor})
	end)
	
	button.MouseButton1Click:Connect(function()
		if isOpen then
			closeInventory()
		else
			openInventory()
		end
	end)
	
	return buttonGui
end

-- Create main inventory UI
local function createInventoryUI()
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "InventoryUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Enabled = false
	ScreenGui.Parent = PlayerGui
	
	-- Backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = ScreenGui
	
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			closeInventory()
		end
	end)
	
	-- Main container
	MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.new(0, 900, 0, 600)
	MainFrame.Position = UDim2.new(0.5, -450, 0.5, -300)
	MainFrame.BackgroundColor3 = CONFIG.BackgroundColor
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = ScreenGui
	
	createCorner(MainFrame, 16)
	createStroke(MainFrame, CONFIG.BorderColor, 2)
	
	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = CONFIG.PanelColor
	header.BorderSizePixel = 0
	header.Parent = MainFrame
	
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 16)
	headerCorner.Parent = header
	
	-- Fix bottom corners of header
	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 20)
	headerFix.Position = UDim2.new(0, 0, 1, -20)
	headerFix.BackgroundColor3 = CONFIG.PanelColor
	headerFix.BorderSizePixel = 0
	headerFix.Parent = header
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 200, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "📦 Inventory"
	title.TextColor3 = CONFIG.TextColor
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header
	
	-- Equipped counter
	local equippedLabel = Instance.new("TextLabel")
	equippedLabel.Name = "EquippedLabel"
	equippedLabel.Size = UDim2.new(0, 150, 0, 30)
	equippedLabel.Position = UDim2.new(0.5, -75, 0.5, -15)
	equippedLabel.BackgroundColor3 = CONFIG.CardColor
	equippedLabel.TextColor3 = CONFIG.TextColor
	equippedLabel.Text = "Equipped: 0/3"
	equippedLabel.TextSize = 14
	equippedLabel.Font = Enum.Font.GothamMedium
	equippedLabel.Parent = header
	createCorner(equippedLabel, 6)
	
	-- Cooldown indicator
	CooldownLabel = Instance.new("TextLabel")
	CooldownLabel.Name = "CooldownLabel"
	CooldownLabel.Size = UDim2.new(0, 120, 0, 30)
	CooldownLabel.Position = UDim2.new(0.5, 85, 0.5, -15)
	CooldownLabel.BackgroundColor3 = CONFIG.CardColor
	CooldownLabel.TextColor3 = CONFIG.WarningColor
	CooldownLabel.Text = ""
	CooldownLabel.TextSize = 12
	CooldownLabel.Font = Enum.Font.GothamMedium
	CooldownLabel.Visible = false
	CooldownLabel.Parent = header
	createCorner(CooldownLabel, 6)
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0.5, -20)
	closeButton.BackgroundColor3 = CONFIG.CardColor
	closeButton.Text = "✕"
	closeButton.TextColor3 = CONFIG.TextColor
	closeButton.TextSize = 18
	closeButton.Font = Enum.Font.GothamBold
	closeButton.AutoButtonColor = false
	closeButton.Parent = header
	createCorner(closeButton, 8)
	
	closeButton.MouseEnter:Connect(function()
		tweenProperty(closeButton, {BackgroundColor3 = CONFIG.ErrorColor})
	end)
	
	closeButton.MouseLeave:Connect(function()
		tweenProperty(closeButton, {BackgroundColor3 = CONFIG.CardColor})
	end)
	
	closeButton.MouseButton1Click:Connect(closeInventory)
	
	-- Content area
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -40, 1, -80)
	content.Position = UDim2.new(0, 20, 0, 70)
	content.BackgroundTransparency = 1
	content.Parent = MainFrame
	
	-- Left sidebar (tabs and filters)
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 180, 1, 0)
	sidebar.BackgroundColor3 = CONFIG.PanelColor
	sidebar.BorderSizePixel = 0
	sidebar.Parent = content
	createCorner(sidebar, 12)
	createPadding(sidebar, 12)
	
	-- Tab buttons container
	local tabsContainer = Instance.new("Frame")
	tabsContainer.Name = "TabsContainer"
	tabsContainer.Size = UDim2.new(1, 0, 0, 220)
	tabsContainer.BackgroundTransparency = 1
	tabsContainer.Parent = sidebar
	
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Padding = UDim.new(0, 6)
	tabsLayout.Parent = tabsContainer
	
	-- Create tabs
	TabButtons = {}
	local tabs = {"All", "Weapons", "Armor", "Consumables", "Materials"}
	local tabIcons = {All = "📋", Weapons = "⚔️", Armor = "🛡️", Consumables = "🧪", Materials = "💎"}
	
	for i, tabName in ipairs(tabs) do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = tabName .. "Tab"
		tabButton.Size = UDim2.new(1, 0, 0, 36)
		tabButton.BackgroundColor3 = CONFIG.CardColor
		tabButton.Text = tabIcons[tabName] .. " " .. tabName
		tabButton.TextColor3 = CONFIG.TextSecondary
		tabButton.TextSize = 14
		tabButton.Font = Enum.Font.GothamMedium
		tabButton.AutoButtonColor = false
		tabButton.LayoutOrder = i
		tabButton.Parent = tabsContainer
		createCorner(tabButton, 8)
		
		TabButtons[tabName] = tabButton
		
		tabButton.MouseEnter:Connect(function()
			if currentTab ~= tabName then
				tweenProperty(tabButton, {BackgroundColor3 = CONFIG.CardHoverColor})
			end
		end)
		
		tabButton.MouseLeave:Connect(function()
			if currentTab ~= tabName then
				tweenProperty(tabButton, {BackgroundColor3 = CONFIG.CardColor})
			end
		end)
		
		tabButton.MouseButton1Click:Connect(function()
			selectTab(tabName)
		end)
	end
	
	-- Sort options
	local sortLabel = Instance.new("TextLabel")
	sortLabel.Name = "SortLabel"
	sortLabel.Size = UDim2.new(1, 0, 0, 24)
	sortLabel.Position = UDim2.new(0, 0, 0, 240)
	sortLabel.BackgroundTransparency = 1
	sortLabel.Text = "Sort By"
	sortLabel.TextColor3 = CONFIG.TextSecondary
	sortLabel.TextSize = 12
	sortLabel.Font = Enum.Font.GothamMedium
	sortLabel.TextXAlignment = Enum.TextXAlignment.Left
	sortLabel.Parent = sidebar
	
	local sortOptions = {"Name", "Rarity"}
	for i, option in ipairs(sortOptions) do
		local sortButton = Instance.new("TextButton")
		sortButton.Name = option .. "Sort"
		sortButton.Size = UDim2.new(0.48, 0, 0, 30)
		sortButton.Position = UDim2.new((i - 1) * 0.52, 0, 0, 266)
		sortButton.BackgroundColor3 = sortBy == option and CONFIG.AccentColor or CONFIG.CardColor
		sortButton.Text = option
		sortButton.TextColor3 = CONFIG.TextColor
		sortButton.TextSize = 12
		sortButton.Font = Enum.Font.GothamMedium
		sortButton.AutoButtonColor = false
		sortButton.Parent = sidebar
		createCorner(sortButton, 6)
		
		sortButton.MouseButton1Click:Connect(function()
			if sortBy == option then
				sortAscending = not sortAscending
			else
				sortBy = option
				sortAscending = true
			end
			updateSortButtons()
			refreshItems()
		end)
	end
	
	-- Right content area
	local rightContent = Instance.new("Frame")
	rightContent.Name = "RightContent"
	rightContent.Size = UDim2.new(1, -200, 1, 0)
	rightContent.Position = UDim2.new(0, 195, 0, 0)
	rightContent.BackgroundTransparency = 1
	rightContent.Parent = content
	
	-- Search bar
	local searchFrame = Instance.new("Frame")
	searchFrame.Name = "SearchFrame"
	searchFrame.Size = UDim2.new(1, 0, 0, 40)
	searchFrame.BackgroundColor3 = CONFIG.PanelColor
	searchFrame.BorderSizePixel = 0
	searchFrame.Parent = rightContent
	createCorner(searchFrame, 10)
	createStroke(searchFrame, CONFIG.BorderColor)
	
	local searchIcon = Instance.new("TextLabel")
	searchIcon.Size = UDim2.new(0, 40, 1, 0)
	searchIcon.BackgroundTransparency = 1
	searchIcon.Text = "🔍"
	searchIcon.TextSize = 16
	searchIcon.Parent = searchFrame
	
	SearchBox = Instance.new("TextBox")
	SearchBox.Name = "SearchBox"
	SearchBox.Size = UDim2.new(1, -50, 1, 0)
	SearchBox.Position = UDim2.new(0, 40, 0, 0)
	SearchBox.BackgroundTransparency = 1
	SearchBox.Text = ""
	SearchBox.PlaceholderText = "Search items..."
	SearchBox.PlaceholderColor3 = CONFIG.TextSecondary
	SearchBox.TextColor3 = CONFIG.TextColor
	SearchBox.TextSize = 14
	SearchBox.Font = Enum.Font.Gotham
	SearchBox.TextXAlignment = Enum.TextXAlignment.Left
	SearchBox.ClearTextOnFocus = false
	SearchBox.Parent = searchFrame
	
	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchQuery = SearchBox.Text
		refreshItems()
	end)
	
	-- Equipped section
	local equippedSection = Instance.new("Frame")
	equippedSection.Name = "EquippedSection"
	equippedSection.Size = UDim2.new(1, 0, 0, 100)
	equippedSection.Position = UDim2.new(0, 0, 0, 50)
	equippedSection.BackgroundColor3 = CONFIG.PanelColor
	equippedSection.BorderSizePixel = 0
	equippedSection.Parent = rightContent
	createCorner(equippedSection, 10)
	createPadding(equippedSection, 10)
	
	local equippedTitle = Instance.new("TextLabel")
	equippedTitle.Size = UDim2.new(1, 0, 0, 20)
	equippedTitle.BackgroundTransparency = 1
	equippedTitle.Text = "⚔️ Equipped Items"
	equippedTitle.TextColor3 = CONFIG.TextColor
	equippedTitle.TextSize = 14
	equippedTitle.Font = Enum.Font.GothamBold
	equippedTitle.TextXAlignment = Enum.TextXAlignment.Left
	equippedTitle.Parent = equippedSection
	
	EquippedContainer = Instance.new("Frame")
	EquippedContainer.Name = "EquippedContainer"
	EquippedContainer.Size = UDim2.new(1, 0, 0, 60)
	EquippedContainer.Position = UDim2.new(0, 0, 0, 25)
	EquippedContainer.BackgroundTransparency = 1
	EquippedContainer.Parent = equippedSection
	
	local equippedLayout = Instance.new("UIListLayout")
	equippedLayout.FillDirection = Enum.FillDirection.Horizontal
	equippedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	equippedLayout.Padding = UDim.new(0, 10)
	equippedLayout.Parent = EquippedContainer
	
	-- Items grid section
	local itemsSection = Instance.new("Frame")
	itemsSection.Name = "ItemsSection"
	itemsSection.Size = UDim2.new(1, 0, 1, -165)
	itemsSection.Position = UDim2.new(0, 0, 0, 160)
	itemsSection.BackgroundColor3 = CONFIG.PanelColor
	itemsSection.BorderSizePixel = 0
	itemsSection.Parent = rightContent
	createCorner(itemsSection, 10)
	createPadding(itemsSection, 10)
	
	local itemsTitle = Instance.new("TextLabel")
	itemsTitle.Size = UDim2.new(1, 0, 0, 20)
	itemsTitle.BackgroundTransparency = 1
	itemsTitle.Text = "📦 Inventory"
	itemsTitle.TextColor3 = CONFIG.TextColor
	itemsTitle.TextSize = 14
	itemsTitle.Font = Enum.Font.GothamBold
	itemsTitle.TextXAlignment = Enum.TextXAlignment.Left
	itemsTitle.Parent = itemsSection
	
	-- Scrolling frame for items
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ItemsScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -30)
	scrollFrame.Position = UDim2.new(0, 0, 0, 28)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = CONFIG.AccentColor
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.Parent = itemsSection
	
	ItemsContainer = Instance.new("Frame")
	ItemsContainer.Name = "ItemsContainer"
	ItemsContainer.Size = UDim2.new(1, 0, 1, 0)
	ItemsContainer.BackgroundTransparency = 1
	ItemsContainer.Parent = scrollFrame
	
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 100, 0, 120)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = ItemsContainer
	
	-- Auto-size canvas
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 10)
	end)
	
	-- Select first tab
	selectTab("All")
	
	return ScreenGui
end

-- Create item card
local function createItemCard(itemData, isEquipped)
	local card = Instance.new("Frame")
	card.Name = itemData.Name
	card.BackgroundColor3 = CONFIG.CardColor
	card.BorderSizePixel = 0
	createCorner(card, 10)
	
	local rarityColor = getRarityColor(itemData.Rarity)
	createStroke(card, rarityColor, 2)
	
	-- Rarity glow effect
	local glow = Instance.new("Frame")
	glow.Size = UDim2.new(1, 0, 0, 3)
	glow.Position = UDim2.new(0, 0, 0, 0)
	glow.BackgroundColor3 = rarityColor
	glow.BorderSizePixel = 0
	glow.Parent = card
	
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 10)
	glowCorner.Parent = glow
	
	-- Icon placeholder
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(1, -16, 0, 50)
	iconFrame.Position = UDim2.new(0, 8, 0, 12)
	iconFrame.BackgroundColor3 = CONFIG.PanelColor
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = card
	createCorner(iconFrame, 6)
	
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "⚔️"
	iconLabel.TextSize = 28
	iconLabel.Parent = iconFrame
	
	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -8, 0, 18)
	nameLabel.Position = UDim2.new(0, 4, 0, 68)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.Name
	nameLabel.TextColor3 = CONFIG.TextColor
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card
	
	-- Rarity label
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, -8, 0, 14)
	rarityLabel.Position = UDim2.new(0, 4, 0, 86)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = itemData.Rarity
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextSize = 10
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.Parent = card
	
	-- Action button
	local actionButton = Instance.new("TextButton")
	actionButton.Size = UDim2.new(1, -16, 0, 20)
	actionButton.Position = UDim2.new(0, 8, 1, -26)
	actionButton.BackgroundColor3 = isEquipped and CONFIG.ErrorColor or CONFIG.AccentColor
	actionButton.Text = isEquipped and "Unequip" or "Equip"
	actionButton.TextColor3 = CONFIG.TextColor
	actionButton.TextSize = 10
	actionButton.Font = Enum.Font.GothamBold
	actionButton.AutoButtonColor = false
	actionButton.Parent = card
	createCorner(actionButton, 4)
	
	-- Hover effects
	local clickable = Instance.new("TextButton")
	clickable.Size = UDim2.new(1, 0, 1, -26)
	clickable.BackgroundTransparency = 1
	clickable.Text = ""
	clickable.Parent = card
	
	clickable.MouseEnter:Connect(function()
		tweenProperty(card, {BackgroundColor3 = CONFIG.CardHoverColor})
	end)
	
	clickable.MouseLeave:Connect(function()
		tweenProperty(card, {BackgroundColor3 = CONFIG.CardColor})
	end)
	
	actionButton.MouseEnter:Connect(function()
		tweenProperty(actionButton, {
			BackgroundColor3 = isEquipped and Color3.fromRGB(255, 100, 100) or CONFIG.AccentHoverColor
		})
	end)
	
	actionButton.MouseLeave:Connect(function()
		tweenProperty(actionButton, {
			BackgroundColor3 = isEquipped and CONFIG.ErrorColor or CONFIG.AccentColor
		})
	end)
	
	actionButton.MouseButton1Click:Connect(function()
		-- Check cooldown
		if tick() < switchCooldownEnd then
			return
		end
		
		if isEquipped then
			UnequipToolEvent:FireServer(itemData.Name)
		else
			EquipToolEvent:FireServer(itemData.Name)
		end
	end)
	
	return card
end

-- Create equipped slot card
local function createEquippedSlot(itemData, index)
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. index
	slot.Size = UDim2.new(0, 100, 0, 60)
	slot.BackgroundColor3 = CONFIG.CardColor
	slot.BorderSizePixel = 0
	slot.LayoutOrder = index
	createCorner(slot, 8)
	
	if itemData then
		local rarityColor = getRarityColor(itemData.Rarity)
		createStroke(slot, rarityColor, 2)
		
		-- Item info
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -8, 0, 20)
		nameLabel.Position = UDim2.new(0, 4, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "⚔️ " .. itemData.Name
		nameLabel.TextColor3 = CONFIG.TextColor
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot
		
		-- Unequip button
		local unequipBtn = Instance.new("TextButton")
		unequipBtn.Size = UDim2.new(1, -16, 0, 22)
		unequipBtn.Position = UDim2.new(0, 8, 1, -28)
		unequipBtn.BackgroundColor3 = CONFIG.ErrorColor
		unequipBtn.Text = "Unequip"
		unequipBtn.TextColor3 = CONFIG.TextColor
		unequipBtn.TextSize = 10
		unequipBtn.Font = Enum.Font.GothamBold
		unequipBtn.AutoButtonColor = false
		unequipBtn.Parent = slot
		createCorner(unequipBtn, 4)
		
		unequipBtn.MouseButton1Click:Connect(function()
			if tick() < switchCooldownEnd then return end
			UnequipToolEvent:FireServer(itemData.Name)
		end)
	else
		createStroke(slot, CONFIG.BorderColor, 1)
		
		-- Empty slot indicator
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 1, 0)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = "Empty"
		emptyLabel.TextColor3 = CONFIG.TextSecondary
		emptyLabel.TextSize = 12
		emptyLabel.Font = Enum.Font.GothamMedium
		emptyLabel.Parent = slot
	end
	
	return slot
end

-- Select tab
function selectTab(tabName)
	currentTab = tabName
	
	for name, button in pairs(TabButtons) do
		if name == tabName then
			tweenProperty(button, {BackgroundColor3 = CONFIG.AccentColor})
			button.TextColor3 = CONFIG.TextColor
		else
			tweenProperty(button, {BackgroundColor3 = CONFIG.CardColor})
			button.TextColor3 = CONFIG.TextSecondary
		end
	end
	
	refreshItems()
end

-- Update sort buttons
function updateSortButtons()
	local sidebar = MainFrame:FindFirstChild("Content"):FindFirstChild("Sidebar")
	for _, option in ipairs({"Name", "Rarity"}) do
		local btn = sidebar:FindFirstChild(option .. "Sort")
		if btn then
			btn.BackgroundColor3 = sortBy == option and CONFIG.AccentColor or CONFIG.CardColor
			btn.Text = option .. (sortBy == option and (sortAscending and " ↑" or " ↓") or "")
		end
	end
end

-- Refresh items display
function refreshItems()
	if not inventoryData then return end
	
	-- Clear existing items
	for _, child in ipairs(ItemsContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Clear equipped slots
	for _, child in ipairs(EquippedContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Create equipped slots
	for i = 1, CONFIG.MaxEquipped do
		local itemData = inventoryData.Equipped[i]
		local slot = createEquippedSlot(itemData, i)
		slot.Parent = EquippedContainer
	end
	
	-- Update equipped label
	local equippedLabel = MainFrame:FindFirstChild("Header"):FindFirstChild("EquippedLabel")
	if equippedLabel then
		equippedLabel.Text = "Equipped: " .. #inventoryData.Equipped .. "/" .. CONFIG.MaxEquipped
	end
	
	-- Filter and create stored item cards
	local filteredItems = {}
	for _, item in ipairs(inventoryData.Stored) do
		local matchesTab = currentTab == "All" or item.Category == currentTab
		local matchesSearch = searchQuery == "" or string.find(string.lower(item.Name), string.lower(searchQuery))
		
		if matchesTab and matchesSearch then
			table.insert(filteredItems, item)
		end
	end
	
	-- Sort items
	table.sort(filteredItems, function(a, b)
		local valueA, valueB
		if sortBy == "Name" then
			valueA, valueB = a.Name, b.Name
		elseif sortBy == "Rarity" then
			local rarityOrder = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6}
			valueA = rarityOrder[a.Rarity] or 1
			valueB = rarityOrder[b.Rarity] or 1
		end
		
		if sortAscending then
			return valueA < valueB
		else
			return valueA > valueB
		end
	end)
	
	-- Create cards
	for i, item in ipairs(filteredItems) do
		local card = createItemCard(item, false)
		card.LayoutOrder = i
		card.Parent = ItemsContainer
	end
end

-- Open inventory
function openInventory()
	if isOpen then return end
	isOpen = true
	
	-- Fetch inventory data
	if GetInventoryEvent then
		inventoryData = GetInventoryEvent:InvokeServer()
	else
		-- Fallback: Get from backpack directly
		inventoryData = {
			Equipped = {},
			Stored = {},
			MaxEquipped = CONFIG.MaxEquipped,
			EquippedCount = 0,
			RemainingCooldown = 0,
		}
		
		local backpack = Player:FindFirstChild("Backpack")
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					table.insert(inventoryData.Equipped, {
						Name = tool.Name,
						Category = tool:GetAttribute("Category") or "Weapons",
						Rarity = tool:GetAttribute("Rarity") or "Common",
						Description = tool:GetAttribute("Description") or "",
						Icon = tool.TextureId or "",
					})
				end
			end
		end
		
		local character = Player.Character
		if character then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") then
					table.insert(inventoryData.Equipped, {
						Name = child.Name,
						Category = child:GetAttribute("Category") or "Weapons",
						Rarity = child:GetAttribute("Rarity") or "Common",
						Description = child:GetAttribute("Description") or "",
						Icon = child.TextureId or "",
					})
				end
			end
		end
	end
	
	-- Update cooldown
	if inventoryData.RemainingCooldown and inventoryData.RemainingCooldown > 0 then
		switchCooldownEnd = tick() + inventoryData.RemainingCooldown
	end
	
	refreshItems()
	
	ScreenGui.Enabled = true
	MainFrame.Position = UDim2.new(0.5, -450, 0.6, -300)
	MainFrame.BackgroundTransparency = 1
	
	tweenProperty(MainFrame, {
		Position = UDim2.new(0.5, -450, 0.5, -300),
		BackgroundTransparency = 0
	}, 0.3)
end

-- Close inventory
function closeInventory()
	if not isOpen then return end
	isOpen = false
	
	tweenProperty(MainFrame, {
		Position = UDim2.new(0.5, -450, 0.6, -300),
		BackgroundTransparency = 1
	}, 0.2)
	
	task.delay(0.2, function()
		if not isOpen then
			ScreenGui.Enabled = false
		end
	end)
end

-- Handle cooldown updates
local function updateCooldownDisplay()
	while true do
		if isOpen and CooldownLabel then
			local remaining = switchCooldownEnd - tick()
			if remaining > 0 then
				CooldownLabel.Visible = true
				CooldownLabel.Text = string.format("⏱️ %.1fs", remaining)
			else
				CooldownLabel.Visible = false
			end
		end
		task.wait(0.1)
	end
end

-- Initialize
local function init()
	createInventoryButton()
	createInventoryUI()
	
	-- Listen for inventory updates
	if InventoryUpdatedEvent then
		InventoryUpdatedEvent.OnClientEvent:Connect(function()
			if isOpen then
				inventoryData = GetInventoryEvent:InvokeServer()
				refreshItems()
			end
		end)
	end
	
	-- Listen for cooldown updates
	if SwitchCooldownEvent then
		SwitchCooldownEvent.OnClientEvent:Connect(function(cooldownTime)
			switchCooldownEnd = tick() + cooldownTime
		end)
	end
	
	-- Keyboard shortcut (I key)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.I then
			if isOpen then
				closeInventory()
			else
				openInventory()
			end
		end
	end)
	
	-- Start cooldown display updater
	task.spawn(updateCooldownDisplay)
	
	print("[InventoryUI] Inventory system initialized")
end

init()
