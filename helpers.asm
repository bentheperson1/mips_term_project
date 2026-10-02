# %dst = byte offset of [row][col], with row and col in registers
# %dst must not be the same register as %col
.macro calc_offset(%dst, %row, %col)
	mul  %dst, %row, 6
	add  %dst, %dst, %col
	sll  %dst, %dst, 2
.end_macro

# %dst = %arr[row][col], with row and col in registers
# %dst must not be the same register as %col
.macro get_cell(%dst, %arr, %row, %col)
	calc_offset(%dst, %row, %col)
	lw   %dst, %arr(%dst)
.end_macro

# %arr[row][col] = %val, with row, col and val in registers
# modifies $t8
.macro set_cell(%arr, %row, %col, %val)
	calc_offset($t8, %row, %col)
	sw   %val, %arr($t8)
.end_macro

.macro print_int(%label)
	li   $v0, SysPrintInt
	la   $a0, %label
	syscall
.end_macro

.macro print_str(%label)
	li   $v0, SysPrintString
	la   $a0, %label
	syscall
.end_macro

.macro print_char_reg(%reg)
	li   $v0, SysPrintChar
	move $a0, %reg
	syscall
.end_macro


# grid[%r][%c] = %v, with r, c and v as constants
# modifies $t5, $t6, $t7, $t8
.macro number(%r, %c, %v)
	li   $t5, %r
	li   $t6, %c
	li   $t7, %v
	set_cell(grid, $t5, $t6, $t7)
.end_macro


# print entry %idx (a register) of a table of 4-byte strings
.macro print_entry(%table, %idx)
	sll  $t4, %idx, 2
	la   $a0, %table
	add  $a0, $a0, $t4
	li   $v0, SysPrintString
	syscall
.end_macro

