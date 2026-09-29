--!strict
local rep = game:GetService("ReplicatedStorage")

local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local ModalWire = {}

type Modal = GuiObject & {Scrim: GuiObject, FadeWrap: GuiObject & {Dlg: GuiObject}}

type Effects = {closeDlg: (Effects, Modal) -> ()}

function ModalWire.close(fx: Effects, modal: Modal)
	ModalGuard.stampClose()

	fx:closeDlg(modal)
end

function ModalWire.wire(fx: Effects, modal: Modal)
	ModalGuard.register(modal)

	ModalGuard.onClickOutside(modal.Scrim, modal.FadeWrap.Dlg, function()
		ModalWire.close(fx, modal)
	end)

	local cl = modal.FadeWrap.Dlg:FindFirstChild("Close", true)

	if cl then
		ModalGuard.onClick(cl :: GuiObject, function()
			ModalWire.close(fx, modal)
		end)
	end

	modal.Visible = false
end

return ModalWire