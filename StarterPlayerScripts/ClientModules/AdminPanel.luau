--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Iris = require(ReplicatedStorage.Modules.Imported.Frontend.Iris)
local AdminPackets = require(ReplicatedStorage.Modules.Packets.AdminPackets)
local StatFields = require(ReplicatedStorage.Modules.Configs.StatFieldsConfig)
local Gamepasses = require(ReplicatedStorage.Modules.Configs.Monetization.Gamepasses)
local NotificationHandler = require(ReplicatedStorage.Modules.Imported.Frontend.NotificationHandler)

local AdminPanel = {}

AdminPanel.__slittttName = "AdminPanel"
AdminPanel.Dependencies = {}

local localPlayer = Players.LocalPlayer :: Player
local windowOpen: typeof(Iris.State(false))
local windowSize: typeof(Iris.State(Vector2.zero))
local windowPos: typeof(Iris.State(Vector2.zero))
local authed = false
local bansList: {{userId: number, reason: string?}} = {}

local selfBlockGui: ScreenGui
local selfBlockLabel: TextLabel
local clickTpState: typeof(Iris.State(false))

local function teleportToMouse()
	local char = localPlayer.Character

	if not char then
		return
	end

	local humanoid = char:FindFirstChild("Humanoid") :: Humanoid
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart

	if humanoid.SeatPart then
		local seat = humanoid.SeatPart

		humanoid.Sit = false

		local weld = seat:FindFirstChild("SeatWeld")

		if weld then
			weld:Destroy()
		end
	end

	local hit = localPlayer:GetMouse().Hit.Position
	local rootPos = root.Position
	local hipHeight = humanoid.HipHeight > 0 and humanoid.HipHeight + 1 or 4

	root.CFrame = CFrame.new(hit, Vector3.new(rootPos.X, hit.Y, rootPos.Z)) * CFrame.Angles(0, math.pi, 0) + Vector3.new(0, hipHeight, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local konamiSeq = {
	Enum.KeyCode.Up, Enum.KeyCode.Up,
	Enum.KeyCode.Down, Enum.KeyCode.Down,
	Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.B, Enum.KeyCode.A,
}
local konamiIndex = 1
local dangerousUnlocked = false

local opcodes = {"set", "add", "deduct", "null"}

local passKeys = Gamepasses.GetAllPassNames()

local function recenterWindow()
	local v = (workspace.CurrentCamera :: Camera).ViewportSize
	local w = math.floor(v.X * 0.5)
	local h = math.floor(v.Y * 0.5)
	
	windowSize:set(Vector2.new(w, h))
	windowPos:set(Vector2.new((v.X - w) * 0.5, (v.Y - h) * 0.5))
end

local function send(action: string, args: {[string]: unknown}?)
	AdminPackets.packets.AdminReq.send({
		action = action,
		payload = HttpService:JSONEncode(args or {}),
	})
end

local function isSelf(userId: number)
	return tonumber(userId) == localPlayer.UserId
end

local function selfBlocked(userId: number)
	return isSelf(userId) and not dangerousUnlocked
end

local function ensureSelfBlockModal()
	if selfBlockGui then
		return
	end

	selfBlockGui = Instance.new("ScreenGui")
	selfBlockGui.Name = "AdminSelfBlockModal"
	selfBlockGui.ResetOnSpawn = false
	selfBlockGui.IgnoreGuiInset = true
	selfBlockGui.DisplayOrder = 999999
	selfBlockGui.Enabled = false
	selfBlockGui.Parent = localPlayer:WaitForChild("PlayerGui")

	local bg = Instance.new("Frame")
	bg.Name = "Backdrop"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	bg.Parent = selfBlockGui

	selfBlockLabel = Instance.new("TextLabel")
	selfBlockLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	selfBlockLabel.Position = UDim2.fromScale(0.5, 0.45)
	selfBlockLabel.Size = UDim2.fromOffset(600, 80)
	selfBlockLabel.BackgroundTransparency = 1
	selfBlockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	selfBlockLabel.Font = Enum.Font.GothamMedium
	selfBlockLabel.TextSize = 24
	selfBlockLabel.TextWrapped = true
	selfBlockLabel.Parent = bg

	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.55)
	btn.Size = UDim2.fromOffset(160, 44)
	btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 18
	btn.Text = "sorry"
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Parent = bg

	btn.MouseButton1Click:Connect(function()
		selfBlockGui.Enabled = false
	end)
