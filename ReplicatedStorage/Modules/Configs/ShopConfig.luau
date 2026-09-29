export type Item = {title: string, description: string, price: number}

local ShopConfig = {
	requestInterval = 0.25,
	items = {
		Placeholder = {
			title = "Placeholder item",
			description = "A sample saved inventory item.",
			price = 1,
		},
	} :: {[string]: Item},
}

function ShopConfig.Get(key: string): Item?
	return ShopConfig.items[key]
end

return ShopConfig