local RunService = game:GetService("RunService")
local PostSim: RBXScriptSignal = RunService.PostSimulation

-- Modern hookfunction wrapper check
local hookfunction = hookfunction or (hookmetamethod and function(f: any, h: any) return hookfunction(f, h) end)

if not hookfunction then
	warn("[No Cooldown] Executor does not support 'hookfunction'. Yield accelerator hook inactive.")
	return
end

-- Sync with environment flag if available
if getgenv then
	getgenv().SpeedEngineEnabled = true
end

-- Faster yields using PostSimulation
local function fastYield(): number
	return PostSim:Wait()
end

-- Inline wrapper to immediately spawn functions without redundant closure creation
local function immediateSpawn(duration: number?, func: (...any) -> (), ...: any): thread?
	if type(func) == "function" then
		return task.spawn(func, ...)
	end
	return nil
end

-- ================================================================
-- PERMANENT SPEED HOOKS (ALWAYS ON)
-- ================================================================
hookfunction(task.wait, function(duration: number?): number
	return fastYield()
end)

hookfunction(task.delay, function(duration: number?, func: (...any) -> (), ...: any): thread?
	return immediateSpawn(duration, func, ...)
end)

if getgenv and getgenv().wait then
	hookfunction(getgenv().wait, function(duration: number?): number
		return fastYield()
	end)
end

if getgenv and getgenv().delay then
	hookfunction(getgenv().delay, function(duration: number?, func: (...any) -> (), ...: any): thread?
		return immediateSpawn(duration, func, ...)
	end)
end

if getgenv and getgenv().spawn then
	hookfunction(getgenv().spawn, function(func: (...any) -> (), ...: any): thread?
		return immediateSpawn(0, func, ...)
	end)
end

print("[No Cooldown] CIPHER // NO COOLDOWN MAX-SPEED HOOK ENGINE V4.1 Loaded (Always On // Zero UI).")
