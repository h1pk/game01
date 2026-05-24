local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local BarricadeSystem = {}

-- Parts currently mid-SubtractAsync — ignore duplicate hits on the same part.
local processing = {} :: {[BasePart]: true}

-- Total holes drilled per Barricade model. Stops geometry getting absurdly complex.
local holeCount  = {} :: {[Model]: number}
local MAX_HOLES  = 12

-- Cylinder drill dimensions (studs).
local DRILL_DIAMETER = 0.28
local DRILL_LENGTH   = 1.4   -- long enough to punch through typical barricade thickness

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getBarricadeModel(part: Instance): Model?
	local node = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and node.Name == "Barricade" then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end

-- CFrame at `pos` where the local X axis (cylinder length) points along `axis`.
local function cylinderCFrame(pos: Vector3, axis: Vector3): CFrame
	local x   = axis.Unit
	local ref = if math.abs(x:Dot(Vector3.yAxis)) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local y   = ref:Cross(x).Unit
	local z   = x:Cross(y)
	return CFrame.fromMatrix(pos, x, y, z)
end

-- ── Core drill ────────────────────────────────────────────────────────────────

local function drill(hitPart: BasePart, hitPosition: Vector3, normal: Vector3, barricade: Model)
	-- Only Part and UnionOperation support SubtractAsync.
	if not (hitPart:IsA("Part") or hitPart:IsA("UnionOperation")) then
		return
	end
	if processing[hitPart] then return end
	processing[hitPart] = true

	-- Cylinder drill bit: length runs along the surface normal, centred just
	-- inside the surface so it punches fully through.
	local drill = Instance.new("Part")
	drill.Shape     = Enum.PartType.Cylinder
	drill.Size      = Vector3.new(DRILL_LENGTH, DRILL_DIAMETER, DRILL_DIAMETER)
	drill.CFrame    = cylinderCFrame(hitPosition - normal * (DRILL_LENGTH * 0.3), normal)
	drill.Anchored  = true
	drill.CanCollide = false
	drill.Parent    = workspace

	local ok, result = pcall(function()
		return hitPart:SubtractAsync(
			{ drill },
			Enum.CollisionFidelity.Box,          -- fast server-side collision
			Enum.RenderFidelity.Automatic        -- clients render at automatic fidelity
		)
	end)

	drill:Destroy()
	processing[hitPart] = nil

	if not ok or not result then
		-- SubtractAsync failed (e.g. drill didn't intersect, or mesh type unsupported).
		holeCount[barricade] = math.max(0, (holeCount[barricade] or 1) - 1)
		if not ok then
			warn("[BarricadeSystem] SubtractAsync error:", result)
		end
		return
	end

	-- Preserve the original part's properties on the new UnionOperation.
	result.Name      = hitPart.Name
	result.Anchored  = hitPart.Anchored
	result.CanCollide = hitPart.CanCollide
	result.Parent    = hitPart.Parent

	hitPart:Destroy()
end

-- ── Remote handler ────────────────────────────────────────────────────────────

local function onBarricadeHit(_, hitPart, hitPosition, normal)
	-- Basic type guards — data comes from untrusted clients.
	if typeof(hitPart)     ~= "Instance" then return end
	if not hitPart:IsA("BasePart")       then return end
	if typeof(hitPosition) ~= "Vector3"  then return end
	if typeof(normal)      ~= "Vector3"  then return end

	local barricade = getBarricadeModel(hitPart)
	if not barricade then return end

	local count = holeCount[barricade] or 0
	if count >= MAX_HOLES then return end
	holeCount[barricade] = count + 1

	-- Run async so the server event handler returns immediately.
	task.spawn(drill, hitPart, hitPosition, normal, barricade)
end

function BarricadeSystem.start()
	Remotes.get("BarricadeHit").OnServerEvent:Connect(onBarricadeHit)
end

return BarricadeSystem
