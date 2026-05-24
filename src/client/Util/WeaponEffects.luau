-- Shared visual-only effects for all weapon systems.
-- All functions are fire-and-forget; cleanup is handled via Debris.
-- Barricade hits also fire a server remote so the server can SubtractAsync a real hole.
local Debris            = game:GetService("Debris")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes   -- lazy-required on first barricade hit
local Effects = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function isBarricade(part: Instance): boolean
	local node = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and node.Name == "Barricade" then return true end
		node = node.Parent
	end
	return false
end

local function tween(instance: Instance, info: TweenInfo, props: {[string]: any})
	TweenService:Create(instance, info, props):Play()
end

-- ── Barricade impact ──────────────────────────────────────────────────────────

local function barricadeImpact(position: Vector3, normal: Vector3, hitPart: BasePart)
	local partColor = hitPart.Color
	local partMat   = hitPart.Material

	for _ = 1, 6 do
		local chip      = Instance.new("Part")
		chip.Size       = Vector3.new(
			math.random(3, 10) / 100,
			math.random(3, 10) / 100,
			math.random(3, 10) / 100
		)
		chip.Color      = partColor
		chip.Material   = partMat
		chip.CFrame     = CFrame.new(position + normal * 0.06)
		chip.CanCollide = false
		chip.Anchored   = false
		chip.CastShadow = false
		chip.Parent     = workspace

		local scatter = Vector3.new(
			math.random() * 2 - 1,
			math.random() * 2 - 1,
			math.random() * 2 - 1
		) * 1.6
		local dir = (normal + scatter).Unit
		chip.AssemblyLinearVelocity  = dir * math.random(6, 18)
		chip.AssemblyAngularVelocity = Vector3.new(
			math.random(-12, 12),
			math.random(-12, 12),
			math.random(-12, 12)
		)
		Debris:AddItem(chip, 0.6)
	end

	-- Tell the server to drill a real CSG hole.
	if not Remotes then
		Remotes = require(ReplicatedStorage.Shared.Remotes)
	end
	Remotes.get("BarricadeHit"):FireServer(hitPart, position, normal)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Effects.muzzleFlash(position: Vector3)
	-- Primary neon flash sphere
	local p      = Instance.new("Part")
	p.Shape      = Enum.PartType.Ball
	p.Size       = Vector3.new(0.35, 0.35, 0.35)
	p.CFrame     = CFrame.new(position)
	p.Material   = Enum.Material.Neon
	p.Color      = Color3.fromRGB(255, 200, 80)
	p.CanCollide = false
	p.Anchored   = true
	p.CastShadow = false
	p.Parent     = workspace

	-- Dynamic point light
	local light         = Instance.new("PointLight")
	light.Brightness    = 5
	light.Range         = 18
	light.Color         = Color3.fromRGB(255, 160, 60)
	light.Parent        = p
	Debris:AddItem(p, 0.06)

	-- Smoke puff: expands and fades
	local smoke  = Instance.new("Part")
	smoke.Shape  = Enum.PartType.Ball
	smoke.Size   = Vector3.new(0.15, 0.15, 0.15)
	smoke.CFrame = CFrame.new(position)
	smoke.Material = Enum.Material.SmoothPlastic
	smoke.Color  = Color3.fromRGB(180, 175, 165)
	smoke.Transparency = 0.3
	smoke.CanCollide = false
	smoke.Anchored   = true
	smoke.CastShadow = false
	smoke.Parent = workspace
	tween(smoke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.55, 0.55, 0.55),
		Transparency = 1,
	})
	Debris:AddItem(smoke, 0.26)
end

function Effects.bulletTrail(from: Vector3, to: Vector3)
	local dist = (to - from).Magnitude
	if dist < 0.1 then return end

	local p      = Instance.new("Part")
	p.Size       = Vector3.new(0.055, 0.055, dist)
	p.CFrame     = CFrame.lookAt((from + to) / 2, to)
	p.Material   = Enum.Material.Neon
	p.Color      = Color3.fromRGB(255, 230, 120)
	p.Transparency = 0
	p.CanCollide = false
	p.Anchored   = true
	p.CastShadow = false
	p.Parent     = workspace

	tween(p, TweenInfo.new(0.12, Enum.EasingStyle.Linear), { Transparency = 1 })
	Debris:AddItem(p, 0.13)
end

