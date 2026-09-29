local Dissolve = {}

local function collectBoundaryRing(em: EditableMesh, faces: {number}, centerSet: {[number]: true}): {number}
	local edgeCount: {[string]: number} = {}

	for _, faceId in faces do
		local verts = em:GetFaceVertices(faceId)
		for i = 1, 3 do
			local a = verts[i]
			local b = verts[i % 3 + 1]
			if not centerSet[a] and not centerSet[b] then
				local key = math.min(a, b) .. "_" .. math.max(a, b)
				edgeCount[key] = (edgeCount[key] or 0) + 1
			end
		end
	end

	local boundaryFrom: {[number]: number} = {}
	for _, faceId in faces do
		local verts = em:GetFaceVertices(faceId)
		for i = 1, 3 do
			local a = verts[i]
			local b = verts[i % 3 + 1]
			if not centerSet[a] and not centerSet[b] then
				local key = math.min(a, b) .. "_" .. math.max(a, b)
				if edgeCount[key] == 1 then
					boundaryFrom[a] = b
				end
			end
		end
	end

	local start = next(boundaryFrom)
	if not start then
		return {}
	end

	local ring = {start}
	local current = boundaryFrom[start]
	local limit = 0
	while current ~= start and limit < 10000 do
		ring[#ring + 1] = current
		current = boundaryFrom[current]
		limit += 1
	end

	return ring
end

local function fanFill(em: EditableMesh, ring: {number})
	if #ring < 3 then
		return
	end
	local pivot = ring[1]
	for i = 2, #ring - 1 do
		em:AddTriangle(pivot, ring[i], ring[i + 1])
	end
end

function Dissolve.Vertex(em: EditableMesh, vertexId: number)
	local faces = em:GetVertexFaces(vertexId)
	if #faces == 0 then
		em:RemoveUnused()
		return
	end

	local ring = collectBoundaryRing(em, faces, {[vertexId] = true})

	for _, faceId in faces do
		em:RemoveFace(faceId)
	end
	em:RemoveUnused()

	fanFill(em, ring)
end

function Dissolve.Face(em: EditableMesh, faceId: number)
	local faceVerts = em:GetFaceVertices(faceId)
	local centerSet: {[number]: true} = {}
	local facesToRemove: {[number]: true} = {[faceId] = true}

	for _, vId in faceVerts do
		centerSet[vId] = true
		for _, adjFaceId in em:GetVertexFaces(vId) do
			facesToRemove[adjFaceId] = true
		end
	end

	local faceList = {}
	for fId in facesToRemove do
		faceList[#faceList + 1] = fId
	end

	local ring = collectBoundaryRing(em, faceList, centerSet)

	for fId in facesToRemove do
		em:RemoveFace(fId)
	end
	em:RemoveUnused()

	fanFill(em, ring)
end

return Dissolve