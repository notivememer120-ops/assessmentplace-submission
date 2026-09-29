-- services
local AssetService = game:GetService("AssetService")

-- modules
local EzMeshObject = require(script.EzMeshObject)
local Generators = require(script.Generators)

-- types
export type EzMeshObject = EzMeshObject.EzMeshObject
export type UpdateVertexData = EzMeshObject.UpdateVertexData

-- main
local EzMesh = {}

function EzMesh:_create(content: Content?): (EditableMesh?, string?)
	local s
	local em
	s, em = pcall(function()
		if content then
			return AssetService:CreateEditableMeshAsync(content, {FixedSize = false})
		end
		return AssetService:CreateEditableMesh()
	end)

	if not s then
		return nil, `EditableMesh creation failed: {tostring(em)}`
	elseif not em then
		return nil, "EditableMesh allocation returned nil; the device memory budget is exhausted"
	end

	return em, nil
end

function EzMesh:IsAvailable(): (boolean, string?)
	local em
	local err
	em, err = self:_create()
	if not em then
		return false, err
	end

	em:Destroy()
	return true, nil
end

function EzMesh:MakeMesh(params: { Vertices: { Vector3 }?, Faces: { { number } }? }?): (EzMeshObject?, string?)
	local p = params or {}
	local em
	local err
	em, err = self:_create()
	if not em then
		warn(`EzMesh:MakeMesh - {err}`)
		return nil, err
	end

	local ids: { number } = {}
	for _, v in p.Vertices or {} do
		ids[#ids + 1] = em:AddVertex(v)
	end

	for _, face in p.Faces or {} do
		em:AddTriangle(ids[face[1]], ids[face[2]], ids[face[3]])
	end

	return EzMeshObject._new(em)
end

function EzMesh:MakeSphere(params: { Rings: number?, Slices: number?, Radius: number? }?): (EzMeshObject?, string?)
	local p = params or {}
	local em
	local err
	em, err = self:_create()
	if not em then
		warn(`EzMesh:MakeSphere - {err}`)
		return nil, err
	end
	Generators.Sphere(em, p.Rings or 20, p.Slices or 20, p.Radius or 1)
	return EzMeshObject._new(em)
end

function EzMesh:MakeBox(params: { Width: number?, Height: number?, Depth: number? }?): (EzMeshObject?, string?)
	local p = params or {}
	local em
	local err
	em, err = self:_create()
	if not em then
		warn(`EzMesh:MakeBox - {err}`)
		return nil, err
	end
	Generators.Box(em, p.Width or 1, p.Height or 1, p.Depth or 1)
	return EzMeshObject._new(em)
end

function EzMesh:MakeCylinder(params: { Rings: number?, Slices: number?, Radius: number?, Height: number? }?): (EzMeshObject?, string?)
	local p = params or {}
	local em
	local err
	em, err = self:_create()
	if not em then
		warn(`EzMesh:MakeCylinder - {err}`)
		return nil, err
	end
	Generators.Cylinder(em, p.Rings or 1, p.Slices or 20, p.Radius or 1, p.Height or 2)
	return EzMeshObject._new(em)
end

function EzMesh:ConvertMesh(Mesh: MeshPart): (EzMeshObject?, string?)
	local em
	local err
	em, err = self:_create(Mesh.MeshContent)
	if not em then
		warn(`EzMesh:ConvertMesh - {Mesh:GetFullName()}: {err}`)
		return nil, err
	end
	return EzMeshObject._new(em, Mesh)
end

return EzMesh