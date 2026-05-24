local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrouchConfig = require(ReplicatedStorage.Shared.CrouchConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CrouchSystem = {}

local player = Players.LocalPlayer
local isCrouching = false
local crouchRemote

local tweenInfo = TweenInfo.new(CrouchConfig.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ── HUD indicator ─────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "CrouchHUD"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local indicator = Instance.new("TextLabel")
indicator.Size = UDim2.new(0, 140, 0, 28)
indicator.AnchorPoint = Vector2.new(0.5, 0)
indicator.Position = UDim2.new(0.5, 0, 0.85, 0)
indicator.BackgroundTransparency = 1
indicator.TextColor3 = Color3.new(0.9, 0.9, 0.9)
indicator.Font = Enum.Font.Gotham
indicator.TextScaled = true
indicator.Text = "[ CROUCHING ]"
indicator.Visible = false
indicator.Parent = gui

-- ── State ─────────────────────────────────────────────────────────────────────

local function setCrouch(state)
	if isCrouching == state then return end
	isCrouching = state
	indicator.Visible = isCrouching

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local targetY = isCrouching and CrouchConfig.CameraYOffset or 0
		TweenService:Create(humanoid, tweenInfo, {
			CameraOffset = Vector3.new(0, targetY, 0),
		}):Play()
	end

	crouchRemote:FireServer(isCrouching)
end

local function onCharacterAdded(character)
	isCrouching = false
	indicator.Visible = false
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = Vector3.new(0, 0, 0)
	end
end

-- ── Bootstrap ─────────────────────────────────────────────────────────────────

function CrouchSystem.start()
	crouchRemote = Remotes.get("CrouchChanged")

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Hold Left Control to crouch
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.C then
			setCrouch(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.C then
			setCrouch(false)
		end
	end)
end

return CrouchSystem