end

local function notifySelfBlock(action: string)
	ensureSelfBlockModal()

	selfBlockLabel.Text = `u can't {action} urself silly :3`
	selfBlockGui.Enabled = true
end

local function buildUI()
	local statStates: {[number]: {
		field: typeof(Iris.State("")),
		op: typeof(Iris.State("")),
		value: typeof(Iris.State("")),
		banReason: typeof(Iris.State("")),
		pass: typeof(Iris.State("")),
	}} = {}

	local function ensureStatState(uid: number)
		if not statStates[uid] then
			statStates[uid] = {
				field = Iris.State("cash"),
				op = Iris.State("add"),
				value = Iris.State("0"),
				banReason = Iris.State("banned by admin"),
				pass = Iris.State(passKeys[1] or ""),
			}
		end

		return statStates[uid]
	end

	local manualBanId = Iris.State(0)
	local manualBanReason = Iris.State("banned by admin")

	clickTpState = Iris.State(false)

	Iris:Connect(function()
		Iris.Window({"admin panel"}, {isOpened = windowOpen, size = windowSize, position = windowPos})

		if not windowOpen.value then
			Iris.End()
			return
		end

		if not authed then
			Iris.Text({"u shouldn't be able to see this..."})
			Iris.End()
			return
		end

		Iris.TabBar()
		Iris.Tab({"players"})

		for _, plr in Players:GetPlayers() do
			local st = ensureStatState(plr.UserId)

			Iris.PushId(tostring(plr.UserId))

			Iris.CollapsingHeader({`{plr.Name} ({plr.UserId})`})

			Iris.SameLine()

			if Iris.Button({"kick"}).clicked() then
				if selfBlocked(plr.UserId) then
					notifySelfBlock("kick")
				else
					send("kick", {userId = plr.UserId, reason = "kicked by admin"})
				end
			end

			if Iris.Button({"ban"}).clicked() then
				if selfBlocked(plr.UserId) then
					notifySelfBlock("ban")
				else
					send("ban", {userId = plr.UserId, reason = st.banReason:get()})
				end
			end

			if Iris.Button({"wipe data"}).clicked() then
				send("wipeData", {userId = plr.UserId})
			end

			if Iris.Button({"bring"}).clicked() then
				send("bring", {userId = plr.UserId})
			end

			if Iris.Button({"tp to"}).clicked() then
				send("teleportTo", {userId = plr.UserId})
			end

			Iris.End()

			Iris.InputText({"ban reason"}, {text = st.banReason})

			Iris.Text({"stats:"})
			Iris.ComboArray({"field"}, {index = st.field}, StatFields.AdminFields)
			Iris.ComboArray({"op"}, {index = st.op}, opcodes)
			Iris.InputText({"value"}, {text = st.value})

			if Iris.Button({"apply stat"}).clicked() then
				send("stat", {
					userId = plr.UserId,
					field = st.field:get(),
					op = st.op:get(),
					value = st.value:get(),
				})
			end

			Iris.Separator()
			Iris.Text({"passes:"})

			if #passKeys > 0 then
				Iris.ComboArray({"pass"}, {index = st.pass}, passKeys)
				Iris.SameLine()

				if Iris.Button({"grant pass"}).clicked() then
					send("grantPass", {userId = plr.UserId, key = st.pass:get()})
				end

				if Iris.Button({"revoke pass"}).clicked() then
					send("revokePass", {userId = plr.UserId, key = st.pass:get()})
				end

				Iris.End()
			else
				Iris.Text({"No gamepasses configured"})
			end

			Iris.End()
			Iris.PopId()
		end

		Iris.End()
		Iris.Tab({"bans"})

		Iris.InputNum({"userid", 1, 0, 1e12, "%d", true}, {number = manualBanId})
		Iris.InputText({"reason"}, {text = manualBanReason})
		Iris.SameLine()
		
		if Iris.Button({"ban userid"}).clicked() then
			if selfBlocked(manualBanId:get()) then
				notifySelfBlock("ban")
			else
				send("ban", {userId = manualBanId:get(), reason = manualBanReason:get()})
			end
		end

		if Iris.Button({"unban userid"}).clicked() then
			send("unban", {userId = manualBanId:get()})
		end

		Iris.End()

		Iris.Separator()
		Iris.Text({`banned ({#bansList}):`})
		
		for _, entry in bansList do
			Iris.PushId("ban_" .. tostring(entry.userId))
			Iris.Text({`{entry.userId}: {entry.reason or ""}`})
			Iris.SameLine()
			
			if Iris.Button({"unban"}).clicked() then
				send("unban", {userId = entry.userId})
			end

			Iris.End()
			Iris.PopId()
		end

		Iris.End()
		Iris.Tab({"misc"})

		Iris.Checkbox({"t to teleport to mouse"}, {isChecked = clickTpState})
		Iris.Separator()

		Iris.End()
		Iris.Tab({"info"})

		Iris.CollapsingHeader({"players tab"})
		Iris.Text({"- kick = regular kick with reason", true})
		Iris.Text({"- ban = datastore ban", true})
		Iris.Text({"- wipe data = resets the player's saved profile", true})
		Iris.Text({"- bring = teleport him to you", true})
		Iris.Text({"- tp to = teleport you to him", true})
		Iris.Text({"- stats = set/add/deduct/null: timesjoined/playtime/cash", true})
		Iris.Text({"- passes = grant/revoke gamepass ownership (live sync)", true})
		Iris.End()

		Iris.CollapsingHeader({"bans tab"})
		Iris.Text({"- ban/unban any userid directly (even if offline)", true})
		Iris.Text({"- list below shows currently banned with unban buttons", true})
		Iris.End()

		Iris.End()
		Iris.End()
		Iris.End()
	end)
