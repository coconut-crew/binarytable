const binarytable = require("@src")
const format = require("@src/format")
const test = require("@std/test")

const function numbered_names(prefix: string, count: number): { string }
	const names: { string } = {}

	for index = 1, count do
		table.insert(names, `{prefix}{string.format("%02d", index)}`)
	end

	return names
end

const function column_table(names: { string }): { [string]: string }
	const columns: { [string]: string } = {}

	for _, name in names do
		columns[name] = ""
	end

	return columns
end

-- lets cases about which columns exist pass or fail independently of column order
const function sorted<T>(names: { T }): { T }
	const copy = table.clone(names)
	table.sort(copy)
	return copy
end

test.suite("new", function(suite)
	suite:case("produces bytes recognised as a btable file", function(t)
		const sheet = binarytable.new({ date = "" })

		t.that(format.magic_string_check(sheet.bytes()))
	end)

	suite:case("starts with a column block of one growth step", function(t)
		const sheet = binarytable.new({})

		t.eq(buffer.readu32(sheet.bytes(), format.COLUMN_BSIZE_FILE_OFFSET), format.COLUMN_BSIZE_GROWTH_AMOUNT)
	end)

	suite:case("has a column for every key of the column table", function(t)
		const sheet = binarytable.new({ date = "", daily_revenue = 0, notes = "" })

		t.eq(sorted(sheet.columns()), { "daily_revenue", "date", "notes" })
	end)

	suite:case("orders columns alphabetically regardless of the column table's layout", function(t)
		const names = { "status", "amount", "region", "notes", "customer", "date", "daily_revenue" }

		const sheet = binarytable.new(column_table(names))

		t.eq(sheet.columns(), sorted(names))
	end)

	suite:case("has no columns for an empty column table", function(t)
		const sheet = binarytable.new({})

		t.eq(sheet.columns(), {})
	end)

	suite:case("measures column names in bytes rather than characters", function(t)
		const sheet = binarytable.new({ ["café"] = "", ["日付"] = "" })

		t.eq(sorted(sheet.columns()), { "café", "日付" })
	end)

	suite:case("keeps every column name when the column block has to grow", function(t)
		-- 11 byte entries, enough of them to overflow the initial block partway through
		const names = numbered_names("column_", format.COLUMN_BSIZE_GROWTH_AMOUNT // 11 + 5)

		const sheet = binarytable.new(column_table(names))

		t.eq(sorted(sheet.columns()), names)
	end)

	suite:case("accepts a column name longer than the initial column block", function(t)
		const long_name = string.rep("x", format.COLUMN_BSIZE_GROWTH_AMOUNT * 2)

		const sheet = binarytable.new(column_table({ "date", long_name }))

		t.eq(sorted(sheet.columns()), { "date", long_name })
	end)
end)
