local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")

local CandyUI = require(rep.Modules.Gameplay.CandyUI)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local NotifyCard = require(rep.Modules.Gameplay.NotifyCard)
local NotifyPackets = require(rep.Modules.Packets.NotifyPackets)
local Queue = require(rep.Modules.Imported.Backend.Queue)
local Timer = require(rep.Modules.Imported.Backend.Timer)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local UILib = require(rep.Modules.Gameplay.UILib)
local UISfx = require(rep.Modules.Gameplay.UISfx)

local ServerNotice = NotifyPackets.packets.ServerNotice

local player = players.LocalPlayer

local cardScale = 1.35

local function fmtCount(seconds)
	local total = math.max(0, seconds)

	return `{total // 60}:{string.format("%02d", total % 60)}`
end

local NotifyController = {}
NotifyController.__slittttName = "NotifyController"
NotifyController.Dependencies = {"AutoScaleController", "InteractFXController"}

function NotifyController:Init()
	if self._scope then
		return
	end

	local scope = Scythe.scope()

	self._scope = scope
	self._noticeScope = Scythe.extend(scope)
	self._queue = Queue.new()
	self._generation = 0
	self._closing = false

	local sg = CandyUI.child(player.PlayerGui, "ScreenGui", {
		Name = "Notify",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 150,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	Scythe.add(scope, sg)

	self:Get("AutoScaleController"):attach(sg)

	self._scrim = CandyUI.scrim(sg)
	self._card = NotifyCard.build(sg)

	self:Get("InteractFXController"):wireCandy(self._card.ok, 0.11)

	Scythe.connect(scope, self._card.ok.Activated, function()
		if self._scope == scope then
			self:hide()
		end
	end)

	Scythe.add(scope, ModalGuard.register(self._card.root))

	Scythe.add(scope, ModalGuard.onClickOutside(self._scrim, self._card.sticker, function()
		if self._scope == scope then
			self:hide()
		end
	end))

	Scythe.add(scope, self:On("Notify", function(cfg)
		if self._scope == scope then
			self:show(cfg)
		end
	end))

	Scythe.add(scope, ServerNotice.listen(function(data)
		if self._scope == scope then
			self:show({
				kind = data.kind,
				title = data.title,
				text = data.text,
				count = data.count > 0 and data.count or nil,
				urgent = data.urgent,
			})
		end
	end))
end

function NotifyController:show(cfg)
	assert(self._scope, "NotifyController must be initialized before showing notices")

	local notice = {config = table.clone(cfg)}

	if self._active then
		if not cfg.urgent then
			self._queue:PushRight(notice)
			return
		end

		if not self._closing then
			self._queue:PushLeft(self._active)
		end
	end

	self:_present(notice)
end

function NotifyController:_present(notice)
	self._generation += 1

	Scythe.clean(self._noticeScope)

	self._active = notice
	self._closing = false

	local scope = self._noticeScope
	local generation = self._generation
	local cfg = notice.config
	local card = self._card
	local kindId = cfg.kind

	if type(kindId) == "string" then
		kindId = NotifyCard.idByName[kindId]
	end

	local def = NotifyCard.setKind(card, kindId)

	card.title.Text = cfg.title or ""
	card.body.Text = cfg.text or ""
	card.body.Visible = card.body.Text ~= ""

	if cfg.count then
		if not notice.deadline then
			notice.deadline = os.clock() + cfg.count
		end

		card.count.Visible = true
		card.count.Text = fmtCount(math.ceil(notice.deadline - os.clock()))

		if notice.deadline > os.clock() then
			local timer = Scythe.add(scope, Timer.new(0.25))
			timer.TimeFunction = os.clock

			Scythe.connect(scope, timer.Tick, function()
				if scope ~= self._noticeScope or generation ~= self._generation then
					return
				end

				local left = math.ceil(notice.deadline - os.clock())

				card.count.Text = fmtCount(left)

				if left <= 0 then
					timer:Stop()
				end
			end)

			timer:Start()
		end
	else
		card.count.Visible = false
	end

	UISfx.play(def.sound)

	self._scrim.Visible = true

	Scythe.add(scope, UILib.tw(self._scrim, 0.22, {BackgroundTransparency = 0.45}), "Cancel")

	card.root.GroupTransparency = 0
	card.root.Visible = true
	card.scale.Scale = 0.86 * cardScale

	UILib.spr.target(card.scale, 0.72, 5.5, {Scale = cardScale})
	Scythe.add(scope, function()
		UILib.spr.stop(card.scale)
	end)
end

function NotifyController:hide()
	if not self._active or self._closing then
		return
	end

	ModalGuard.stampClose()

	self._closing = true
	self._generation += 1

	Scythe.clean(self._noticeScope)

	local scope = self._noticeScope
	local generation = self._generation
	local card = self._card
	local onOk = self._active.config.onOk
	self._active.config.onOk = nil

	UILib.spr.target(card.scale, 1, 12, {Scale = 0.7 * cardScale})
	Scythe.add(scope, function()
		UILib.spr.stop(card.scale)
	end)

	local fade = Scythe.add(scope, UILib.tw(card.root, 0.22, {GroupTransparency = 1}), "Cancel")

	Scythe.add(scope, UILib.tw(self._scrim, 0.18, {BackgroundTransparency = 1}), "Cancel")

	Scythe.connect(scope, fade.Completed, function(state)
		if state ~= Enum.PlaybackState.Completed or scope ~= self._noticeScope or generation ~= self._generation then
			return
		end

		self._active = nil
		self._closing = false

		Scythe.clean(scope)

		card.root.Visible = false
		self._scrim.Visible = false

		if not self._queue:IsEmpty() then
			self:_present(self._queue:PopLeft())
		end
	end)

	if onOk then
		task.spawn(onOk)
	end
end

function NotifyController:Destroy()
	if not self._scope then
		return
	end

	local scope = self._scope
	self._scope = nil
	self._generation += 1
	self._active = nil
	self._queue = nil
	self._closing = false

	Scythe.clean(self._noticeScope)
	Scythe.destroy(scope)

	self._noticeScope = nil
	self._card = nil
	self._scrim = nil
end

return NotifyController