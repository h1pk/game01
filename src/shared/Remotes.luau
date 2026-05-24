-- Central registry for all RemoteEvents.
-- Server calls Remotes.init() once on startup.
-- All callers use Remotes.get(name) — yields until the folder/remote exists.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"
local NAMES = {
	"GunFired",
	"ShotgunFired",
	"ARFired",
	"CrouchChanged",
	"BarricadeHit",
}

local Remotes = {}
local folder
local cache = {}

function Remotes.init()
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		cache[name] = remote
	end
end

function Remotes.get(name: string): RemoteEvent
	if cache[name] then return cache[name] end
	if not folder then
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
	end
	cache[name] = folder:WaitForChild(name, 10) :: RemoteEvent
	return cache[name]
end

return Remotes
