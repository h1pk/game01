local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ARConfig = require(ReplicatedStorage.Shared.ARConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ARSystem = {}
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

-- ── Model builder ─────────────────────────────────────────────────────────────

local function weld(handle, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = part
	w.Parent = handle
end

local function makePart(tool, handle, name, size, color, material, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.BrickColor = BrickColor.new(color)
	p.Material = Enum.Material[material]
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = handle.CFrame * offset
	p.Parent = tool
	weld(handle, p)
	return p
end

local function createAssaultRifle(player)
	local tool = Instance.new("Tool")
	tool.Name = "AssaultRifle"
	tool.RequiresHandle = true
	tool.ToolTip = "Hold to fire  |  R to reload"
	-- Hand grips at the pistol-grip area (behind and below the receiver centre)
	tool.GripPos = Vector3.new(0, 0.12, 0.3)

	-- ── Handle (lower receiver / grip) ────────────────────────────────────────
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.52, 0.95)
	handle.BrickColor = BrickColor.new("Dark grey metallic")
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	-- ── Upper receiver ────────────────────────────────────────────────────────
	makePart(tool, handle, "UpperReceiver",
		Vector3.new(0.28, 0.22, 0.95),
		"Black", "Metal",
		CFrame.new(0, 0.37, 0))

	-- ── Barrel ───────────────────────────────────────────────────────────────
	makePart(tool, handle, "Barrel",
		Vector3.new(0.1, 0.1, 1.8),
		"Black", "Metal",
		CFrame.new(0, 0.28, -1.35))

	-- ── Handguard (around barrel, KeyFrame rails) ─────────────────────────────
	makePart(tool, handle, "Handguard",
		Vector3.new(0.28, 0.28, 0.95),
		"Dark grey", "SmoothPlastic",
		CFrame.new(0, 0.28, -0.85))

	-- ── Muzzle device (flash hider) ──────────────────────────────────────────
	makePart(tool, handle, "MuzzleDevice",
		Vector3.new(0.16, 0.16, 0.22),
		"Black", "Metal",
		CFrame.new(0, 0.28, -2.35))

	-- ── Stock ─────────────────────────────────────────────────────────────────
	makePart(tool, handle, "Stock",
		Vector3.new(0.22, 0.28, 0.9),
		"Dark grey metallic", "Metal",
		CFrame.new(0, 0.1, 0.93))

	-- ── Stock cheekrest ───────────────────────────────────────────────────────
	makePart(tool, handle, "Cheekrest",
		Vector3.new(0.2, 0.14, 0.45),
		"Dark grey metallic", "Metal",
		CFrame.new(0, 0.34, 0.83))

	-- ── Pistol grip ───────────────────────────────────────────────────────────
	makePart(tool, handle, "PistolGrip",
		Vector3.new(0.22, 0.5, 0.26),
		"Dark grey metallic", "Metal",
		CFrame.new(0, -0.35, 0.2) * CFrame.Angles(math.rad(14), 0, 0))

	-- ── Magazine ──────────────────────────────────────────────────────────────
	makePart(tool, handle, "Magazine",
		Vector3.new(0.24, 0.72, 0.28),
		"Black", "Metal",
		CFrame.new(0, -0.58, -0.08) * CFrame.Angles(math.rad(-4), 0, 0))

	-- ── Scope rail ────────────────────────────────────────────────────────────
	makePart(tool, handle, "ScopeRail",
		Vector3.new(0.12, 0.06, 0.75),
		"Dark grey", "Metal",
		CFrame.new(0, 0.52, -0.22))

	-- ── Scope body ────────────────────────────────────────────────────────────
	makePart(tool, handle, "ScopeBody",
		Vector3.new(0.14, 0.2, 0.65),
		"Black", "Metal",
		CFrame.new(0, 0.67, -0.22))

	-- ── Scope front lens (neon green tint for visual flair) ───────────────────
	makePart(tool, handle, "ScopeLens",
		Vector3.new(0.1, 0.1, 0.04),
		"Bright green", "Neon",
		CFrame.new(0, 0.67, -0.56))

	-- ── Charging handle ───────────────────────────────────────────────────────
	makePart(tool, handle, "ChargingHandle",
		Vector3.new(0.08, 0.08, 0.22),
		"Dark grey", "Metal",
		CFrame.new(0.2, 0.37, 0.3))

	tool.Parent = player.Backpack
end

-- ── Damage handler ────────────────────────────────────────────────────────────

local function onFired(player, hitPosition, hitPart)
	local now = tick()
	if now - (lastShotTime[player] or 0) < ARConfig.FireRate then return end
	lastShotTime[player] = now

	local character = player.Character
	if not character then return end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= "AssaultRifle" then return end

	if typeof(hitPosition) ~= "Vector3" then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (hitPosition - root.Position).Magnitude > ARConfig.Range + 20 then return end

	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then return end

	local humanoid, hitCharacter = findHumanoid(hitPart)
	if not humanoid or humanoid.Health <= 0 then return end
	if Players:GetPlayerFromCharacter(hitCharacter) == player then return end

	humanoid:TakeDamage(ARConfig.Damage)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		createAssaultRifle(player)
	end)
end

function ARSystem.start()
	Remotes.get("ARFired").OnServerEvent:Connect(onFired)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastShotTime[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
		if player.Character then
			createAssaultRifle(player)
		end
	end
end

return ARSystem
