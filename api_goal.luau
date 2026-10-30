const btable = require("@src")

-- fresh from scratch but it's also un-type safe which lets u e.g. parse a csv file

const obj = btable.new({
	meow = btable.serdes.boolean,
})

print("the size in bytes:", obj.size())

const iters = obj.rows()

for idx, meow in iters.unsafe_query("typo") do
	print("defaults to buffer: " .. buffer.tostring(meow))
	print("because it's stored in binary")
end

for idx, meow in iters.query("meow") do
	-- type error: can't add true + 2
	-- this is cuz its very fancily typed
	print(meow + 2)
end
