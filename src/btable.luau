const COLUMN_COUNT_FILE_OFFSET = 8
const COLUMN_BSIZE_FILE_OFFSET = 4
const COLUMN_BSIZE_GROWTH_AMOUNT = 256
const STARTING_SIZE = 1024

type function IndexerToProperties(union: type)
	if union.tag == "any" then
		return types.any
	elseif union.tag == "singleton" then
		return types.newtable({
			[union] = types.buffer,
		} :: any)
	elseif union.tag == "string" then
		return types.newtable(nil, {
			index = types.string,
			readresult = types.buffer,
			writeresult = types.buffer,
		})
	elseif union.tag == "unknown" then
		return types.newtable(nil, {
			index = types.string,
			readresult = types.buffer,
			writeresult = types.buffer,
		})
	end

	const ret_property_ty = types.newtable()

	for _, stringleton in union:components() do
		ret_property_ty:setproperty(stringleton, types.buffer)
	end

	return ret_property_ty
end

export type Row<T> = IndexerToProperties<T>

const function grow_at<T>(self: Identity<T>, offset: number, amount: number): (buffer, number)
	const old_buff = self.buff
	const old_len = buffer.len(old_buff)

	const new_buff = buffer.create(old_len + amount)

	buffer.copy(new_buff, 0, old_buff, 0, offset)
	buffer.copy(new_buff, offset + amount, old_buff, offset, old_len - offset)

	self.buff = new_buff
	return new_buff, old_len + amount
end

--[[
Private binary file format methods.

Parsers/readers take the buffer because they do not need to replace the buffer.
Anything which writes needs to take `self` because it might need to replace the buffer.
]]

const function btable_check_format(buff: buffer)
	return buffer.len(buff) >= 8 and buffer.readstring(buff, 0, 8) == "<!btable"
end

const function column_grow_block<T>(self: Identity<T>): (buffer, number)
	local buff = self.buff
	local buff_len = buffer.len(buff)
	const bsize = buffer.readu32(buff, buff_len - COLUMN_BSIZE_FILE_OFFSET)

	buff, buff_len = grow_at(self, buff_len - COLUMN_COUNT_FILE_OFFSET - bsize, COLUMN_BSIZE_GROWTH_AMOUNT)

	buffer.writeu32(buff, buff_len - COLUMN_BSIZE_FILE_OFFSET, bsize + COLUMN_BSIZE_GROWTH_AMOUNT)

	return buff, buff_len
end

const function column_add<T>(self: Identity<T>, column_name: string)
	const name_len = string.len(column_name)
	local buff = self.buff
	local buff_len = buffer.len(buff)

	const column_count = buffer.readu32(buff, buff_len - COLUMN_COUNT_FILE_OFFSET)

	-- The performance cost of checking if a column is already in here is too significant.
	-- might be worth revisiting tho
	local cursor = buff_len - COLUMN_COUNT_FILE_OFFSET
	for _ = 1, column_count do
		cursor -= buffer.readu16(buff, cursor - 2) + 2
	end

	-- While the name doesn't fit inside the current column block, keep growing
	-- this is really cooked spaghetti
	while
		cursor - 2 - name_len
		< buff_len - COLUMN_COUNT_FILE_OFFSET - buffer.readu32(buff, buff_len - COLUMN_BSIZE_FILE_OFFSET)
	do
		const old_len = buff_len
		buff, buff_len = column_grow_block(self)
		cursor += buff_len - old_len
	end

	cursor -= 2
	buffer.writeu16(buff, cursor, name_len)

	cursor -= name_len
	buffer.writestring(buff, cursor, column_name)

	buffer.writeu32(buff, buff_len - COLUMN_COUNT_FILE_OFFSET, column_count + 1)
end

const function column_find_idx(buff: buffer, column_name: string): number?
	local cursor = buffer.len(buff) - COLUMN_COUNT_FILE_OFFSET

	for idx = 1, buffer.readu32(buff, cursor) do
		cursor -= 2
		const name_len = buffer.readu16(buff, cursor)

		cursor -= name_len
		if buffer.readstring(buff, cursor, name_len) == column_name then
			return idx
		end
	end

	return nil
end

const function row_add() end

const function row_remove() end

const function row_pop() end

const function row_move() end

const function cell_set() end

const function cell_get() end

