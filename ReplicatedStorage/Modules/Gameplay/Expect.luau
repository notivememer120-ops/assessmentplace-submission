local function expect(parent, name)
	local child = parent:FindFirstChild(name)

	assert(child, `{name} is missing in {parent:GetFullName()}`)
	
	return child
end

return expect