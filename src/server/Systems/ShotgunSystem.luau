local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotgunConfig = require(ReplicatedStorage.Shared.ShotgunConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ShotgunSystem = {}
local lastShotTime = {}

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

local function createShotgun(player)
	local tool = Instance.new("Tool")
	tool.Name = "Shotgun"
	tool.RequiresHandle = true
	tool.ToolTip = "Click to fire  |  R to reload"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 2.2)
	handle.BrickColor = BrickColor.new("Reddish brown")
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool

	tool.Parent = player.Backpack
end

local function onShotgunFired(player, pelletHits)
	local now = tick()
	if now - (lastShotTime[player] or 0) < ShotgunConfig.FireRate then return end
	lastShotTime[player] = now

	local character = player.Character
	if not character then return end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= "Shotgun" then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if typeof(pelletHits) ~= "table" then return end

	local count = math.min(#pelletHits, ShotgunConfig.PelletCount)
	local damageDealt = {}

	for i = 1, count do
		local pellet = pelletHits[i]
		if typeof(pellet) ~= "table" then continue end

		local hitPos = pellet[1]
		local hitPart = pellet[2]

		if typeof(hitPos) ~= "Vector3" then continue end
		if (hitPos - root.Position).Magnitude > ShotgunConfig.Range + 20 then continue end
		if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then continue end

		local humanoid, hitCharacter = findHumanoid(hitPart)
		if not humanoid or humanoid.Health <= 0 then continue end
		if Players:GetPlayerFromCharacter(hitCharacter) == player then continue end

		local maxDamage = ShotgunConfig.PelletCount * ShotgunConfig.PelletDamage
		if (damageDealt[humanoid] or 0) < maxDamage then
			humanoid:TakeDamage(ShotgunConfig.PelletDamage)
			damageDealt[humanoid] = (damageDealt[humanoid] or 0) + ShotgunConfig.PelletDamage
		end
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		createShotgun(player)
	end)
end

function ShotgunSystem.start()
	Remotes.get("ShotgunFired").OnServerEvent:Connect(onShotgunFired)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastShotTime[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
		if player.Character then
			createShotgun(player)
		end
	end
end

return ShotgunSystem
