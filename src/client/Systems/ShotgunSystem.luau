local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotgunConfig = require(ReplicatedStorage.Shared.ShotgunConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ShotgunSystem = {}
local Effects

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local equipped = false
local ammo = ShotgunConfig.MaxAmmo
local reloading = false
local lastShot = 0

-- ── HUD ──────────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "ShotgunHUD"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local ammoFrame = Instance.new("Frame")
ammoFrame.Size = UDim2.new(0, 170, 0, 44)
ammoFrame.Position = UDim2.new(1, -180, 1, -60)
ammoFrame.BackgroundColor3 = Color3.new(0, 0, 0)
ammoFrame.BackgroundTransparency = 0.45
ammoFrame.BorderSizePixel = 0
ammoFrame.Visible = false
ammoFrame.Parent = gui

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.new(1, 0, 1, 0)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3 = Color3.fromRGB(255, 190, 90)
ammoLabel.TextScaled = true
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.Text = ""
ammoLabel.Parent = ammoFrame

-- Wider crosshair to reflect pellet spread
local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.new(0, 36, 0, 36)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.BackgroundTransparency = 1
crosshair.Visible = false
crosshair.Parent = gui

local function makeLine(size, pos)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = size
	line.Position = pos
	line.BackgroundColor3 = Color3.fromRGB(255, 190, 90)
	line.BorderSizePixel = 0
	line.Parent = crosshair
end
makeLine(UDim2.new(0, 2, 0, 18), UDim2.new(0.5, 0, 0.5, 0))
makeLine(UDim2.new(0, 18, 0, 2), UDim2.new(0.5, 0, 0.5, 0))

local function updateHUD()
	crosshair.Visible = equipped
	ammoFrame.Visible = equipped
	if equipped then
		ammoLabel.Text = reloading and "Reloading..." or ("SG  " .. ammo .. " / " .. ShotgunConfig.MaxAmmo)
	end
end

-- ── Spread ────────────────────────────────────────────────────────────────────

-- Returns a direction vector randomly deviated from `dir` within a cone of
-- half-angle `angleDeg` degrees. Slight center bias is intentional (more realistic).
local function applySpread(dir: Vector3, angleDeg: number): Vector3
	local rad = math.rad(angleDeg)
	local azimuth = math.random() * math.pi * 2
	local polar = math.random() * rad
	local cf = CFrame.lookAt(Vector3.zero, dir)
	return (cf * CFrame.Angles(polar * math.cos(azimuth), polar * math.sin(azimuth), 0)).LookVector
end

-- ── Core logic ────────────────────────────────────────────────────────────────

local function reload()
	if reloading or ammo >= ShotgunConfig.MaxAmmo or not equipped then return end
	reloading = true
	updateHUD()
	task.wait(ShotgunConfig.ReloadTime)
	if equipped then
		ammo = ShotgunConfig.MaxAmmo
	end
	reloading = false
	updateHUD()
end

local function fire()
	if not equipped or reloading then return end
	if ammo <= 0 then
		task.spawn(reload)
		return
	end
	local now = tick()
	if now - lastShot < ShotgunConfig.FireRate then return end
	lastShot = now

	ammo -= 1
	updateHUD()

	local character = player.Character
	if not character then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local baseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzlePos = handle and handle.Position or baseRay.Origin

	Effects.muzzleFlash(muzzlePos)
	Effects.shellCasing(handle, "shotgun")

	-- Cast each pellet with independent RNG spread
	local pelletHits = {}
	for _ = 1, ShotgunConfig.PelletCount do
		local dir = applySpread(baseRay.Direction, ShotgunConfig.SpreadAngle)
		local result = workspace:Raycast(baseRay.Origin, dir * ShotgunConfig.Range, params)
		local hitPos = result and result.Position or (baseRay.Origin + dir * ShotgunConfig.Range)

		if result then
			Effects.hitImpact(result.Position, result.Normal, result.Instance)
		end
		Effects.bulletTrail(muzzlePos, hitPos)

		pelletHits[#pelletHits + 1] = {hitPos, result and result.Instance}
	end

	Remotes.get("ShotgunFired"):FireServer(pelletHits)

	if ammo <= 0 then
		task.spawn(reload)
	end
end

local function onCharacterAdded(character)
	ammo = ShotgunConfig.MaxAmmo
	reloading = false
	equipped = false
	updateHUD()

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Shotgun" then
			equipped = true
			updateHUD()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Shotgun" then
			equipped = false
			reloading = false
			updateHUD()
		end
	end)
end

function ShotgunSystem.start()
	Effects = require(script.Parent.Parent.Util.WeaponEffects)

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			fire()
		elseif input.KeyCode == Enum.KeyCode.R then
			if equipped then task.spawn(reload) end
		end
	end)
end

return ShotgunSystem
