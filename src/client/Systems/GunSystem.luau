local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunConfig = require(ReplicatedStorage.Shared.GunConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GunSystem = {}
local Effects  -- required lazily inside start() so a missing Util folder doesn't kill the module

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local equipped = false
local ammo = GunConfig.MaxAmmo
local reloading = false
local lastShot = 0

-- ── HUD ──────────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "GunHUD"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local ammoFrame = Instance.new("Frame")
ammoFrame.Size = UDim2.new(0, 160, 0, 44)
ammoFrame.Position = UDim2.new(1, -170, 1, -60)
ammoFrame.BackgroundColor3 = Color3.new(0, 0, 0)
ammoFrame.BackgroundTransparency = 0.45
ammoFrame.BorderSizePixel = 0
ammoFrame.Visible = false
ammoFrame.Parent = gui

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.new(1, 0, 1, 0)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3 = Color3.new(1, 1, 1)
ammoLabel.TextScaled = true
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.Text = ""
ammoLabel.Parent = ammoFrame

local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.new(0, 20, 0, 20)
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
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.Parent = crosshair
end
makeLine(UDim2.new(0, 2, 0, 14), UDim2.new(0.5, 0, 0.5, 0))
makeLine(UDim2.new(0, 14, 0, 2), UDim2.new(0.5, 0, 0.5, 0))

local function updateHUD()
	crosshair.Visible = equipped
	ammoFrame.Visible = equipped
	if equipped then
		ammoLabel.Text = reloading and "Reloading..." or (ammo .. " / " .. GunConfig.MaxAmmo)
	end
end

-- ── Core logic ────────────────────────────────────────────────────────────────

local function reload()
	if reloading or ammo >= GunConfig.MaxAmmo or not equipped then return end
	reloading = true
	updateHUD()
	task.wait(GunConfig.ReloadTime)
	if equipped then
		ammo = GunConfig.MaxAmmo
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
	if now - lastShot < GunConfig.FireRate then return end
	lastShot = now

	ammo -= 1
	updateHUD()

	local character = player.Character
	if not character then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * GunConfig.Range, params)

	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzlePos = handle and handle.Position or ray.Origin

	local hitPos = result and result.Position or (ray.Origin + ray.Direction * GunConfig.Range)

	Effects.muzzleFlash(muzzlePos)
	Effects.bulletTrail(muzzlePos, hitPos)
	Effects.shellCasing(handle, "handgun")
	if result then
		Effects.hitImpact(result.Position, result.Normal, result.Instance)
	end

	Remotes.get("GunFired"):FireServer(hitPos, result and result.Instance)

	if ammo <= 0 then
		task.spawn(reload)
	end
end

local function onCharacterAdded(character)
	ammo = GunConfig.MaxAmmo
	reloading = false
	equipped = false
	updateHUD()

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Gun" then
			equipped = true
			updateHUD()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Gun" then
			equipped = false
			reloading = false
			updateHUD()
		end
	end)
end

function GunSystem.start()
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

return GunSystem
