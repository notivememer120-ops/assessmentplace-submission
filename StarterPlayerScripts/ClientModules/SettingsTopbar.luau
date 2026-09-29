local rep = game:GetService("ReplicatedStorage")
local sounds = game:GetService("SoundService")
local starterGui = game:GetService("StarterGui")

local DataService = require(rep.Modules.Imported.Backend.DataService).client
local packets = require(rep.Modules.Packets.SettingsPackets).packets
local defaults = require(rep.Modules.Gameplay.DataTemplate).settings
local Signal = require(rep.Modules.Imported.Utility.Signal)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local config = require(rep.Modules.Configs.CampUIConfig)

type Controller = {
	__slittttName: string,
	Changed: typeof(Signal()),
	SaveChanged: typeof(Signal()),
	Status: string,
	_state: {[string]: boolean},
	_scope: Scythe.Scope,
	_save: Scythe.Scope,
	_music: SoundGroup,
	_sfx: SoundGroup,
	GetValue: (Controller, string) -> boolean,
	_apply: (Controller) -> (),
	_status: (Controller, string) -> (),
	SetValue: (Controller, string, boolean) -> (),
	Init: (Controller) -> (),
	Destroy: (Controller) -> (),
}

local SettingsTopbar = {} :: Controller
SettingsTopbar.__slittttName = "SettingsTopbar"
SettingsTopbar.Changed = Signal()
SettingsTopbar.SaveChanged = Signal()

function SettingsTopbar:GetValue(key)
	return self._state[key]
end

function SettingsTopbar:_apply()
	self._music.Volume = if self._state.muteMusic then 0 else 1
	self._sfx.Volume = if self._state.muteSfx then 0 else 1

	starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not self._state.hideChat)
end

function SettingsTopbar:_status(text)
	self.Status = text

	self.SaveChanged:Fire(text)
end

function SettingsTopbar:SetValue(key, value)
	if self._state[key] == value then return end

	self._state[key] = value

	self:_apply()
	self.Changed:Fire(key, value)

	Scythe.clean(self._save)

	self:_status(config.copy.saving)

	Scythe.add(self._save, task.delay(0.5, function()
		packets.SaveSettingsReq.send(table.clone(self._state))
	end))
	Scythe.add(self._save, task.delay(5, function()
		self:_status(config.copy.unsaved)
	end))
end

function SettingsTopbar:Init()
	self._scope = Scythe.scope()
	self._save = Scythe.extend(self._scope)
	self._state = table.clone(defaults)

	for k, v in DataService:get("settings") do
		if defaults[k] ~= nil then self._state[k] = v end
	end

	local function group(name: string, folder: Instance): SoundGroup
		local result = Scythe.add(self._scope, Instance.new("SoundGroup"))
		result.Name = name
		result.Parent = sounds

		local function adopt(v: Instance)
			if v:IsA("Sound") then v.SoundGroup = result end
		end

		for _, v in folder:GetDescendants() do adopt(v) end

		Scythe.connect(self._scope, folder.DescendantAdded, adopt)
		return result
	end

	self._music = group("MusicGroup", sounds.Music)
	self._sfx = group("SFXGroup", sounds.SFX)

	self:_apply()
	self:_status(config.copy.saved)

	Scythe.connect(self._scope, DataService:getChangedSignal("settings"), function(saved)
		for k, v in self._state do
			if saved[k] ~= v then return end
		end

		Scythe.clean(self._save)

		self:_status(config.copy.saved)
	end)
end

function SettingsTopbar:Destroy()
	Scythe.destroy(self._scope)
end

return SettingsTopbar