end

function AdminPanel:Init()
	Iris.Init(localPlayer:WaitForChild("PlayerGui") :: PlayerGui, RunService.RenderStepped, true)

	-- Iris parents everything under an "Iris_Root" FOLDER, and the respawn PlayerGui reset
	-- wipes folders even though the ScreenGuis inside are ResetOnSpawn=false; after that every
	-- Combo re-Generate WaitForChilds the dead root, parking the cycle coroutine mid-frame -
	-- endless "Too few calls to Iris.PopId()" + flicker. rebuild the tree the moment it dies
	localPlayer.PlayerGui.ChildRemoved:Connect(function(c)
		if c.Name == "Iris_Root" then
			Iris.ForceRefresh()
		end
	end)
	
	windowOpen = Iris.State(false)
	windowSize = Iris.State(Vector2.zero)
	windowPos = Iris.State(Vector2.zero)
	
	buildUI()

	local function toggleWindow()
		if not windowOpen or not authed then
			return
		end

		local nextOpen = not windowOpen:get()

		if nextOpen then
			recenterWindow()
		end
		
		windowOpen:set(nextOpen)
	end

	AdminPackets.packets.AdminSync.listen(function(data)
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(data.payload or "{}")
		end)

		if not ok then
			decoded = {}
		end

		if data.kind == "authed" then
			authed = true
		elseif data.kind == "bans" then
			bansList = decoded.list or {}
		end
	end)

	task.defer(function()
		send("hello", {})
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == konamiSeq[konamiIndex] then
				konamiIndex += 1
			elseif input.KeyCode == konamiSeq[1] then
				konamiIndex = 2
			else
				konamiIndex = 1
			end

			if konamiIndex > #konamiSeq then
				konamiIndex = 1

				send("dangerousUnlock", {})

				if not dangerousUnlocked then
					dangerousUnlocked = true

					if authed then
						NotificationHandler:CreateNotification("Error", "Gengaozo | -45, Noize of Nocent", 5, nil, false)
					end
				end
			end
		end

		if gpe then
			return
		end

		if input.KeyCode == Enum.KeyCode.F3 then
			toggleWindow()
		end

		if input.KeyCode == Enum.KeyCode.T and authed and clickTpState:get() then
			teleportToMouse()
		end
	end)
end

return AdminPanel