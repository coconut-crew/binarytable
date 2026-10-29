--[[ THIS ISNT AI GENERATED I PROMISE I JUST ACTUALLY WROTE THIS ITS NOT EVEN PROMPT PLSSSS

# structure

## 1. start
- format marker (`<!btable`): 8 bytes

## 2. columns
- total column block size (u32, 4 bytes)
- column count (u32, 4 bytes)

then for each column:
- column length: u16, size int included
- column data: ...
- repeat

## 3. rows
- row count u32: 4 bytes

then, for each row:
- size for the entire row, u32, size int included.
	keep in mind this has padding, all bytes are not guaranteed to be filled. grows at 1.5x multiplier
- size array for all columns, u32 for each (e.g. row 1 column 1 takes 23 bytes)
- cell data (length decided by size array index)
]]

const COLUMN_BSIZE_FILE_OFFSET = 8
const COLUMN_COUNT_FILE_OFFSET = 12
const COLUMN_BLOCK_FILE_OFFSET = 16
const COLUMN_BSIZE_GROWTH_AMOUNT = 256
const STARTING_SIZE = 1024
const ROW_STARTING_SIZE = 64

const function grow_at(buff: buffer, offset: number, amount: number): buffer
	const old_buff_len = buffer.len(buff)
	const new_buff = buffer.create(old_buff_len + amount)

	buffer.copy(new_buff, 0, buff, 0, offset)
	buffer.copy(new_buff, offset + amount, buff, offset, old_buff_len - offset)

	return new_buff
end

const function magic_string_check(buff: buffer)
	return buffer.len(buff) >= 8 and buffer.readstring(buff, 0, 8) == "<!btable"
end

-- opens the gap at the end of the column block, which pushes the rows right
const function column_grow_block(buff: buffer): buffer
	const bsize = buffer.readu32(buff, COLUMN_BSIZE_FILE_OFFSET)

	buff = grow_at(buff, COLUMN_BLOCK_FILE_OFFSET + bsize, COLUMN_BSIZE_GROWTH_AMOUNT)

	buffer.writeu32(buff, COLUMN_BSIZE_FILE_OFFSET, bsize + COLUMN_BSIZE_GROWTH_AMOUNT)

	return buff
end

const function column_add(buff: buffer, column_id: string): buffer
	-- +2 for name length
	const id_length = string.len(column_id) + 2
	const column_count = buffer.readu32(buff, COLUMN_COUNT_FILE_OFFSET)

	-- The performance cost of checking if a column is already in here is too significant.
	-- might be worth revisiting tho
	local cursor = COLUMN_BLOCK_FILE_OFFSET
	for _ = 1, column_count do
		cursor += buffer.readu16(buff, cursor)
	end

	-- While the name doesn't fit inside the current column block, keep growing
	const min_size = cursor + id_length
	while min_size > COLUMN_BLOCK_FILE_OFFSET + buffer.readu32(buff, COLUMN_BSIZE_FILE_OFFSET) do
		buff = column_grow_block(buff)
	end

	buffer.writeu16(buff, cursor, id_length)
	buffer.writestring(buff, cursor + 2, column_id)

	buffer.writeu32(buff, COLUMN_COUNT_FILE_OFFSET, column_count + 1)

	return buff
end

const function column_get_id(buff: buffer, column_idx: number): string
	local cursor = COLUMN_BLOCK_FILE_OFFSET

	for idx = 1, column_idx - 1 do
		cursor += buffer.readu16(buff, cursor)
	end

	return buffer.readstring(buff, cursor + 2, buffer.readu16(buff, cursor) - 2)
end

const function column_find_idx(buff: buffer, column_id: string): number?
	local cursor = COLUMN_BLOCK_FILE_OFFSET

	for idx = 1, buffer.readu32(buff, COLUMN_COUNT_FILE_OFFSET) do
		const name_len = buffer.readu16(buff, cursor)

		if buffer.readstring(buff, cursor + 2, name_len - 2) == column_id then
			return idx
		end

		cursor += name_len
	end

	return nil
end

const function column_block_end(buff: buffer): number
	return COLUMN_BLOCK_FILE_OFFSET + buffer.readu32(buff, COLUMN_BSIZE_FILE_OFFSET)
end

const function row_offset_of(buff: buffer, tgt: number)
	local cursor = column_block_end(buff) + 4

	for _ = 1, tgt - 1 do
		cursor += buffer.readu32(buff, cursor)
	end

	return cursor
end

const function row_find_empty_slot(buff: buffer)
	const row_block_start_offset = column_block_end(buff)

	local cursor = row_block_start_offset + 4
	for _ = 1, buffer.readu32(buff, row_block_start_offset) do
		cursor += buffer.readu32(buff, cursor)
	end

	return cursor
end

const function row_alloc(buff: buffer, row: number, bytes: number): buffer
	const row_offset = row_offset_of(buff, row)
	const row_size = buffer.readu32(buff, row_offset)

	local amt = ROW_STARTING_SIZE
	while amt < bytes do
		amt = (amt * 1.5) // 1
	end

	buffer.writeu32(buff, row_offset, row_size + amt)

	return grow_at(buff, row_offset + row_size, amt)
end

const function row_set_field(buff: buffer, buff_len: number, row: number, data: buffer): (buffer, number) end

const function row_get_field(buff: buffer, row: number): buffer end

return table.freeze({
	grow_at = grow_at,

	magic_string_check = magic_string_check,

	column_find_idx = column_find_idx,
	column_get_id = column_get_id,
	column_grow_block = column_grow_block,
	column_add = column_add,
	column_block_end = column_block_end,

	row_find_empty_slot = row_find_empty_slot,
	row_offset_of = row_offset_of,
	row_alloc = row_alloc,

	COLUMN_BSIZE_FILE_OFFSET = COLUMN_BSIZE_FILE_OFFSET,
	COLUMN_COUNT_FILE_OFFSET = COLUMN_COUNT_FILE_OFFSET,
	COLUMN_BLOCK_FILE_OFFSET = COLUMN_BLOCK_FILE_OFFSET,
	COLUMN_BSIZE_GROWTH_AMOUNT = COLUMN_BSIZE_GROWTH_AMOUNT,
	STARTING_SIZE = STARTING_SIZE,
	ROW_STARTING_SIZE = ROW_STARTING_SIZE,
})
