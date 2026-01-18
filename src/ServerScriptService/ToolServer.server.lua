--[[
	ToolServer (Server)
	Handles server-side combat validation and hit detection
	Uses WeaponRegistry for modular weapon configurations
	Place in ServerScriptService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local WeaponRegistry = require(Modules:WaitForChild("WeaponRegistry"))
local SkillRegistry = require(Modules:WaitForChild("SkillRegistry"))

-- Create Remotes folder if it doesn't exist
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

-- Create Attack remote
local AttackRemote = Remotes:FindFirstChild("Attack")
if not AttackRemote then
	AttackRemote = Instance.new("RemoteEvent")
	AttackRemote.Name = "Attack"
	AttackRemote.Parent = Remotes
end

-- Create DamageDealt remote (server -> client)
local DamageRemote = Remotes:FindFirstChild("DamageDealt")
if not DamageRemote then
	DamageRemote = Instance.new("RemoteEvent")
	DamageRemote.Name = "DamageDealt"
	DamageRemote.Parent = Remotes
end

local playerCooldowns = {}
local playerSkillCooldowns = {} -- Track individual skill cooldowns

local function getWeaponId(tool)
	return tool:GetAttribute("WeaponId") or tool.Name
end

local function getNearbyEnemies(character, range)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return {} end
	
	local enemies = {}
	local position = humanoidRootPart.Position
	
	-- Check other players
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character ~= character then
			local enemyHRP = player.Character:FindFirstChild("HumanoidRootPart")
			local enemyHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
			
			if enemyHRP and enemyHumanoid and enemyHumanoid.Health > 0 then
				local distance = (enemyHRP.Position - position).Magnitude
				if distance <= range then
					table.insert(enemies, {
						Character = player.Character,
						Humanoid = enemyHumanoid,
						Distance = distance,
						HRP = enemyHRP,
					})
				end
			end
		end
	end
	
	-- Check NPCs/Dummies/Rigs in workspace
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Humanoid") and descendant.Health > 0 then
			local npcCharacter = descendant.Parent
			-- Skip if it's the attacker or a player character
			if npcCharacter ~= character and not Players:GetPlayerFromCharacter(npcCharacter) then
				local enemyHRP = npcCharacter:FindFirstChild("HumanoidRootPart") 
					or npcCharacter:FindFirstChild("Torso")
					or npcCharacter:FindFirstChild("UpperTorso")
				
				if enemyHRP then
					local distance = (enemyHRP.Position - position).Magnitude
					if distance <= range then
						table.insert(enemies, {
							Character = npcCharacter,
							Humanoid = descendant,
							Distance = distance,
							HRP = enemyHRP,
						})
					end
				end
			end
		end
	end
	
	-- Sort by distance
	table.sort(enemies, function(a, b)
		return a.Distance < b.Distance
	end)
	
	return enemies
end

local function applyKnockback(targetHRP, attackerPosition, force)
	if not targetHRP or not force or force <= 0 then return end
	
	local direction = (targetHRP.Position - attackerPosition).Unit
	local knockbackVelocity = Instance.new("BodyVelocity")
	knockbackVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	knockbackVelocity.Velocity = direction * force + Vector3.new(0, force * 0.3, 0)
	knockbackVelocity.Parent = targetHRP
	
	task.delay(0.2, function()
		knockbackVelocity:Destroy()
	end)
end

AttackRemote.OnServerEvent:Connect(function(player, skillName, skillRegistryName)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	-- Check for equipped tool
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return end
	
	-- Get weapon config
	local weaponId = getWeaponId(tool)
	local weaponConfig = WeaponRegistry.GetWeapon(weaponId)
	
	-- Check if this is a skill slot attack (Skill_Z, Skill_X, etc.)
	local isSkillSlotAttack = string.match(skillName, "^Skill_(%a)$")
	local skillConfig = nil
	local damage = 0
	local hitRange = weaponConfig.HitRange or 6
	
	if isSkillSlotAttack then
		-- Skill slot attack - get config from SkillRegistry and weapon slot
		local slotKey = isSkillSlotAttack
		local slotData = WeaponRegistry.GetSkillSlot(weaponId, slotKey)
		
		if not slotData then
			warn("[ToolServer] No skill in slot " .. slotKey .. " for weapon: " .. weaponId)
			return
		end
		
		local registrySkill = SkillRegistry.GetSkill(slotData.SkillName)
		if not registrySkill then
			warn("[ToolServer] Unknown skill in registry: " .. tostring(slotData.SkillName))
			return
		end
		
		-- Build skill config from registry + weapon slot multiplier
		skillConfig = {
			Animation = registrySkill.Animation,
			DamageMultiplier = slotData.DamageMultiplier or 1.0,
			Cooldown = registrySkill.Cooldown,
			Range = hitRange * (registrySkill.RangeMultiplier or 1.0),
			IsAoE = registrySkill.IsAoE,
			AoERadius = registrySkill.AoERadius,
			Knockback = registrySkill.Knockback,
		}
		
		-- Calculate damage using weapon base damage and slot multiplier
		damage = math.floor(weaponConfig.BaseDamage * (slotData.DamageMultiplier or 1.0))
		hitRange = skillConfig.Range
		
		-- Use skill name for cooldown tracking
		skillName = slotData.SkillName .. "_" .. slotKey
	else
		-- Regular M1-M4 attack
		skillConfig = weaponConfig.Skills[skillName]
		
		if not skillConfig then
			warn("[ToolServer] Unknown skill: " .. tostring(skillName) .. " for weapon: " .. weaponId)
			return
		end
		
		damage = WeaponRegistry.CalculateDamage(weaponId, skillName)
		hitRange = skillConfig.Range or weaponConfig.HitRange or 6
	end
	
	-- Check base attack cooldown
	local currentTime = tick()
	local attackCooldown = weaponConfig.AttackCooldown or 0.5
	
	if playerCooldowns[player] and currentTime - playerCooldowns[player] < attackCooldown then
		return
	end
	
	-- Check skill-specific cooldown
	if skillConfig.Cooldown then
		playerSkillCooldowns[player] = playerSkillCooldowns[player] or {}
		local lastSkillUse = playerSkillCooldowns[player][skillName] or 0
		
		if currentTime - lastSkillUse < skillConfig.Cooldown then
			return
		end
		playerSkillCooldowns[player][skillName] = currentTime
	end
	
	playerCooldowns[player] = currentTime
	
	-- Get enemies in range
	local enemies = getNearbyEnemies(character, hitRange)
	
	if #enemies == 0 then return end
	
	-- Determine targets (AoE or single)
	local targets = {}
	
	if skillConfig.IsAoE then
		local aoERadius = skillConfig.AoERadius or hitRange
		for _, enemy in ipairs(enemies) do
			if enemy.Distance <= aoERadius then
				table.insert(targets, enemy)
			end
		end
	else
		-- Single target (closest)
		table.insert(targets, enemies[1])
	end
	
	-- Apply damage and effects to all targets
	for _, target in ipairs(targets) do
		target.Humanoid:TakeDamage(damage)
		
		-- Apply knockback if configured
		if skillConfig.Knockback then
			applyKnockback(target.HRP, humanoidRootPart.Position, skillConfig.Knockback)
		end
		
		-- Send damage info to client for UI
		DamageRemote:FireClient(player, damage, target.HRP.Position, target.Character.Name)
		
		print(string.format("[Combat] %s hit %s for %d damage (%s - %s)", 
			player.Name, 
			target.Character.Name, 
			damage,
			weaponId,
			skillName))
	end
end)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player] = nil
	playerSkillCooldowns[player] = nil
end)

print("[ToolServer] Combat system initialized with WeaponRegistry")
