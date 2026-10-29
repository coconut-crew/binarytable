const binarytable = require("@src")
const format = require("@src/format")
const test = require("@std/test")

const function table_with_columns(names: { string }): buffer
	local buff = binarytable.new({}).bytes()

	for _, name in names do
		buff = format.column_add(buff, name)
	end

	return buff
end

const function column_block_end(buff: buffer): number
	return format.COLUMN_BLOCK_FILE_OFFSET + buffer.readu32(buff, format.COLUMN_BSIZE_FILE_OFFSET)
end

-- writes the row count and each row's size, sizes counting their own 4 byte header
const function write_rows(buff: buffer, row_sizes: { number })
	const row_block = column_block_end(buff)
	buffer.writeu32(buff, row_block, #row_sizes)

	local cursor = row_block + 4
	for _, size in row_sizes do
		buffer.writeu32(buff, cursor, size)
		cursor += size
	end
end

test.suite("row_find_empty_slot", function(suite)
	suite:case("returns the offset right after the row count for a table without rows", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })

		t.eq(format.row_find_empty_slot(buff), column_block_end(buff) + 4)
	end)

	suite:case("skips past every existing row", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })
		write_rows(buff, { 14, 10 })

		t.eq(format.row_find_empty_slot(buff), column_block_end(buff) + 4 + 14 + 10)
	end)

	suite:case("finds the row block after the column block has grown", function(t)
		const buff = table_with_columns({ string.rep("x", format.COLUMN_BSIZE_GROWTH_AMOUNT) })

		t.eq(format.row_find_empty_slot(buff), column_block_end(buff) + 4)
	end)
end)

test.suite("row_offset_of", function(suite)
	suite:case("returns the offset right after the row count for the first row", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })
		write_rows(buff, { 14, 10 })

		t.eq(format.row_offset_of(buff, 1), column_block_end(buff) + 4)
	end)

	suite:case("skips past the rows before the target", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })
		write_rows(buff, { 14, 10, 8 })

		t.eq(format.row_offset_of(buff, 3), column_block_end(buff) + 4 + 14 + 10)
	end)
end)

test.suite("row_alloc", function(suite)
	suite:case("grows the row by at least the requested bytes", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })
		write_rows(buff, { 14, 10 })
		const first_row = column_block_end(buff) + 4

		const grown = format.row_alloc(buff, 1, 100)

		t.that(buffer.readu32(grown, first_row) - 14 >= 100)
	end)

	suite:case("records the added bytes in the row size", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })
		write_rows(buff, { 14, 10 })
		const first_row = column_block_end(buff) + 4

		const grown = format.row_alloc(buff, 1, 100)

		t.eq(buffer.readu32(grown, first_row) - 14, buffer.len(grown) - buffer.len(buff))
	end)

	suite:case("keeps the row's existing data in place", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })
		write_rows(buff, { 14, 10 })
		const first_row = column_block_end(buff) + 4
		buffer.writestring(buff, first_row + 4, "row1")

		const grown = format.row_alloc(buff, 1, 100)

		t.eq(buffer.readstring(grown, first_row + 4, 4), "row1")
	end)

	suite:case("keeps the rows after it intact", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })
		write_rows(buff, { 14, 10 })
		const first_row = column_block_end(buff) + 4
		buffer.writestring(buff, first_row + 14 + 4, "row2")

		const grown = format.row_alloc(buff, 1, 100)
		const second_row = first_row + buffer.readu32(grown, first_row)

		t.eq(buffer.readu32(grown, second_row), 10)
		t.eq(buffer.readstring(grown, second_row + 4, 4), "row2")
	end)
end)
