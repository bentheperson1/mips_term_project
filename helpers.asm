.eqv BOARD_SIZE 6				# the board is 6 x 6 cells
.eqv GRID_BYTES 144				# BOARD_SIZE * BOARD_SIZE * 4
.eqv EDGE_BYTES 168				# (BOARD_SIZE + 1) * BOARD_SIZE * 4

# calls try_move with the origin cell and the direction offsets
# arguments are registers
# returns $v0 = 1 if the move was made, 0 if it was rejected
# modifies $a0-$a3, plus whatever try_move modifies ($t0-$t4, $t8, $t9)
.macro attempt_move(%row, %col, %row_ofs, %col_ofs)
	move $a0, %row				# a0 = origin row
	move $a1, %col				# a1 = origin col
	move $a2, %row_ofs			# a2 = row offset
	move $a3, %col_ofs			# a3 = col offset
	jal  try_move				# try the move, result in v0
.end_macro

# %dst = byte offset of [row][col], with row and col in registers
# %dst must not be the same register as %col
.macro calc_offset(%dst, %row, %col)
	mul  %dst, %row, BOARD_SIZE		# dst = row * 6
	add  %dst, %dst, %col			# dst = row * 6 + col (the cell index)
	sll  %dst, %dst, 2			# dst = index * 4 (each cell is one 4 byte word)
.end_macro

# %dst = %arr[row][col], with row and col in registers
# %dst must not be the same register as %col
.macro get_cell(%dst, %arr, %row, %col)
	calc_offset(%dst, %row, %col)		# dst = byte offset of the cell
	lw   %dst, %arr(%dst)			# dst = word at array base + offset
.end_macro

# %arr[row][col] = %val, with row, col and val in registers
# modifies $t8
.macro set_cell(%arr, %row, %col, %val)
	calc_offset($t8, %row, %col)		# t8 = byte offset of the cell
	sw   %val, %arr($t8)			# store the value at array base + offset
.end_macro

# prints the integer stored in %reg
.macro print_int_reg(%reg)
	li   $v0, SysPrintInt			# syscall: print integer
	move $a0, %reg				# a0 = value to print
	syscall
.end_macro

# prints the integer stored in the word at %label
.macro print_int(%label)
	li   $v0, SysPrintInt			# syscall: print integer
	lw   $a0, %label			# a0 = the value stored at the label
	syscall
.end_macro

# prints the null terminated string at %label
.macro print_str(%label)
	li   $v0, SysPrintString		# syscall: print string
	la   $a0, %label			# a0 = address of the string
	syscall
.end_macro

# prints the character whose ascii code is in %reg
.macro print_char_reg(%reg)
	li   $v0, SysPrintChar			# syscall: print character
	move $a0, %reg				# a0 = character to print
	syscall
.end_macro

# print entry %idx (a register) of a table of 4-byte strings
# modifies $t4
.macro print_entry(%table, %idx)
	sll  $t4, %idx, 2			# t4 = index * 4 (each entry is 4 bytes)
	la   $a0, %table			# a0 = start of the table
	add  $a0, $a0, $t4			# a0 = address of the chosen entry
	li   $v0, SysPrintString		# syscall: print string
	syscall
.end_macro

# dest = random number between min and max (inclusive), min and max must be constants
.macro irandom_range(%dest, %min, %max)
	li   $v0, SysRandIntRange		# syscall: random int in range
	li   $a0, 0				# select random number generator 0

	# calculate range size: upper - lower + 1
	li   $a1, %max				# a1 = max
	subi $a1, $a1, %min			# a1 = max - min
	addi $a1, $a1, 1			# a1 = (max - min + 1)
	syscall					# returns random number in $a0 from 0 to ($a1 - 1)

	add  %dest, $a0, %min			# shift range up by lower bound (%min)
.end_macro

# print entry %idx (a register) of a table of 4-byte strings, where %table is a register holding the table's address
# modifies $t4
.macro print_entry_reg(%table, %idx)
	sll  $t4, %idx, 2			# t4 = index * 4 (each entry is 4 bytes)
	add  $a0, %table, $t4			# a0 = table address + offset
	li   $v0, SysPrintString		# syscall: print string
	syscall
.end_macro

# compare_string(str1, str2, result, t1, t2)
# compares two null terminated strings
# %result = 1 if they are identical, 0 if not
# modifies $t7, $t8 (working pointers) plus the two temp registers passed in
.macro compare_string(%str1, %str2, %result, %t1, %t2)
	move $t7, %str1				# copy pointer 1 (so the caller's register is left untouched)
	move $t8, %str2				# copy pointer 2
	li   %result, 1				# assume equal initially

_loop:
	lb   %t1, 0($t7)			# load byte from string 1
	lb   %t2, 0($t8)			# load byte from string 2

	bne  %t1, %t2, _notequal		# if bytes do not match, strings are not equal
	beq  %t1, $zero, _done			# if both are null terminator '\0', strings match completely

	addi $t7, $t7, 1			# move to next char in string 1
	addi $t8, $t8, 1			# move to next char in string 2
	j    _loop				# check the next pair of characters

_notequal:
	li   %result, 0				# set result to 0 (not equal)

_done:
.end_macro