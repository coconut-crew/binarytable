const format = require("@src/format")
const test = require("@std/test")

test.suite("magic_string_check", function(suite)
	suite:case("rejects a buffer without the format marker", function(t)
		t.never.that(format.magic_string_check(buffer.fromstring("not a btable file")))
	end)

	suite:case("rejects a buffer shorter than the format marker", function(t)
		t.never.that(format.magic_string_check(buffer.fromstring("<!bt")))
	end)
end)

test.suite("grow_at", function(suite)
	suite:case("opens a zeroed gap at the offset and shifts the rest right", function(t)
		const grown = format.grow_at(buffer.fromstring("abcdef"), 2, 3)

		t.eq(buffer.tostring(grown), "ab\0\0\0cdef")
	end)

	suite:case("handles offsets at either end of the buffer", function(t)
		t.eq(buffer.tostring(format.grow_at(buffer.fromstring("abc"), 0, 2)), "\0\0abc")
		t.eq(buffer.tostring(format.grow_at(buffer.fromstring("abc"), 3, 2)), "abc\0\0")
	end)

	suite:case("leaves the input buffer untouched", function(t)
		const original = buffer.fromstring("abcdef")

		format.grow_at(original, 2, 3)

		t.eq(buffer.tostring(original), "abcdef")
	end)
end)
