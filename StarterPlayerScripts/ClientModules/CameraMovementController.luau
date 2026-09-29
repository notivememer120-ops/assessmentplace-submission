--!strict
local rep = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer :: Player
local guiServ = game:GetService("GuiService")
local vrServ = game:GetService("VRService")
local uis = game:GetService("UserInputService")

local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local Motion = require(rep.Modules.Gameplay.CameraMotion)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local CameraMovementController = {}
CameraMovementController.__slittttName = "CameraMovementController"
CameraMovementController.Dependencies = {"SettingsTopbar"}

type CharacterState = {
	char: Model,
	hum: Humanoid,
	root: BasePart,
	motion: typeof(Motion.new()),
	look: Vector3?,
	position: Vector3?,
}

type Controller = typeof(CameraMovementController) & {
	_scope: Scythe.Scope,
	_applied: {
		camera: Camera,
		base: CFrame,
		frame: CFrame,
		restFov: number,
		fov: number,
	}?,
	Get: (Controller, "SettingsTopbar") -> typeof(require(script.Parent.SettingsTopbar)),
}

function CameraMovementController._restore(self: Controller)
	local applied = self._applied

	if not applied then return end

	self._applied = nil

	if applied.camera.CFrame == applied.frame then
		applied.camera.CFrame = applied.base
	end

	if applied.camera.FieldOfView == applied.fov then
		applied.camera.FieldOfView = applied.restFov
	end
end

function CameraMovementController.Init(self: Controller)
	self._scope = Scythe.scope()

	Scythe.add(self._scope, function() self:_restore() end)

	local characterScope = Scythe.extend(self._scope)
	local settings = self:Get("SettingsTopbar")
	local current: CharacterState?

	local function characterChanged()
		self:_restore()

		current = nil

		Scythe.clean(characterScope)

		local char = player.Character

		if not char then return end

		Scythe.add(characterScope, task.defer(function()
			local hum = WaitFor:get(char, "Humanoid") :: Humanoid
			local root = WaitFor:get(char, "HumanoidRootPart") :: BasePart

			if char ~= player.Character then return end

			current = {char = char, hum = hum, root = root, motion = Motion.new()}
		end))
	end

	Scythe.connect(self._scope, player:GetPropertyChangedSignal("Character"), characterChanged)
	Scythe.connect(self._scope, workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		self:_restore()

		if current then
			current.motion:Reset()
			current.look = nil
		end
	end)

	characterChanged()
	Scythe.bindToRenderStep(self._scope, "CameraMovementReset", Enum.RenderPriority.Camera.Value - 1, function()
		self:_restore()
	end)

	Scythe.bindToRenderStep(self._scope, "CameraMovementController", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local state = current

		if not state or state.char ~= player.Character then return end

		local camera = workspace.CurrentCamera :: Camera
		local hum = state.hum
		local root = state.root
		local enabled = settings:GetValue("cameraMovement") and not guiServ.ReducedMotionEnabled and not vrServ.VREnabled
			and not ModalGuard.anyOpen() and not guiServ.MenuIsOpen
			and hum.Health > 0 and not hum.Sit and not hum.PlatformStand and root:IsDescendantOf(workspace)
			and camera.CameraType == Enum.CameraType.Custom and camera.CameraSubject == hum

		if not enabled then
			state.motion:Reset()
			state.look = nil
			state.position = nil
			return
		end

		local frame = camera.CFrame
		local velocity = root.AssemblyLinearVelocity

		if state.position and (root.Position - state.position).Magnitude > math.max(12, velocity.Magnitude * dt * 3) then
			state.motion:Reset()
			state.look = nil
		end

		state.position = root.Position

		local turn = 0

		if state.look and dt > 0 then
			local delta = frame:VectorToObjectSpace(state.look)

			turn = math.clamp(math.atan2(delta.X, -delta.Z) / dt, -3, 3)
		end

		state.look = frame.LookVector

		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local side = flat:Dot(frame.RightVector)
		local localVelocity = Vector3.new(side, 0, math.sqrt(math.max(0, flat:Dot(flat) - side * side)))

		if hum.MoveDirection.Magnitude < 0.1 then localVelocity = Vector3.zero end

		localVelocity = Vector3.new(localVelocity.X, velocity.Y, localVelocity.Z)

		local weight = if (camera.Focus.Position - frame.Position).Magnitude < 1 then 1 else 0.65

		if uis.PreferredInput == Enum.PreferredInput.Touch then weight *= 0.8 end

		local offset
		local fov

		offset, fov = state.motion:Step(dt, localVelocity, hum.FloorMaterial ~= Enum.Material.Air, player:GetAttribute("sprinting") :: boolean?, turn, weight)

		local restFov = camera.FieldOfView

		camera.CFrame = frame * offset
		camera.FieldOfView = math.min(restFov + fov, 120)
		self._applied = {camera = camera, base = frame, frame = camera.CFrame, restFov = restFov, fov = camera.FieldOfView}
	end)
end

function CameraMovementController.Destroy(self: Controller)
	Scythe.destroy(self._scope)
end

return CameraMovementController
