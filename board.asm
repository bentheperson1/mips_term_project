.include "SysCalls.asm"
.include "helpers.asm"

.data
.align 2
.globl grid
.globl h_links
.globl v_links
.globl d_links
.globl board_end

grid:		.space 144		# 6x6 numbers, 0 = empty
h_links:		.space 144		# 6x6, 1 = link between (r,c) and (r,c+1)
v_links:		.space 168		# 7x6, 1 = link between (r-1,c) and (r,c)
d_links:		.space 168		# 7x6, 1 = "/", 2 = "\" on junction right of column c
owners:		.space 144		# 6x6 bools
board_end:				# end of all arrays (used by clear_board)

header:		.asciiz "    0   1   2   3   4   5   \n"
border_start:	.asciiz "  +"
row_wall:	.asciiz " |"
newline:		.asciiz "\n"
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
		.asciiz " 10"
		.asciiz " 11"
		.asciiz " 12"
		.asciiz " 13"
		.asciiz " 14""

junctions:	.byte '+', '/', 92	# index = d_links value (92 = backslash in ascii)
separators:	.byte '|', '-'		# index = h_links value

.text
.globl reset_game_board
.globl clear_board
.globl print_board
.globl verify_starting_position
.globl set_link


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


# verify_starting_position(row, col)   $a0 = row, $a1 = col
# returns $v0 = 1 if in bounds and on a numbered cell, else 0 (prints a message)
# leaf function, modifies $v0 and $a0 (when printing the error)
verify_starting_position:
	blt  $a0, 0, invalid_start
	bge  $a0, 6, invalid_start
	blt  $a1, 0, invalid_start
	bge  $a1, 6, invalid_start

	get_cell($v0, grid, $a0, $a1)
	beqz $v0, invalid_start

	li   $v0, 1
	jr   $ra

invalid_start:
	print_str(invalid_start_pos_prompt)
	li   $v0, 0
	jr   $ra


# set_link(r1, c1, r2, c2)   $a0 = r1, $a1 = c1, $a2 = r2, $a3 = c2
# links two adjacent cells (horizontal, vertical or diagonal)
# returns $v0 = 1 if the link was set, 0 if out of bounds or not adjacent
# leaf function, modifies $a0-$a3, $t0, $t8, $t9
set_link:
	# keep points in bounds
	blt  $a0, 0, link_invalid
	bge  $a0, 6, link_invalid
	blt  $a1, 0, link_invalid
	bge  $a1, 6, link_invalid
	blt  $a2, 0, link_invalid
	bge  $a2, 6, link_invalid
	blt  $a3, 0, link_invalid
	bge  $a3, 6, link_invalid

	# make sure the first cell is the upper one (r1 <= r2)
	ble  $a0, $a2, link_rows_ordered
	
	move $t0, $a0 # swap row cells
	move $a0, $a2
	move $a2, $t0
	
	move $t0, $a1 # swap column cells
	move $a1, $a3
	move $a3, $t0

link_rows_ordered:
	li   $t9, 1
	sub  $t0, $a2, $a0
	beq  $t0, 0, link_horizontal
	beq  $t0, 1, link_down
	j    link_invalid

link_horizontal:
	# left cell is whichever column is smaller
	blt  $a1, $a3, link_h_ordered
	move $t0, $a1
	move $a1, $a3
	move $a3, $t0

link_h_ordered:
	sub  $t0, $a3, $a1
	bne  $t0, 1, link_invalid

	set_cell(h_links, $a0, $a1, $t9)
	j    link_valid

link_down:
	sub  $t0, $a3, $a1
	beq  $t0, 0, link_vertical
	beq  $t0, 1, link_diag_back
	beq  $t0, -1, link_diag_forward
	j    link_invalid

link_vertical:
	set_cell(v_links, $a2, $a1, $t9)
	j    link_valid

link_diag_back:
	# "\" goes from (r, c) to (r + 1, c + 1), junction is right of column c
	li   $t9, 2
	set_cell(d_links, $a2, $a1, $t9)
	j    link_valid

link_diag_forward:
	# "/" goes from (r, c) to (r + 1, c - 1), junction is right of the smaller column
	set_cell(d_links, $a2, $a3, $t9)
	j    link_valid

link_valid:
	li   $v0, 1
	jr   $ra

link_invalid:
	li   $v0, 0
	jr   $ra
	

# print_board()
# $t0 = row, $t1 = col, $t3 = value read
# leaf function (apart from syscalls), only $t registers are used
print_board:
	#print_str(game_board_prompt)
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