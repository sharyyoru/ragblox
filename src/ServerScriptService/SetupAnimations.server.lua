--[[
	SetupAnimations (Server)
	Creates the animation folder structure and animation instances
	Run this once to set up the animation hierarchy, then can be removed
	Place in ServerScriptService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Animation IDs for Swords
local SWORD_ANIMATIONS = {
	-- Combo attacks
	M1 = "rbxassetid://100801018704943",
	M2 = "rbxassetid://70924391716335",
	M3 = "rbxassetid://95916017998734",
	M4 = "rbxassetid://71608173228517",
	-- Utility animations
	Idle = "rbxassetid://85712461062430",
	Sprint = "rbxassetid://99797485122785",
}

-- Create folder structure
local function createFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function createAnimation(parent, name, animationId)
	local anim = parent:FindFirstChild(name)
	if not anim then
		anim = Instance.new("Animation")
		anim.Name = name
		anim.AnimationId = animationId
		anim.Parent = parent
	else
		anim.AnimationId = animationId
	end
	return anim
end

-- Setup structure
local Animations = createFolder(ReplicatedStorage, "Animations")
local Swords = createFolder(Animations, "Swords")
local SwordAnim = createFolder(Swords, "SwordAnim")

-- Create sword animations
for name, id in pairs(SWORD_ANIMATIONS) do
	createAnimation(SwordAnim, name, id)
	print("[SetupAnimations] Created animation: " .. name)
end

-- Create Remotes folder
local Remotes = createFolder(ReplicatedStorage, "Remotes")
local AttackRemote = Remotes:FindFirstChild("Attack")
if not AttackRemote then
	AttackRemote = Instance.new("RemoteEvent")
	AttackRemote.Name = "Attack"
	AttackRemote.Parent = Remotes
end

print("[SetupAnimations] Animation structure created successfully!")
print("Structure: ReplicatedStorage.Animations.Swords.SwordAnim")
