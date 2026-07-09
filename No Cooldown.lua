-- TFL No Cooldown
-- Instant execution hooks for maximum speed

local RunService = game:GetService("RunService")

--================================================
-- TFL GLOBAL COOLDOWN BREAKER
--================================================
local function hookWait()
	if hookfunction and typeof(hookfunction) == "function" then
		pcall(function()
			hookfunction(wait, function()
				return RunService.PostSimulation:Wait()
			end)
		end)
	end
end

local function hookTaskWait()
	if hookfunction and typeof(hookfunction) == "function" then
		pcall(function()
			hookfunction(task.wait, function()
				return RunService.PostSimulation:Wait()
			end)
		end)
	end
end

local function hookDelay()
	if hookfunction and typeof(hookfunction) == "function" then
		pcall(function()
			hookfunction(delay, function(_,func)
				task.spawn(func)
			end)
		end)
	end
end

local function hookSpawn()
	if hookfunction and typeof(hookfunction) == "function" then
		pcall(function()
			hookfunction(spawn, function(func)
				task.spawn(func)
			end)
		end)
	end
end

-- Apply hooks
hookWait()
hookTaskWait()
hookDelay()
hookSpawn()

print("⚡ TFL No Cooldown Running")