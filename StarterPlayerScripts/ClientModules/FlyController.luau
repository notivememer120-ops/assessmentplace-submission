local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local runServ = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local AdminPackets = require(rep.Modules.Packets.AdminPackets)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local player = players.LocalPlayer

local toggleKey = Enum.KeyCode.F4
local flySpeed = 60
local boostMult = 3

local FlyController = {}
FlyController.__slittttName = "FlyController"

function FlyController:Init()
	self._authed = false
	self._flying = false

	AdminPackets.packets.AdminSync.listen(function(data)
		if data.kind == "authed" then
			self._authed = true
		end
	end)

	uis.InputBegan:Connect(function(input, gp)
		if gp or input.KeyCode ~= toggleKey or not self._authed then
			return
		end

		if self._flying then
			self:Stop()
		else
			self:_start()
		end
	end)
end

function FlyController:_start()
	local char = player.Character

	if not char then
		return
	end

	local root = char.HumanoidRootPart
	local hum = char.Humanoid
	local scope = Scythe.scope()

	self._flying = true
	self._scope = scope

	Scythe.add(scope, function()
		self._flying = false
		root.CanCollide = true

		if hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	local att = Instance.new("Attachment")
	att.Parent = root

	Scythe.add(scope, att)

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root

	Scythe.add(scope, lv)

	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = att
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.RigidityEnabled = true
	ao.CFrame = CFrame.lookAt(Vector3.zero, root.CFrame.LookVector)
	ao.Parent = root

	Scythe.add(scope, ao)

	hum:ChangeState(Enum.HumanoidStateType.Physics)

	Scythe.connect(scope, hum.Died, function()
		self:Stop()
	end)

	Scythe.connect(scope, player.CharacterRemoving, function()
		self:Stop()
	end)

	Scythe.connect(scope, runServ.RenderStepped, function()
		local cam = workspace.CurrentCamera
		local forward = (uis:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (uis:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
		local strafe = (uis:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (uis:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		local lift = (uis:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (uis:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
		local vec = cam.CFrame:VectorToWorldSpace(Vector3.new(strafe, 0, -forward)) + Vector3.new(0, lift, 0)

		if vec.Magnitude > 0 then
			local speed = flySpeed * (uis:IsKeyDown(Enum.KeyCode.LeftShift) and boostMult or 1)

			vec = vec.Unit * speed
		end

		lv.VectorVelocity = vec

		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)

		if flat.Magnitude > 0.05 then
			ao.CFrame = CFrame.lookAt(Vector3.zero, flat)
		end
	end)

	-- humanoid re-enables limb collisions every step, so noclip has to force
	-- them off per physics step, not once
	Scythe.connect(scope, runServ.Stepped, function()
		for i, v in char:GetDescendants() do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end
	end)
end

function FlyController:Stop()
	if self._flying then
		Scythe.destroy(self._scope)
	end
end

return FlyController