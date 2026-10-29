const btable = require("@src/btable")
const test = require("@std/test")

const function numbered_names(prefix: string, count: number): { string }
	const names: { string } = {}

	for index = 1, count do
		table.insert(names, `{prefix}{string.format("%02d", index)}`)
	end

	return names
end

const function column_block_size(buff: buffer): number
	return buffer.readu32(buff, buffer.len(buff) - btable.COLUMN_BSIZE_FILE_OFFSET)
end

const function column_block_start(buff: buffer): number
	return buffer.len(buff) - btable.COLUMN_COUNT_FILE_OFFSET - column_block_size(buff)
end

test.suite("new", function(suite)
	suite:case("produces a buffer recognised as a btable file", function(t)
		const sheet = btable.new({ "date" })

		t.that(btable.btable_check_format(sheet.buff))
	end)

	suite:case("keeps column names in the order given", function(t)
		const sheet = btable.new({ "date", "daily_revenue", "notes" })

		t.eq(sheet:columns(), { "date", "daily_revenue", "notes" })
	end)

	suite:case("has no columns for an empty column list", function(t)
		const sheet = btable.new({})

		t.eq(sheet:columns(), {})
	end)

	suite:case("measures column names in bytes rather than characters", function(t)
		const sheet = btable.new({ "café", "日付" })

		t.eq(sheet:columns(), { "café", "日付" })
	end)

	suite:case("keeps every column name when the column block has to grow", function(t)
		-- 11 byte entries, enough of them to overflow the initial block partway through
		const names = numbered_names("column_", btable.COLUMN_BSIZE_GROWTH_AMOUNT // 11 + 5)

		const sheet = btable.new(names)

		t.eq(sheet:columns(), names)
	end)

	suite:case("accepts a column name longer than the initial column block", function(t)
		const names: { string } = { "date", string.rep("x", btable.COLUMN_BSIZE_GROWTH_AMOUNT * 2) }

		const sheet = btable.new(names)

		t.eq(sheet:columns(), names)
	end)
end)

test.suite("parse", function(suite)
	suite:case("reads back the columns of a table made with new", function(t)
		const original = btable.new({ "date", "daily_revenue", "notes" })

		const sheet, columns = btable.parse(original.buff)

		t.eq(columns, { "date", "daily_revenue", "notes" })
		t.eq(sheet:columns(), columns)
	end)

	suite:case("accepts requested columns that the table has", function(t)
		const original = btable.new({ "date", "daily_revenue", "notes" })

		const sheet = btable.parse(original.buff, { "notes", "date" })

		t.eq(sheet:columns(), { "date", "daily_revenue", "notes" })
	end)

	suite:case("rejects a requested column the table does not have", function(t)
		const original = btable.new({ "date", "daily_revenue" })

		t.throwsWith("column notes does not exist in this btable", btable.parse, original.buff, { "date", "notes" })
	end)

	suite:case("leaves the input buffer intact", function(t)
		const original = btable.new({ "date", "daily_revenue" })

		btable.parse(original.buff)

		t.eq(original:columns(), { "date", "daily_revenue" })
	end)

	suite:case("gives the table its own copy of the buffer", function(t)
		const original = btable.new({ "date", "daily_revenue" })
		const sheet = btable.parse(original.buff)

		btable.column_add(sheet, "notes")

		t.eq(original:columns(), { "date", "daily_revenue" })
	end)

	suite:case("rejects a buffer that is not a btable", function(t)
		t.throwsWith("a non-btable buffer was passed into parse", btable.parse, buffer.fromstring("date,daily_revenue"))
	end)
end)

test.suite("btable_check_format", function(suite)
	suite:case("rejects a buffer without the format marker", function(t)
		t.never.that(btable.btable_check_format(buffer.fromstring("not a btable file")))
	end)

	suite:case("rejects a buffer shorter than the format marker", function(t)
		t.never.that(btable.btable_check_format(buffer.fromstring("<!bt")))
	end)
end)

test.suite("grow_at", function(suite)
	suite:case("opens a zeroed gap at the offset and shifts the rest right", function(t)
		const sheet = btable.new({})
		sheet.buff = buffer.fromstring("abcdef")

		btable.grow_at(sheet, 2, 3)

		t.eq(buffer.tostring(sheet.buff), "ab\0\0\0cdef")
	end)

	suite:case("handles offsets at either end of the buffer", function(t)
		const sheet = btable.new({})

		sheet.buff = buffer.fromstring("abc")
		btable.grow_at(sheet, 0, 2)
		t.eq(buffer.tostring(sheet.buff), "\0\0abc")

		sheet.buff = buffer.fromstring("abc")
		btable.grow_at(sheet, 3, 2)
		t.eq(buffer.tostring(sheet.buff), "abc\0\0")
	end)

	suite:case("stores the grown buffer on the table and returns it with its length", function(t)
		const sheet = btable.new({})
		sheet.buff = buffer.fromstring("abcdef")

		const grown, grown_len = btable.grow_at(sheet, 2, 3)

		t.that(grown == sheet.buff)
		t.eq(grown_len, buffer.len(grown))
		t.eq(grown_len, 9)
	end)
end)

test.suite("column_grow_block", function(suite)
	suite:case("records the added bytes in the column block size", function(t)
		const sheet = btable.new({ "date" })
		const old_len, old_size = buffer.len(sheet.buff), column_block_size(sheet.buff)

		btable.column_grow_block(sheet)

		t.that(buffer.len(sheet.buff) > old_len)
		t.eq(column_block_size(sheet.buff) - old_size, buffer.len(sheet.buff) - old_len)
	end)

	suite:case("keeps existing column names", function(t)
		-- fills the block exactly, so the gap has to open left of the whole name
		const name = string.rep("x", btable.COLUMN_BSIZE_GROWTH_AMOUNT - 2)
		const sheet = btable.new({ name })

		btable.column_grow_block(sheet)

		t.eq(sheet:columns(), { name })
	end)

	suite:case("keeps row data directly left of the column block", function(t)
		const sheet = btable.new({ "date" })
		buffer.writestring(sheet.buff, column_block_start(sheet.buff) - 4, "row!")

		btable.column_grow_block(sheet)

		t.eq(buffer.readstring(sheet.buff, column_block_start(sheet.buff) - 4, 4), "row!")
	end)

	suite:case("returns the grown buffer and its length", function(t)
		const sheet = btable.new({ "date" })

		const grown, grown_len = btable.column_grow_block(sheet)

		t.that(grown == sheet.buff)
		t.eq(grown_len, buffer.len(grown))
	end)
end)

test.suite("column_add", function(suite)
	suite:case("appends the column after the existing ones", function(t)
		const sheet = btable.new({ "date", "daily_revenue" })

		btable.column_add(sheet, "notes")

		t.eq(sheet:columns(), { "date", "daily_revenue", "notes" })
	end)
end)

test.suite("column_find_idx", function(suite)
	suite:case("returns the position of a column in the order columns were added", function(t)
		const sheet = btable.new({ "date", "daily_revenue", "notes" })

		t.eq(btable.column_find_idx(sheet.buff, "date"), 1)
		t.eq(btable.column_find_idx(sheet.buff, "daily_revenue"), 2)
		t.eq(btable.column_find_idx(sheet.buff, "notes"), 3)
	end)

	suite:case("returns nil for a column that does not exist", function(t)
		const sheet = btable.new({ "date", "daily_revenue" })

		t.eq(btable.column_find_idx(sheet.buff, "notes"), nil)
	end)

	suite:case("does not match a column that only shares a prefix with the name", function(t)
		const sheet = btable.new({ "date_created" })

		t.eq(btable.column_find_idx(sheet.buff, "date"), nil)
	end)
end)
