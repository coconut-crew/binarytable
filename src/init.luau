const format = require("@src/format")
const tys = require("@src/tys")

type Handle<T = string> = tys.BinaryTableHandle<T>
type PHandle = {
	set_buff: (new_buff: buffer) -> (),
}

const function handle<T>(buff: buffer): (Handle<T>, PHandle)
	-- Column-based functions
	const function handle_columns()
		const names = {}

		for idx = 1, buffer.readu32(buff, format.COLUMN_COUNT_FILE_OFFSET) do
			table.insert(names, format.column_get_id(buff, idx))
		end

		return names :: any
	end

	-- Row-based functions
	const function handle_rows() end

	-- Buffer util functions
	const function handle_bytes(): buffer
		return buff
	end

	const function handle_size()
		return buffer.len(buff)
	end

	const function p_handle_set_buff(new_buff: buffer)
		buff = new_buff
	end

	const handle: Handle<T> = {
		columns = handle_columns,
		rows = handle_rows,

		bytes = handle_bytes,
		size = handle_size,
	}
	const p_handle: PHandle = {
		set_buff = p_handle_set_buff,
	}
	return handle, p_handle
end

const binarytable = {
	serdes = {
		boolean = true,
	},
}

function binarytable.new<ColumnTable>(column_table: ColumnTable): tys.BinaryTableHandle<ColumnTable>
	local buff = buffer.create(format.STARTING_SIZE)
	buffer.writestring(buff, 0, "<!btable")
	buffer.writeu32(buff, format.COLUMN_BSIZE_FILE_OFFSET, format.COLUMN_BSIZE_GROWTH_AMOUNT)

	const obj_handle, obj_p_handle = handle<<ColumnTable>>(buff)

	--[=[ Column handling ]=]

	-- alphanumerical sort for stability
	const keys: { string } = {}

	for key: string in column_table :: any do
		table.insert(keys, key)
	end

	table.sort(keys)

	-- add the columns in memory
	for _, key in keys do
		buff = format.column_add(buff, key)
	end
	obj_p_handle.set_buff(buff)

	--[=[ idk what would even go here yet ]=]

	return obj_handle
end

function binarytable.parse<ColumnTable>(buff: buffer, column_table: ColumnTable?): tys.BinaryTableHandle<ColumnTable>
	-- TODO implement this will be empty for now
end

return table.freeze(binarytable)
