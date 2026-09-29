--!strict
local cas = game:GetService("ContextActionService")
local players = game:GetService("Players")
local runServ = game:GetService("RunService")

local player = players.LocalPlayer :: Player

local InputLock = {}

local lockAction = "cutsceneInputLock"
local locked = false

type Controls = {Disable: (Controls) -> (), Enable: (Controls) -> ()}

local controls: Controls?
local driver: RBXScriptConnection?
local humanoid: Humanoid?
local jumpWasEnabled: boolean?

local function sink()
	return Enum.ContextActionResult.Sink
end

local function getControls(): Controls
	if not controls then
		local loadModule = require :: (ModuleScript) -> {GetControls: (any) -> Controls}

		controls = loadModule(player.PlayerScripts:WaitForChild("PlayerModule") :: ModuleScript):GetControls()
	end

	return controls :: Controls
end

function InputLock.lock(hum: Humanoid)
	if locked then
		warn("InputLock.lock called while already locked, ignoring the second call")

		return
	end

	locked = true
	humanoid = hum
	jumpWasEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Jumping)

	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	getControls():Disable()

	cas:BindActionAtPriority(lockAction, sink, false, Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump)

	driver = runServ.PreSimulation:Connect(function()
		hum:Move(Vector3.zero)
		hum.Jump = false
	end)
end

function InputLock.release()
	if not locked then
		return
	end

	locked = false

	(driver :: RBXScriptConnection):Disconnect()

	driver = nil

	local hum = humanoid :: Humanoid
	hum.Jump = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpWasEnabled :: boolean)

	humanoid = nil

	cas:UnbindAction(lockAction)
	getControls():Enable()
end

return InputLock