const btable = {}
btable.__index = btable
export type Identity<T> = setmetatable<
	{
		buff: buffer,

		read ["%column_union"]: T,
	},
	{
		-- :/
		__index: {
			cell_set: (self: Identity<T>, column: T, row: number, value: buffer) -> (),
			cell_get: (self: Identity<T>, column: T, row: number) -> buffer,

			rows: (self: Identity<T>) -> ({ read T }) -> () -> (number, ...buffer),
			row_push: (self: Identity<T>, row: Row<T>) -> number,
			row_get: (self: Identity<T>) -> Row<T>,
			row_remove: (self: Identity<T>, pos: number) -> (),
			row_set: (self: Identity<T>, pos: number, row: Row<T>) -> (),
			row_pop: (self: Identity<T>, pos: number) -> Row<T>,

			columns: (self: Identity<T>) -> { T },
		},
	}
>

const function new<T>(columns: { read T | "" }): Identity<T>
	const buff, buff_len = buffer.create(STARTING_SIZE), STARTING_SIZE
	const self = setmetatable({
		buff = buff,

		["%column_union"] = nil :: T,
	}, btable) :: any

	buffer.writestring(buff, 0, "<!btable")
	buffer.writeu32(buff, buff_len - COLUMN_BSIZE_FILE_OFFSET, COLUMN_BSIZE_GROWTH_AMOUNT)

	for _, column_name in columns do
		column_add(self, column_name)
	end

	return self
end

-- note: a subset of columns being specified is allowed and intentional
const function parse<T>(input: buffer, columns: { read T | "" }?): (Identity<T>, { string })
	assert(btable_check_format(input), `a non-btable buffer was passed into parse`)

	local buff, buff_len = input, buffer.len(input)

	const cloned_buff = buffer.create(buff_len)
	buffer.copy(cloned_buff, 0, buff, 0, buff_len)

	buff = cloned_buff

	const self = setmetatable({
		buff = buff,
		["%column_union"] = nil,
	}, btable) :: any

	if columns then
		for _, column_name in columns do
			const exists = column_find_idx(buff, column_name)
			assert(exists, `column {column_name} does not exist in this btable`)
		end
	end

	return self, self:columns()
end

function btable.row_push<T>(self: Identity<T>, data: Row<T>) end

function btable.row_get<T>(self: Identity<T>, pos: number): Row<T> end

function btable.row_move<T>(self: Identity<T>, from: number, to: number) end

function btable.sort<T>(self: Identity<T>, sort_fn: (left: Row<T>, right: Row<T>) -> boolean) end

function btable.row_remove<T>(self: Identity<T>, pos: number): Row<T> end

function btable.row_pop<T>(self: Identity<T>, pos: number): Row<T> end

function btable.columns<T>(self: Identity<T>): { T }
	local cursor = buffer.len(self.buff) - 8
	const names: { string } = {}

	for _ = 1, buffer.readu32(self.buff, cursor) do
		cursor -= 2
		const name_len = buffer.readu16(self.buff, cursor)

		cursor -= name_len
		table.insert(names, buffer.readstring(self.buff, cursor, name_len))
	end

	return names
end

function btable.rows<T>(self: Identity<T>): ({ read T }) -> () -> (number, ...buffer)
	const function columns(column_ids: { read T })
		const column_idx: { any } = table.clone(column_ids)

		for idx, column_name in column_ids do
			-- note: suboptimal.
			-- we could make this better by making it build a lookup table
			const found_idx = column_find_idx(self.buff, column_name)
			assert(found_idx, `row {column_name} not found`)

			column_idx[idx] = found_idx
		end

		const function iter(): (number, ...buffer) end

		return iter
	end

	return columns
end

table.freeze(btable)
return table.freeze({
	new = new,
	parse = parse,

	column_grow_block = column_grow_block,
	column_add = column_add,
	column_find_idx = column_find_idx,

	btable_check_format = btable_check_format,

	grow_at = grow_at,

	STARTING_SIZE = STARTING_SIZE,
	COLUMN_BSIZE_FILE_OFFSET = COLUMN_BSIZE_FILE_OFFSET,
	COLUMN_COUNT_FILE_OFFSET = COLUMN_COUNT_FILE_OFFSET,
	COLUMN_BSIZE_GROWTH_AMOUNT = COLUMN_BSIZE_GROWTH_AMOUNT,
})
