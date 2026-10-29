# structure

## 1. start

- format marker (`<!btable`): 8 bytes

## 2. rows

stored in reverse, from right to left

- row count u32: 4 bytes

then, for each row:

- size for the entire row, u32. keep in mind this has padding, all bytes are not guaranteed to be filled. grows at 1.5x multiplier
- size array for all columns, u32 for each (e.g. row 1 column 1 takes 23 bytes)
- cell data (length decided by size array index)

## 3. columns

stored in reverse, length at the right side, data on the left side.

- total column block size (u32, 4 bytes)
- column count (u32, 4 bytes)

then for each column:

- column length: u16
- column data: ...
- repeat

# common procedures and how they happen

## cell data lookup

1. move cursor to eof -> iter thru column until find right name. that idx is the one to search for
2.

## add column

## add row
