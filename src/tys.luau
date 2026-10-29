-- Utils
export type function Or(ty: type, fallback: type)
	if ty.tag == "nil" then
		return fallback
	end

	return ty
end

export type function Truthy(ty: type, err: type)
	assert(err.tag == "singleton" and type(err:value()) == "string", "error messages must be stringletons")
	const err_str = err:value()
	assert(type(err_str) == "string")

	if ty.tag == "nil" then
		print(string.format(err_str, tostring(ty)))
		return types.never
	end

	return ty
end

-- Primitives
export type Column<Id, Data = buffer> = {
	-- Close enough, welcome back ByteNet

	-- Forced to return a buffer for safety reasons
	read write: (data: Data) -> buffer,

	-- ret: data, number
	read read: (buff: buffer, pos: number) -> (Data, number),

	write __T: Data,
}

-- Query overloads
type ErrColumnMissing = '"%*" is not a column'

type SafeQueryTerm<Columns, T> = Truthy<rawget<Columns, T>, ErrColumnMissing>

type SafeQuery<Columns> = <A>(a: A | "" | keyof<Columns>) -> () -> (number, SafeQueryTerm<Columns, A>)

type UnsafeQueryTerm<Columns, T> = Or<rawget<Columns, T>, buffer>

type UnsafeQuery<Columns> = <A>(a: A | "" | keyof<Columns>) -> () -> (number, UnsafeQueryTerm<Columns, A>)

-- public-facing APIs
export type BinaryTableHandle<Columns> = {
	bytes: () -> buffer,
	size: () -> number,

	-- row_push: (row: Row<Columns>) -> number,
	-- row_get: () -> Row<Columns>,
	-- row_remove: (pos: number) -> (),
	-- row_set: (pos: number, row: Row<Columns>) -> (),
	-- row_pop: (pos: number) -> Row<Columns>,
	-- sort: () -> (),

	rows: () -> {
		query: SafeQuery<Columns>,
		unsafe_query: UnsafeQuery<Columns>,
	},

	columns: () -> { keyof<Columns> },
}

type meow = BinaryTableHandle<{ mrrp: number }>

return nil
