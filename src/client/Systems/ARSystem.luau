local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ARConfig = require(ReplicatedStorage.Shared.ARConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ARSystem = {}
local Effects  -- lazy-required inside start()

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local equipped = false
local ammo = ARConfig.MaxAmmo
local reloading = false
local firing = false   -- true while mouse is held

-- ── HUD ──────────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "ARHUD"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local ammoFrame = Instance.new("Frame")
ammoFrame.Size = UDim2.new(0, 175, 0, 44)
ammoFrame.Position = UDim2.new(1, -185, 1, -60)
ammoFrame.BackgroundColor3 = Color3.new(0, 0, 0)
ammoFrame.BackgroundTransparency = 0.45
ammoFrame.BorderSizePixel = 0
ammoFrame.Visible = false
ammoFrame.Parent = gui

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.new(1, 0, 1, 0)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
ammoLabel.TextScaled = true
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.Text = ""
ammoLabel.Parent = ammoFrame

-- Tight dot crosshair (AR sights feel precise)
local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.new(0, 16, 0, 16)
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
	line.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
	line.BorderSizePixel = 0
	line.Parent = crosshair
end
makeLine(UDim2.new(0, 2, 0, 10), UDim2.new(0.5, 0, 0.5, 0))
makeLine(UDim2.new(0, 10, 0, 2), UDim2.new(0.5, 0, 0.5, 0))

local function updateHUD()
	crosshair.Visible = equipped
	ammoFrame.Visible = equipped
	if equipped then
		ammoLabel.Text = reloading and "Reloading..." or ("AR  " .. ammo .. " / " .. ARConfig.MaxAmmo)
	end
end

-- ── Core logic ────────────────────────────────────────────────────────────────

local function reload()
	if reloading or ammo >= ARConfig.MaxAmmo or not equipped then return end
	reloading = true
	updateHUD()
	task.wait(ARConfig.ReloadTime)
	if equipped then
		ammo = ARConfig.MaxAmmo
	end
	reloading = false
	updateHUD()
end

-- Fires one bullet — called repeatedly by the auto-fire loop.
local function fire()
	if not equipped or reloading or ammo <= 0 then return end

	ammo -= 1
	updateHUD()

	local character = player.Character
	if not character then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * ARConfig.Range, params)

	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzlePos = handle and handle.Position or ray.Origin

	local hitPos = result and result.Position or (ray.Origin + ray.Direction * ARConfig.Range)

	Effects.muzzleFlash(muzzlePos)
	Effects.bulletTrail(muzzlePos, hitPos)
	Effects.shellCasing(handle, "rifle")
	if result then
		Effects.hitImpact(result.Position, result.Normal, result.Instance)
	end

	Remotes.get("ARFired"):FireServer(hitPos, result and result.Instance)
end

-- Full-auto loop: runs while mouse is held and gun is equipped.
local function startFiring()
	if firing then return end
	firing = true
	while firing and equipped do
		if reloading then
			task.wait(0.05)
			continue
		end
		if ammo <= 0 then
			task.spawn(reload)
			break
		end
		fire()
		task.wait(ARConfig.FireRate)
	end
	firing = false
end

local function onCharacterAdded(character)
	ammo = ARConfig.MaxAmmo
	reloading = false
	equipped = false
	firing = false
	updateHUD()

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "AssaultRifle" then
			equipped = true
			updateHUD()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == "AssaultRifle" then
			equipped = false
			firing = false
			reloading = false
			updateHUD()
		end
	end)
end

function ARSystem.start()
	Effects = require(script.Parent.Parent.Util.WeaponEffects)

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and equipped then
			task.spawn(startFiring)
		elseif input.KeyCode == Enum.KeyCode.R then
			if equipped then task.spawn(reload) end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		end
	end)
end

return ARSystem
