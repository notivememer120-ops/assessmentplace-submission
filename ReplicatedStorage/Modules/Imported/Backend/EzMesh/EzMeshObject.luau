-- services
local AssetService = game:GetService("AssetService")

-- modules
local Dissolve = require(script.Parent.Dissolve)

-- types
export type UpdateVertexData = {
	Position: Vector3?,
	Color: Color3?,
}

export type EzMeshObject = {
	EditableMesh: EditableMesh,
	Part: MeshPart?,

	RenderMesh: (self: EzMeshObject) -> MeshPart,
	RecycleMesh: (self: EzMeshObject, part: MeshPart) -> MeshPart,
	Clone: (self: EzMeshObject) -> EzMeshObject,

	AddVertex: (self: EzMeshObject, position: Vector3) -> number,
	AddTriangle: (self: EzMeshObject, verts: { number }) -> number,

	SetVertexPosition: (self: EzMeshObject, vertId: number, position: Vector3) -> (),
	SetVertexColor: (self: EzMeshObject, vertId: number, color: Color3) -> (),
	UpdateVertices: (self: EzMeshObject, data: { Vertices: { [number]: UpdateVertexData } }) -> (),

	RemoveVertex: (self: EzMeshObject, vertId: number) -> (),
	RemoveFace: (self: EzMeshObject, faceId: number) -> (),
	DissolveVertex: (self: EzMeshObject, vertId: number) -> (),
	DissolveFace: (self: EzMeshObject, faceId: number) -> (),

	GetBounds: (self: EzMeshObject) -> (CFrame, Vector3),
	GetSize: (self: EzMeshObject) -> Vector3,
	GetPart: (self: EzMeshObject) -> MeshPart?,
	GetEditableMesh: (self: EzMeshObject) -> EditableMesh,

	Destroy: (self: EzMeshObject) -> (),
	Clear: (self: EzMeshObject) -> (),
}

-- utils
local PART_OPTIONS = {
	CollisionFidelity = Enum.CollisionFidelity.Box,
	RenderFidelity = Enum.RenderFidelity.Automatic,
}

local function createPart(em: EditableMesh): MeshPart
	return AssetService:CreateMeshPartAsync(Content.fromObject(em), PART_OPTIONS)
end

local function applyToExisting(em: EditableMesh, part: MeshPart)
	local textureContent = part.TextureContent

	local temp = createPart(em)
	part:ApplyMesh(temp)
	temp:Destroy()

	part.TextureContent = textureContent
end

-- main
local EzMeshObject = {}
EzMeshObject.__index = EzMeshObject

function EzMeshObject._new(em: EditableMesh, existingPart: MeshPart?): EzMeshObject
	return setmetatable({
		EditableMesh = em,
		Part = existingPart,
	}, EzMeshObject) :: any
end

function EzMeshObject:RenderMesh(): MeshPart
	if not self.Part then
		self.Part = createPart(self.EditableMesh)
	else
		applyToExisting(self.EditableMesh, self.Part)
	end
	return self.Part
end

function EzMeshObject:RecycleMesh(part: MeshPart): MeshPart
	applyToExisting(self.EditableMesh, part)
	if self.Part and self.Part ~= part then
		self.Part:Destroy()
	end
	self.Part = part

	return part
end

function EzMeshObject:Clone(): EzMeshObject
	local newEm = AssetService:CreateEditableMeshAsync(Content.fromObject(self.EditableMesh))
	return EzMeshObject._new(newEm)
end

function EzMeshObject:AddVertex(position: Vector3): number
	return self.EditableMesh:AddVertex(position)
end

function EzMeshObject:AddTriangle(verts: { number }): number
	return self.EditableMesh:AddTriangle(verts[1], verts[2], verts[3])
end

function EzMeshObject:SetVertexPosition(vertId: number, position: Vector3)
	self.EditableMesh:SetPosition(vertId, position)
end

function EzMeshObject:SetVertexColor(vertId: number, color: Color3)
	local em = self.EditableMesh
	local colorId = em:AddColor(color, 1)
	for _, faceId in em:GetVertexFaces(vertId) do
		em:SetVertexFaceColor(vertId, faceId, colorId)
	end
end

function EzMeshObject:UpdateVertices(data: { Vertices: { [number]: UpdateVertexData } })
	local em = self.EditableMesh

	for vertId, props in data.Vertices do
		if props.Position then
			em:SetPosition(vertId, props.Position)
		end
		if props.Color then
			self:SetVertexColor(vertId, props.Color)
		end
	end
end

function EzMeshObject:RemoveVertex(vertId: number)
	local em = self.EditableMesh
	for _, faceId in em:GetVertexFaces(vertId) do
		em:RemoveFace(faceId)
	end
	em:RemoveUnused()
end

function EzMeshObject:RemoveFace(faceId: number)
	self.EditableMesh:RemoveFace(faceId)
end

function EzMeshObject:DissolveVertex(vertId: number)
	Dissolve.Vertex(self.EditableMesh, vertId)
end

function EzMeshObject:DissolveFace(faceId: number)
	Dissolve.Face(self.EditableMesh, faceId)
end

function EzMeshObject:GetBounds(): (CFrame, Vector3)
	local em = self.EditableMesh
	local center = em:GetCenter()
	local size = em:GetSize()
	if self.Part then
		return self.Part.CFrame * CFrame.new(center), size
	end
	return CFrame.new(center), size
end

function EzMeshObject:GetSize(): Vector3
	return self.EditableMesh:GetSize()
end

function EzMeshObject:GetPart(): MeshPart?
	return self.Part
end

function EzMeshObject:GetEditableMesh(): EditableMesh
	return self.EditableMesh
end

function EzMeshObject:Clear()
	if self.Part then
		self.Part:Destroy()
		self.Part = nil
	end
	self.EditableMesh:Destroy()
	self.EditableMesh = AssetService:CreateEditableMesh()
end

function EzMeshObject:Destroy()
	if self.Part then
		self.Part:Destroy()
	end
	self.EditableMesh:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

return EzMeshObject