-- `hitPart` is optional but enables the barricade CSG drilling path.
function Effects.hitImpact(position: Vector3, normal: Vector3?, hitPart: BasePart?)
	local n = normal or Vector3.yAxis

	-- Brief white flash + impact light
	local flash      = Instance.new("Part")
	flash.Shape      = Enum.PartType.Ball
	flash.Size       = Vector3.new(0.25, 0.25, 0.25)
	flash.CFrame     = CFrame.new(position + n * 0.04)
	flash.Material   = Enum.Material.Neon
	flash.Color      = Color3.fromRGB(255, 255, 255)
	flash.CanCollide = false
	flash.Anchored   = true
	flash.CastShadow = false
	flash.Parent     = workspace

	local iLight      = Instance.new("PointLight")
	iLight.Brightness = 3
	iLight.Range      = 10
	iLight.Color      = Color3.fromRGB(255, 220, 140)
	iLight.Parent     = flash
	Debris:AddItem(flash, 0.06)

	-- Flying spark chips
	for _ = 1, 7 do
		local spark      = Instance.new("Part")
		spark.Shape      = Enum.PartType.Ball
		spark.Size       = Vector3.new(0.06, 0.06, 0.06)
		spark.CFrame     = CFrame.new(position + n * 0.04)
		spark.Material   = Enum.Material.Neon
		spark.Color      = Color3.fromRGB(255, math.random(130, 210), 20)
		spark.CanCollide = false
		spark.Anchored   = false
		spark.CastShadow = false
		spark.Parent     = workspace
		local dir = (Vector3.new(
			math.random() * 2 - 1,
			math.random() * 2 - 1,
			math.random() * 2 - 1
		) + n).Unit
		spark.AssemblyLinearVelocity = dir * math.random(7, 20)
		Debris:AddItem(spark, 0.2)
	end

	-- Dust puff: expands and fades outward from surface
	local dust   = Instance.new("Part")
	dust.Shape   = Enum.PartType.Ball
	dust.Size    = Vector3.new(0.1, 0.1, 0.1)
	dust.CFrame  = CFrame.new(position + n * 0.06)
	dust.Material = Enum.Material.SmoothPlastic
	dust.Color   = Color3.fromRGB(160, 155, 145)
	dust.Transparency = 0.4
	dust.CanCollide = false
	dust.Anchored   = true
	dust.CastShadow = false
	dust.Parent  = workspace
	tween(dust, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.45, 0.45, 0.45),
		Transparency = 1,
	})
	Debris:AddItem(dust, 0.23)

	-- Barricade: eject physical debris chips + trigger server CSG hole
	if hitPart and hitPart:IsA("BasePart") and isBarricade(hitPart) then
		barricadeImpact(position, n, hitPart)
	end
end

-- Shell casing ejected from the weapon handle.
-- shellType: "rifle" | "shotgun" | "handgun"
function Effects.shellCasing(handle: BasePart?, shellType: string?)
	if not handle then return end

	local sizes = {
		rifle   = Vector3.new(0.30, 0.065, 0.065),
		handgun = Vector3.new(0.18, 0.085, 0.085),
		shotgun = Vector3.new(0.22, 0.140, 0.140),
	}
	local size = sizes[shellType or "handgun"] or sizes.handgun

	local casing          = Instance.new("Part")
	casing.Shape          = Enum.PartType.Cylinder
	casing.Size           = size
	casing.Color          = Color3.fromRGB(185, 148, 42)
	casing.Material       = Enum.Material.Metal
	casing.Reflectance    = 0.4
	casing.CanCollide     = true
	casing.Anchored       = false
	casing.CastShadow     = false
	-- Start at handle, slightly to the right and up
	casing.CFrame         = handle.CFrame * CFrame.new(0, 0.1, -0.25)
	casing.Parent         = workspace

	-- Eject rightward + slightly upward relative to handle orientation
	local right = handle.CFrame.RightVector
	local up    = handle.CFrame.UpVector
	casing.AssemblyLinearVelocity = right * math.random(4, 7) + up * math.random(2, 4)
		+ Vector3.new(
			(math.random() - 0.5) * 1.5,
			0,
			(math.random() - 0.5) * 1.5
		)
	casing.AssemblyAngularVelocity = Vector3.new(
		math.random(-20, 20),
		math.random(-20, 20),
		math.random(-20, 20)
	)
	Debris:AddItem(casing, 4)
end

return Effects
