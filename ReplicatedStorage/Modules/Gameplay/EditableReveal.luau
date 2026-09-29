--!optimize 2
--!native
--!strict

local AssetService = game:GetService("AssetService")

local EditableReveal = {}
EditableReveal.__index = EditableReveal

local bins = 256

export type Axis = "y" | "radius" | "angle"

export type EditableReveal = typeof(setmetatable(
	{} :: {
		_image:ImageLabel,
		_editable:EditableImage,
		_size:Vector2,
		_workBuf:buffer,
		_binOffsets:buffer,
		_binData:buffer,
		_originalImageContent:Content,
	},
	EditableReveal
))

local function makeBinner(axis:Axis, w:number, h:number): (number, number) -> number
	if axis == "y" then
		local denom = math.max(1, h - 1)

		return function(_x:number, y:number): number
			local bin = math.floor((y / denom) * bins)

			if bin >= bins then
				bin = bins - 1
			end

			return bin
		end
	end

	if axis == "angle" then
		local acx = (w - 1) / 2
		local acy = (h - 1) / 2

		return function(x:number, y:number): number
			local t = (math.atan2(acx - x, y - acy) % (2 * math.pi)) / (2 * math.pi)
			local bin = math.floor(t * bins)

			if bin >= bins then
				bin = bins - 1
			end

			return bin
		end
	end

	local cx = (w - 1) / 2
	local cy = (h - 1) / 2
	local maxR = math.sqrt(cx * cx + cy * cy)
	
	if maxR <= 0 then
		maxR = 1
	end

	return function(x:number, y:number): number
		local dx = x - cx
		local dy = y - cy
		local bin = math.floor((math.sqrt(dx * dx + dy * dy) / maxR) * bins)
		
		if bin >= bins then
			bin = bins - 1
		end
		
		return bin
	end
end

function EditableReveal.new(image:ImageLabel, axis:Axis, sourceEditable:EditableImage?):EditableReveal
	local editable = sourceEditable or (AssetService:CreateEditableImageAsync(image.ImageContent) :: EditableImage)

	local size = editable.Size
	local w = size.X
	local h = size.Y
	local srcBuf = editable:ReadPixelsBuffer(Vector2.zero, size)
	local workBuf = buffer.create(w * h * 4)

	local binOf = makeBinner(axis, w, h)
	local binCounts = buffer.create(bins * 4)

	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local idx = (y * w + x) * 4

			if buffer.readu8(srcBuf, idx + 3) > 0 then
				local off = binOf(x, y) * 4

				buffer.writeu32(binCounts, off, buffer.readu32(binCounts, off) + 1)
			end
		end
	end

	local binOffsets = buffer.create((bins + 1) * 4)
	local running = 0

	for bin = 0, bins - 1 do
		buffer.writeu32(binOffsets, bin * 4, running)

		running += buffer.readu32(binCounts, bin * 4)
	end

	buffer.writeu32(binOffsets, bins * 4, running)

	local binData = buffer.create(math.max(1, running) * 8)
	local cursors = buffer.create(bins * 4)

	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local idx = (y * w + x) * 4

			if buffer.readu8(srcBuf, idx + 3) > 0 then
				local bin = binOf(x, y)
				local binStart = buffer.readu32(binOffsets, bin * 4)
				local cursor = buffer.readu32(cursors, bin * 4)
				local writeOff = (binStart + cursor) * 8

				buffer.writeu32(binData, writeOff, idx)
				buffer.writeu32(binData, writeOff + 4, buffer.readu32(srcBuf, idx))
				buffer.writeu32(cursors, bin * 4, cursor + 1)
			end
		end
	end

	local originalImageContent = image.ImageContent

	editable:WritePixelsBuffer(Vector2.zero, size, workBuf)

	image.ImageContent = Content.fromObject(editable)

	return setmetatable({
		_image = image,
		_editable = editable,
		_size = size,
		_workBuf = workBuf,
		_binOffsets = binOffsets,
		_binData = binData,
		_originalImageContent = originalImageContent,
	}, EditableReveal)
end

function EditableReveal:Reveal(t0:number, t1:number)
	local self:EditableReveal = self

	t0 = math.clamp(t0, 0, 1)
	t1 = math.clamp(t1, 0, 1)

	if t1 < t0 then
		t0, t1 = t1, t0
	end

	local workBuf = self._workBuf

	buffer.fill(workBuf, 0, 0)

	local binLo = math.max(0, math.floor(t0 * bins))
	local binHi = math.min(bins, math.ceil(t1 * bins))

	if binHi > binLo then
		local binData = self._binData
		local startPix = buffer.readu32(self._binOffsets, binLo * 4)
		local endPix = buffer.readu32(self._binOffsets, binHi * 4)

		for i = startPix, endPix - 1 do
			local off = i * 8

			buffer.writeu32(workBuf, buffer.readu32(binData, off), buffer.readu32(binData, off + 4))
		end
	end

	self._editable:WritePixelsBuffer(Vector2.zero, self._size, workBuf)
end

function EditableReveal:Hide()
	local self:EditableReveal = self

	buffer.fill(self._workBuf, 0, 0)
	
	self._editable:WritePixelsBuffer(Vector2.zero, self._size, self._workBuf)
end

function EditableReveal:Destroy()
	local self:EditableReveal = self
	
	self._image.ImageContent = self._originalImageContent

	self._editable:Destroy()
end

return EditableReveal