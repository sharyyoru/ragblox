--[[
	DeathVFX Module
	Handles death visual effects that scale with character size
	Includes corpse cleanup after effect completes
	Place in ReplicatedStorage.Modules
	
	VFX expected at: ReplicatedStorage.vfx.ondeath.Sparkles
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DeathVFX = {}

-- Configuration
local CORPSE_FADE_TIME = 2 -- Seconds to fade corpse
local CORPSE_CLEANUP_DELAY = 3 -- Seconds after death before cleanup starts
local VFX_DURATION = 2.5 -- How long VFX plays before cleanup
local SPARKLE_SIZE_MULTIPLIER = 3 -- Make sparkles 3x bigger

-- Cache VFX template
local VFX_FOLDER = ReplicatedStorage:WaitForChild("vfx")
local ONDEATH_FOLDER = VFX_FOLDER:WaitForChild("ondeath")
local SPARKLES_VFX = ONDEATH_FOLDER:WaitForChild("Sparkles")

-- Get character scale based on HumanoidRootPart or bounding box
local function getCharacterScale(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Use HRP size as base scale (default HRP is 2x2x1)
		local defaultSize = Vector3.new(2, 2, 1)
		local scale = hrp.Size.Magnitude / defaultSize.Magnitude
		return math.max(0.5, math.min(scale, 5)) -- Clamp between 0.5 and 5
	end
	
	-- Fallback: calculate from bounding box
	local _, size = character:GetBoundingBox()
	local defaultHeight = 5.5 -- Default R15 height
	local scale = size.Y / defaultHeight
	return math.max(0.5, math.min(scale, 5))
end

-- Scale a ParticleEmitter based on character scale and make it shoot upward
local function scaleParticleEmitter(emitter, scale)
	-- Apply 3x size multiplier on top of character scale
	local totalScale = scale * SPARKLE_SIZE_MULTIPLIER
	
	-- Scale size
	if emitter.Size then
		local keypoints = emitter.Size.Keypoints
		local newKeypoints = {}
		for _, kp in ipairs(keypoints) do
			table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, kp.Value * totalScale, kp.Envelope * totalScale))
		end
		emitter.Size = NumberSequence.new(newKeypoints)
	end
	
	-- Scale speed (make particles shoot up faster)
	if emitter.Speed then
		local minSpeed = emitter.Speed.Min * totalScale
		local maxSpeed = emitter.Speed.Max * totalScale
		emitter.Speed = NumberRange.new(minSpeed, maxSpeed)
	end
	
	-- Force particles to shoot upward toward sky
	emitter.EmissionDirection = Enum.NormalId.Top
	
	-- Narrow spread so particles go straight up
	emitter.SpreadAngle = Vector2.new(15, 15)
end

-- Play death VFX on a character (spawns at ground level, not attached to character)
function DeathVFX.Play(character)
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
	
	if not hrp then
		warn("[DeathVFX] No root part found for character: " .. character.Name)
		return
	end
	
	local scale = getCharacterScale(character)
	print("[DeathVFX] Playing for " .. character.Name .. " with scale: " .. string.format("%.2f", scale))
	
	-- Get position at ground level (raycast down to find ground)
	local groundPosition = hrp.Position
	local rayOrigin = hrp.Position
	local rayDirection = Vector3.new(0, -50, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if rayResult then
		groundPosition = rayResult.Position
	else
		-- Fallback: use HRP position minus half character height
		groundPosition = hrp.Position - Vector3.new(0, 3, 0)
	end
	
	-- Create a stationary anchor part at ground level (NOT attached to character)
	local anchorPart = Instance.new("Part")
	anchorPart.Name = "DeathVFXAnchor"
	anchorPart.Size = Vector3.new(1, 1, 1)
	anchorPart.Position = groundPosition
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.Transparency = 1
	anchorPart.Parent = workspace
	
	-- Create attachment on the stationary part
	local attachment = Instance.new("Attachment")
	attachment.Name = "DeathVFXAttachment"
	attachment.Parent = anchorPart
	
	-- Clone the Sparkles VFX
	local vfxClone = SPARKLES_VFX:Clone()
	
	-- Handle different VFX types
	if vfxClone:IsA("ParticleEmitter") then
		-- Scale and attach single emitter
		scaleParticleEmitter(vfxClone, scale)
		vfxClone.Parent = attachment
		
		-- Emit once (don't loop)
		vfxClone.Enabled = false
		local emitCount = vfxClone:GetAttribute("EmitCount") or 30
		vfxClone:Emit(math.floor(emitCount * scale))
		
	elseif vfxClone:IsA("Model") or vfxClone:IsA("Folder") then
		-- Handle multiple emitters in a container
		vfxClone.Parent = attachment
		
		for _, child in pairs(vfxClone:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				scaleParticleEmitter(child, scale)
				child.Enabled = false
				local emitCount = child:GetAttribute("EmitCount") or 20
				child:Emit(math.floor(emitCount * scale))
			end
		end
	else
		-- Direct parent if it's something else
		vfxClone.Parent = anchorPart
	end
	
	-- Immediately hide the character body
	DeathVFX.HideCharacter(character)
	
	-- Cleanup VFX anchor after duration
	Debris:AddItem(anchorPart, VFX_DURATION)
	
	return vfxClone
end

-- Immediately hide character (make invisible)
function DeathVFX.HideCharacter(character)
	if not character then return end
	
	-- Hide all parts immediately
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
			part.CanCollide = false
		elseif part:IsA("Decal") or part:IsA("Texture") then
			part.Transparency = 1
		end
	end
	
	print("[DeathVFX] Character hidden: " .. character.Name)
end

-- Fade and cleanup corpse
function DeathVFX.CleanupCorpse(character, delay)
	delay = delay or CORPSE_CLEANUP_DELAY
	
	task.delay(delay, function()
		if not character or not character.Parent then return end
		
		print("[DeathVFX] Starting corpse cleanup for: " .. character.Name)
		
		-- Collect all BaseParts to fade
		local parts = {}
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
		
		-- Fade all parts
		local fadeInfo = TweenInfo.new(CORPSE_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		
		for _, part in pairs(parts) do
			-- Disable collisions during fade
			part.CanCollide = false
			
			local tween = TweenService:Create(part, fadeInfo, {
				Transparency = 1
			})
			tween:Play()
		end
		
		-- Fade decals/textures too
		for _, decal in pairs(character:GetDescendants()) do
			if decal:IsA("Decal") or decal:IsA("Texture") then
				local tween = TweenService:Create(decal, fadeInfo, {
					Transparency = 1
				})
				tween:Play()
			end
		end
		
		-- Destroy after fade completes
		task.delay(CORPSE_FADE_TIME + 0.1, function()
			if character and character.Parent then
				character:Destroy()
				print("[DeathVFX] Corpse destroyed: " .. character.Name)
			end
		end)
	end)
end

-- Full death sequence: VFX + cleanup
function DeathVFX.OnDeath(character, skipVFX)
	if not character then return end
	
	-- Play death VFX
	if not skipVFX then
		DeathVFX.Play(character)
	end
	
	-- Schedule corpse cleanup
	DeathVFX.CleanupCorpse(character)
end

-- Connect to a humanoid's death event
function DeathVFX.ConnectHumanoid(humanoid)
	if not humanoid then return end
	
	local character = humanoid.Parent
	if not character then return end
	
	humanoid.Died:Connect(function()
		DeathVFX.OnDeath(character)
	end)
	
	return true
end

return DeathVFX
