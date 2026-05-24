local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes must exist before any system calls Remotes.get()
local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.init()

for _, module in script:WaitForChild("Systems"):GetChildren() do
	if module:IsA("ModuleScript") then
		task.spawn(function()
			local ok, err = pcall(function()
				require(module).start()
			end)
			if not ok then
				warn("[Server] System '" .. module.Name .. "' failed to start: " .. tostring(err))
			end
		end)
	end
end
