.include "SysCalls.asm"

.data
.align 2
grid:		.space 144		# 6x6 numbers, 0 = empty
h_links:	.space 144		# 6x6, 1 = link between (r,c) and (r,c+1)
v_links:	.space 168		# 7x6, 1 = link between (r-1,c) and (r,c)
d_links:	.space 168		# 7x6, 1 = "/", 2 = "\" on junction right of column c
board_end:				# end of all four arrays (used by clear_board)

header:		.asciiz "    0   1   2   3   4   5   \n"
border_start:	.asciiz "  +"
row_wall:	.asciiz " |"
newline:	.asciiz "\n"
game_board_prompt: .asciiz "Behold, the game board:\n"
invalid_start_pos_prompt: .asciiz "Your start position is invalid. Try again.\n"

# every entry is 4 bytes (3 characters + null), so index * 4 = byte offset
segments:	.asciiz "---"		# index 0 = wall
		.asciiz " | "		# index 1 = vertical link

cells:		.asciiz "   "		# index 0 = empty
		.asciiz " 1 "
		.asciiz " 2 "
		.asciiz " 3 "
		.asciiz " 4 "
		.asciiz " 5 "
		.asciiz " 6 "
		.asciiz " 7 "
		.asciiz " 8 "
		.asciiz " 9 "

junctions:	.byte '+', '/', 92	# index = d_links value (92 = backslash in ascii)
separators:	.byte '|', '-'		# index = h_links value

.text
.globl reset_game_board
.globl clear_board
.globl set_element
.globl get_element
.globl print_board
.globl verify_starting_position

# ---------------------------------------------------------------- macros

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

# %dst = byte offset of [row][col], with row and col in registers
.macro calc_offset(%dst, %row, %col)
	mul  %dst, %row, 6
	add  %dst, %dst, %col
	sll  %dst, %dst, 2
.end_macro

# %dst = %arr[row][col], with row and col in registers
.macro get_cell(%dst, %arr, %row, %col)
	calc_offset(%dst, %row, %col)
	lw   %dst, %arr(%dst)
.end_macro

# %arr[row][col] = value, with row, col and value as constants
.macro set_cell(%arr, %r, %c, %v)
	li   $t8, %r
	mul  $t8, $t8, 6
	addi $t8, $t8, %c
	sll  $t8, $t8, 2
	li   $t9, %v
	sw   $t9, %arr($t8)
.end_macro

.macro number(%r, %c, %v)
	set_cell(grid, %r, %c, %v)
.end_macro

# ------------------------------------------------------------- functions

# clear_board()
# zeroes grid, h_links, v_links and d_links
clear_board:
	la   $t0, grid
	la   $t1, board_end
clear_loop:
	sw   $zero, 0($t0)
	addi $t0, $t0, 4
	bne  $t0, $t1, clear_loop
	jr   $ra


# reset_game_board()
# clears everything, then places the starting numbers
reset_game_board:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)

	jal  clear_board

	number(0, 0, 1)
	number(1, 1, 2)
	number(2, 2, 3)
	number(3, 3, 3)
	number(4, 4, 2)
	number(5, 5, 1)

	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr   $ra


# set_element(row, col, value)   $a0 = row, $a1 = col, $a2 = value
# writes into grid (the number layer). modifies $t2, $t3
set_element:
	calc_offset($t2, $a0, $a1)
	la   $t3, grid
	add  $t3, $t3, $t2
	sw   $a2, 0($t3)
	jr   $ra


# get_element(row, col)   $a0 = row, $a1 = col
# returns grid[row][col] in $v0. modifies $t2, $t3
get_element:
	calc_offset($t2, $a0, $a1)
	la   $t3, grid
	add  $t3, $t3, $t2
	lw   $v0, 0($t3)
	jr   $ra


# verify_starting_position(row, col)   $a0 = row, $a1 = col
# returns $v0 = 1 if in bounds and on a numbered cell, else 0 (prints a message)
verify_starting_position:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)

	blt  $a0, 0, invalid_start
	bge  $a0, 6, invalid_start
	blt  $a1, 0, invalid_start
	bge  $a1, 6, invalid_start

	jal  get_element
	beqz $v0, invalid_start

	li   $v0, 1
	j    verify_starting_position_done

invalid_start:
	print_str(invalid_start_pos_prompt)
	li   $v0, 0

verify_starting_position_done:
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr   $ra


# print_board()
# $t0 = row, $t1 = col, $t3 = value read
# leaf function (apart from syscalls), only $t registers are used
print_board:
	print_str(game_board_prompt)
	print_str(header)

	li   $t0, 0

row_loop:
	print_str(border_start)
	li   $t1, 0

border_loop:
	get_cell($t3, v_links, $t0, $t1)
	print_entry(segments, $t3)

	get_cell($t3, d_links, $t0, $t1)
	lb   $t3, junctions($t3)
	print_char_reg($t3)

	addi $t1, $t1, 1
	blt  $t1, 6, border_loop

	print_str(newline)

	beq  $t0, 6, print_done

	addi $t4, $t0, 48		# '0' + row
	print_char_reg($t4)
	print_str(row_wall)

	li   $t1, 0

cell_loop:
	get_cell($t3, grid, $t0, $t1)
	print_entry(cells, $t3)

	get_cell($t3, h_links, $t0, $t1)
	lb   $t3, separators($t3)
	print_char_reg($t3)

	addi $t1, $t1, 1
	blt  $t1, 6, cell_loop

	print_str(newline)

	addi $t0, $t0, 1
	j    row_loop

print_done:
	jr   $ra