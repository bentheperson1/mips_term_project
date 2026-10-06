.eqv BOARD_SIZE 3
.eqv GRID_BYTES 36		# BOARD_SIZE * BOARD_SIZE * 4
.eqv EDGE_BYTES 48		# (BOARD_SIZE + 1) * BOARD_SIZE * 4

# calls try_move with the origin cell and the direction offsets
# arguments are registers
# returns $v0 = 1 if the move was made, 0 if it was rejected
# modifies $a0-$a3, plus whatever try_move modifies ($t0-$t4, $t8, $t9)
.macro attempt_move(%row, %col, %row_ofs, %col_ofs)
	move $a0, %row
	move $a1, %col
	move $a2, %row_ofs
	move $a3, %col_ofs
	jal  try_move
.end_macro

# %dst = byte offset of [row][col], with row and col in registers
# %dst must not be the same register as %col
.macro calc_offset(%dst, %row, %col)
	mul  %dst, %row, BOARD_SIZE
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

# print entry %idx (a register) of a table of 4-byte strings
.macro print_entry(%table, %idx)
	sll  $t4, %idx, 2
	la   $a0, %table
	add  $a0, $a0, $t4
	li   $v0, SysPrintString
	syscall
.end_macro

# print entry %idx (a register) of a table of 4-byte strings, where %table is a register holding the table's address
# modifies $t4
.macro print_entry_reg(%table, %idx)
	sll  $t4, %idx, 2
	add  $a0, %table, $t4
	li   $v0, SysPrintString
	syscall
.end_macro
