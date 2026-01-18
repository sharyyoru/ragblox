--[[
	BGM (Client)
	Background music player - meek volume, non-distracting
	Place in StarterPlayer.StarterPlayerScripts
]]

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- Configuration
local BGM_ID = "rbxassetid://92655824506142"
local BGM_VOLUME = 0.35 -- Audible but not distracting

-- Create sound in SoundService for global playback
local bgmSound = Instance.new("Sound")
bgmSound.Name = "BGM"
bgmSound.SoundId = BGM_ID
bgmSound.Volume = BGM_VOLUME
bgmSound.Looped = true
bgmSound.RollOffMode = Enum.RollOffMode.Linear
bgmSound.Parent = SoundService

-- Wait a moment for game to load, then play
task.wait(1)
bgmSound:Play()

print("[BGM] Background music started at volume " .. BGM_VOLUME)
