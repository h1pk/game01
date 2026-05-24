local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunConfig = require(ReplicatedStorage.Shared.GunConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GunSystem = {}
local lastShotTime = {}

-- Walk up the Part's ancestry until we find a Model that owns a Humanoid.
-- Stops at the Workspace root. Handles Accessories (also Models) correctly.
local function findHumanoid(part)
	local ancestor = part.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Model") then
			local h = ancestor:FindFirstChildOfClass("Humanoid")
			if h then return h, ancestor end
		end
		ancestor = ancestor.Parent
	end
	return nil, nil
end

local function createGun(player)
	local tool = Instance.new("Tool")
	tool.Name = "Gun"
	tool.RequiresHandle = true
	tool.ToolTip = "Click to fire  |  R to reload"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.5)
	handle.BrickColor = BrickColor.new("Dark grey")
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	tool.Parent = player.Backpack
end

local function onFired(player, hitPosition, hitPart)
	local now = tick()
	if now - (lastShotTime[player] or 0) < GunConfig.FireRate then return end
	lastShotTime[player] = now

	local character = player.Character
	if not character then return end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= "Gun" then return end

	if typeof(hitPosition) ~= "Vector3" then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (hitPosition - root.Position).Magnitude > GunConfig.Range + 20 then return end

	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then return end

	local humanoid, hitCharacter = findHumanoid(hitPart)
	if not humanoid or humanoid.Health <= 0 then return end
	if Players:GetPlayerFromCharacter(hitCharacter) == player then return end

	humanoid:TakeDamage(GunConfig.Damage)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		createGun(player)
	end)
end

function GunSystem.start()
	Remotes.get("GunFired").OnServerEvent:Connect(onFired)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastShotTime[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
		if player.Character then
			createGun(player)
		end
	end
end

return GunSystem
