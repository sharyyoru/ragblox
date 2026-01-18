# Ragblox - Modular Animation System

A modular animation structure for Roblox tools where animations are loaded based on tool type/category.

## Project Structure

```
src/
├── ReplicatedStorage/
│   └── Modules/
│       ├── AnimationLoader.lua    -- Core module for loading animations by tool type
│       └── CombatHandler.lua      -- Combo system and attack management
├── ServerScriptService/
│   ├── SetupAnimations.server.lua -- Creates animation instances (run once)
│   └── ToolServer.server.lua      -- Server-side combat & hit detection
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       └── ToolController.client.lua -- Client-side input & animation control
└── StarterPack/
    └── BasicSword.lua             -- Example sword tool configuration
```

## Animation Structure

```
ReplicatedStorage/
└── Animations/
    └── Swords/
        └── SwordAnim/
            ├── M1 (rbxassetid://137700881978523)
            ├── M2 (rbxassetid://70924391716335)
            ├── M3 (rbxassetid://95916017998734)
            ├── M4 (rbxassetid://71608173228517)
            ├── Idle (rbxassetid://85712461062430)
            └── Sprint (rbxassetid://119227715041787)
```

## Setup Instructions

### 1. Copy Scripts to Roblox Studio

Place the scripts in their respective locations:

| Script | Location in Roblox Studio |
|--------|---------------------------|
| `AnimationLoader.lua` | ReplicatedStorage.Modules |
| `CombatHandler.lua` | ReplicatedStorage.Modules |
| `SetupAnimations.server.lua` | ServerScriptService |
| `ToolServer.server.lua` | ServerScriptService |
| `ToolController.client.lua` | StarterPlayer.StarterPlayerScripts |

### 2. Run the Game Once

The `SetupAnimations` script will automatically create:
- `ReplicatedStorage.Animations.Swords.SwordAnim` folder
- All Animation instances with correct IDs
- `ReplicatedStorage.Remotes.Attack` RemoteEvent

### 3. Create a Sword Tool

1. Create a new **Tool** in `StarterPack`
2. Name it (e.g., "BasicSword")
3. Add a **Part** named `Handle` inside the tool
4. Add a **String Attribute** called `ToolType` with value `Sword`

### 4. Controls

- **Left Click**: Attack (M1 → M2 → M3 → M4 combo)
- **Left Shift + Move**: Sprint

## Adding New Tool Types

### 1. Add Animation Folder Mapping

In `AnimationLoader.lua`, add your new type:

```lua
local ANIMATION_FOLDERS = {
    Sword = "SwordAnim",
    Spear = "SpearAnim",  -- Add new types here
    Axe = "AxeAnim",
}
```

### 2. Create Animation Folder

Create the folder structure:
```
ReplicatedStorage.Animations.[TypeName]s.[TypeName]Anim
```

Example for Spear:
```
ReplicatedStorage.Animations.Spears.SpearAnim
```

### 3. Add Animations

Add Animation instances inside the folder:
- `M1`, `M2`, `M3`, `M4` (combo attacks)
- `Idle` (idle pose when equipped)
- `Sprint` (running animation)

### 4. Set Tool Attribute

On your new tool, set `ToolType` attribute to match (e.g., `Spear`)

## Animation IDs Reference

### Sword Animations
| Animation | ID |
|-----------|-----|
| M1 | 137700881978523 |
| M2 | 70924391716335 |
| M3 | 95916017998734 |
| M4 | 71608173228517 |
| Idle | 85712461062430 |
| Sprint | 119227715041787 |

## Customization

### Damage Values

Edit `ToolServer.server.lua`:
```lua
local COMBO_DAMAGE = {
    [1] = 10, -- M1
    [2] = 12, -- M2
    [3] = 15, -- M3
    [4] = 20, -- M4 (finisher)
}
```

### Combat Settings

```lua
local HIT_RANGE = 6        -- Attack range in studs
local ATTACK_COOLDOWN = 0.4 -- Seconds between attacks
```

### Movement Speeds

Edit `ToolController.client.lua`:
```lua
local SPRINT_SPEED = 24
local WALK_SPEED = 16
```

### Combo Timing

Edit `CombatHandler.lua`:
```lua
local COMBO_RESET_TIME = 1.5 -- Time before combo resets
local COMBO_WINDOW = 0.8     -- Time window to chain attacks
```
