local Generators = {}

function Generators.Sphere(em: EditableMesh, rings: number, slices: number, radius: number)
	local vertIds = {}
	local cols = slices + 1

	for ring = 0, rings do
		local phi = math.pi * ring / rings
		for slice = 0, slices do
			local theta = 2 * math.pi * slice / slices
			vertIds[#vertIds + 1] = em:AddVertex(Vector3.new(
				radius * math.sin(phi) * math.cos(theta),
				radius * math.cos(phi),
				radius * math.sin(phi) * math.sin(theta)
				))
		end
	end

	for ring = 0, rings - 1 do
		for slice = 0, slices - 1 do
			local a = ring * cols + slice
			local b = a + 1
			local c = a + cols
			local d = c + 1
			em:AddTriangle(vertIds[a + 1], vertIds[b + 1], vertIds[c + 1])
			em:AddTriangle(vertIds[b + 1], vertIds[d + 1], vertIds[c + 1])
		end
	end
end

function Generators.Box(em: EditableMesh, w: number, h: number, d: number)
	local hw = w * 0.5
	local hh = h * 0.5
	local hd = d * 0.5

	local v = {}
	for _, pos in {
		Vector3.new(-hw, -hh, -hd),
		Vector3.new( hw, -hh, -hd),
		Vector3.new( hw,  hh, -hd),
		Vector3.new(-hw,  hh, -hd),
		Vector3.new(-hw, -hh,  hd),
		Vector3.new( hw, -hh,  hd),
		Vector3.new( hw,  hh,  hd),
		Vector3.new(-hw,  hh,  hd),
		} do
		v[#v + 1] = em:AddVertex(pos)
	end

	em:AddTriangle(v[1], v[3], v[2])
	em:AddTriangle(v[1], v[4], v[3])

	em:AddTriangle(v[5], v[6], v[7])
	em:AddTriangle(v[5], v[7], v[8])

	em:AddTriangle(v[1], v[5], v[8])
	em:AddTriangle(v[1], v[8], v[4])

	em:AddTriangle(v[2], v[3], v[7])
	em:AddTriangle(v[2], v[7], v[6])

	em:AddTriangle(v[1], v[2], v[6])
	em:AddTriangle(v[1], v[6], v[5])

	em:AddTriangle(v[4], v[7], v[3])
	em:AddTriangle(v[4], v[8], v[7])
end

function Generators.Cylinder(em: EditableMesh, rings: number, slices: number, radius: number, height: number)
	local hh = height * 0.5
	local ringStep = height / rings
	local cols = slices + 1
	local vertIds = {}

	for ring = 0, rings do
		local y = -hh + ring * ringStep
		for slice = 0, slices do
			local theta = 2 * math.pi * slice / slices
			vertIds[#vertIds + 1] = em:AddVertex(Vector3.new(
				radius * math.cos(theta),
				y,
				radius * math.sin(theta)
				))
		end
	end

	for ring = 0, rings - 1 do
		for slice = 0, slices - 1 do
			local a = ring * cols + slice
			local b = a + 1
			local c = a + cols
			local d = c + 1
			em:AddTriangle(vertIds[a + 1], vertIds[c + 1], vertIds[b + 1])
			em:AddTriangle(vertIds[b + 1], vertIds[c + 1], vertIds[d + 1])
		end
	end

	local topCenter = em:AddVertex(Vector3.new(0, hh, 0))
	local botCenter = em:AddVertex(Vector3.new(0, -hh, 0))

	for slice = 0, slices - 1 do
		local tA = rings * cols + slice
		local tB = tA + 1
		em:AddTriangle(topCenter, vertIds[tB + 1], vertIds[tA + 1])

		local bA = slice
		local bB = bA + 1
		em:AddTriangle(botCenter, vertIds[bA + 1], vertIds[bB + 1])
	end
end

return Generators