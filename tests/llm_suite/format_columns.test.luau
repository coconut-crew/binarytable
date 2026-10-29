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

const function column_block_size(buff: buffer): number
	return buffer.readu32(buff, format.COLUMN_BSIZE_FILE_OFFSET)
end

const function column_block_end(buff: buffer): number
	return format.COLUMN_BLOCK_FILE_OFFSET + column_block_size(buff)
end

test.suite("column_grow_block", function(suite)
	suite:case("records the added bytes in the column block size", function(t)
		const buff = table_with_columns({ "date" })
		const old_size = column_block_size(buff)

		const grown = format.column_grow_block(buff)

		t.that(buffer.len(grown) > buffer.len(buff))
		t.eq(column_block_size(grown) - old_size, buffer.len(grown) - buffer.len(buff))
	end)

	suite:case("keeps existing column names", function(t)
		-- fills the block exactly, so the gap has to open after the whole name
		const name = string.rep("x", format.COLUMN_BSIZE_GROWTH_AMOUNT - 2)
		const buff = table_with_columns({ name })

		const grown = format.column_grow_block(buff)

		t.eq(format.column_find_idx(grown, name), 1)
	end)

	suite:case("keeps row data directly after the column block", function(t)
		const buff = table_with_columns({ "date" })
		buffer.writestring(buff, column_block_end(buff), "row!")

		const grown = format.column_grow_block(buff)

		t.eq(buffer.readstring(grown, column_block_end(grown), 4), "row!")
	end)
end)

test.suite("column_add", function(suite)
	suite:case("appends the column after the existing ones", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })

		const added = format.column_add(buff, "notes")

		t.eq(format.column_find_idx(added, "date"), 1)
		t.eq(format.column_find_idx(added, "notes"), 3)
	end)

	suite:case("keeps row data after the column block when the block has to grow", function(t)
		const buff = table_with_columns({ "date" })
		buffer.writestring(buff, column_block_end(buff), "row!")

		const added = format.column_add(buff, string.rep("x", format.COLUMN_BSIZE_GROWTH_AMOUNT))

		t.eq(buffer.readstring(added, column_block_end(added), 4), "row!")
	end)
end)

test.suite("column_find_idx", function(suite)
	suite:case("returns the position of a column in the order columns were added", function(t)
		const buff = table_with_columns({ "date", "daily_revenue", "notes" })

		t.eq(format.column_find_idx(buff, "date"), 1)
		t.eq(format.column_find_idx(buff, "daily_revenue"), 2)
		t.eq(format.column_find_idx(buff, "notes"), 3)
	end)

	suite:case("returns nil for a column that does not exist", function(t)
		const buff = table_with_columns({ "date", "daily_revenue" })

		t.eq(format.column_find_idx(buff, "notes"), nil)
	end)

	suite:case("does not match a column that only shares a prefix with the name", function(t)
		const buff = table_with_columns({ "date_created" })

		t.eq(format.column_find_idx(buff, "date"), nil)
	end)
end)

test.suite("column_get_id", function(suite)
	suite:case("returns the id of the column at each position", function(t)
		const buff = table_with_columns({ "date", "daily_revenue", "notes" })

		t.eq(format.column_get_id(buff, 1), "date")
		t.eq(format.column_get_id(buff, 2), "daily_revenue")
		t.eq(format.column_get_id(buff, 3), "notes")
	end)
end)

test.suite("column_block_end", function(suite)
	suite:case("ends right after the last column name when the names fill the block", function(t)
		const name = string.rep("x", format.COLUMN_BSIZE_GROWTH_AMOUNT - 2)
		const buff = table_with_columns({ name })

		t.eq(format.column_block_end(buff), format.COLUMN_BLOCK_FILE_OFFSET + 2 + string.len(name))
	end)

	suite:case("moves past every byte added when the column block grows", function(t)
		const buff = table_with_columns({ "date" })
		const old_end = format.column_block_end(buff)

		const grown = format.column_grow_block(buff)

		t.eq(format.column_block_end(grown) - old_end, buffer.len(grown) - buffer.len(buff))
	end)
end)
