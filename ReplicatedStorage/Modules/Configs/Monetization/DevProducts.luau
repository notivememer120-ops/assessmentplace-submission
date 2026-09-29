local DevProducts: {[string]: any} = {}

function DevProducts.GetByProductId(productId: number): (string?, {[string]: any}?)
	for key, def in DevProducts do
		if type(def) == "table" and def.ProductId == productId then
			return key, def
		end
	end

	return nil, nil
end

function DevProducts.GetAllProductKeys(): {string}
	local names = {}

	for n, v in DevProducts do
		if type(v) == "table" then
			table.insert(names, n)
		end
	end

	table.sort(names)

	return names
end

return DevProducts