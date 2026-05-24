local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrouchConfig = require(ReplicatedStorage.Shared.CrouchConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CrouchSystem = {}
local characterData = {}

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	characterData[character] = {
		baseHipHeight = humanoid.HipHeight,
		baseWalkSpeed = humanoid.WalkSpeed,
	}

	-- Clean up when the character is removed from the workspace
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			characterData[character] = nil
		end
	end)
end

local function onCrouchChanged(player, isCrouching)
	if typeof(isCrouching) ~= "boolean" then return end
	local character = player.Character
	if not character then return end
	local data = characterData[character]
	if not data then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if isCrouching then
		humanoid.WalkSpeed = CrouchConfig.CrouchSpeed
		-- Clamp to 0 so character never clips below ground
		humanoid.HipHeight = math.max(0, data.baseHipHeight + CrouchConfig.HipHeightDelta)
	else
		humanoid.WalkSpeed = data.baseWalkSpeed
		humanoid.HipHeight = data.baseHipHeight
	end
end

function CrouchSystem.start()
	Remotes.get("CrouchChanged").OnServerEvent:Connect(onCrouchChanged)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(onCharacterAdded)
	end)

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end
	end
end

return CrouchSystem
