.include "SysCalls.asm"
.include "helpers.asm"

.data
.align 2

grid:		.space GRID_BYTES	# 6x6 numbers, 0 = empty
h_links:	.space GRID_BYTES	# 6x6, 1 = link between (r,c) and (r,c+1)
v_links:	.space EDGE_BYTES	# 7x6, 1 = link between (r-1,c) and (r,c)
d_links:	.space EDGE_BYTES	# 7x6, 1 = "/", 2 = "\" on junction right of column c
owners:		.space GRID_BYTES	# 6x6 bools
board_end:				# end of all arrays (used by clear_board)

header:		.asciiz "\n\n    0   1   2   \n"
border_start:	.asciiz "  +"
row_wall:	.asciiz " |"
newline:	.asciiz "\n"

# every entry is 4 bytes (3 characters + null), so index * 4 = byte offset
segments:	.asciiz "---"		# index 0 = wall
		.asciiz " | "		# index 1 = vertical link

player_cells:	.asciiz "   "		# index 0 = empty
		.asciiz "P1 "
		.asciiz "P2 "
		.asciiz "P3 "
		.asciiz "P4 "
		.asciiz "P5 "
		.asciiz "P6 "
		.asciiz "P7 "
		.asciiz "P8 "
		.asciiz "P9 "


enemy_cells:	.asciiz "   "		# index 0 = empty
		.asciiz "E1 "
		.asciiz "E2 "
		.asciiz "E3 "
		.asciiz "E4 "
		.asciiz "E5 "
		.asciiz "E6 "
		.asciiz "E7 "
		.asciiz "E8 "
		.asciiz "E9 "

junctions:	.byte '+', '/', 92	# index = d_links value (92 = backslash in ascii)
separators:	.byte '|', '-'		# index = h_links value

.text
.globl clear_board
.globl reset_game_board
.globl print_board
.globl verify_starting_position
.globl try_move
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


# links two cells with constant coordinates by calling set_link
.macro link_cells(%r1, %c1, %r2, %c2)
	li   $a0, %r1
	li   $a1, %c1
	li   $a2, %r2
	li   $a3, %c2
	jal  set_link
.end_macro


# reset_game_board()
# clears everything, then places the starting numbers and links
reset_game_board:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)

	jal  clear_board

	# starting numbers
	li   $t0, 0
	li   $t1, 0
	li   $t2, 1
	li   $t3, 1
	set_cell(grid, $t0, $t1, $t2)
	set_cell(owners, $t0, $t1, $t3)

	li   $t0, 0
	li   $t1, 1
	li   $t2, 2
	li   $t3, 1
	set_cell(grid, $t0, $t1, $t2)
	set_cell(owners, $t0, $t1, $t3)
	
	li   $t0, 1
	li   $t1, 2
	li   $t2, 1
	li   $t3, 0
	set_cell(grid, $t0, $t1, $t2)
	set_cell(owners, $t0, $t1, $t3)

	li   $t0, 2
	li   $t1, 1
	li   $t2, 2
	li   $t3, 0
	set_cell(grid, $t0, $t1, $t2)
	set_cell(owners, $t0, $t1, $t3)
	
	
	# starting links
	link_cells(0, 0, 0, 1)
	link_cells(1, 2, 2, 1)
	
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr   $ra


# verify_starting_position(row, col)   $a0 = row, $a1 = col
# returns $v0 = 1 if in bounds and on a numbered cell, else 0
# leaf function, modifies $v0
verify_starting_position:
	blt  $a0, 0, start_invalid
	bge  $a0, BOARD_SIZE, start_invalid
	blt  $a1, 0, start_invalid
	bge  $a1, BOARD_SIZE, start_invalid

	get_cell($v0, grid, $a0, $a1)
	beqz $v0, start_invalid

	li   $v0, 1
	jr   $ra

start_invalid:
	li   $v0, 0
	jr   $ra


# try_move(row, col, row_offset, col_offset)
# $a0 = origin row, $a1 = origin col, $a2 = row offset, $a3 = col offset
# fills the neighbouring cell with origin + 1 and links the two cells
# returns $v0 = 1 if the move was made, 0 if it leaves the board or the target is taken
# modifies $a2, $a3, $t0-$t4, $t8, $t9
try_move:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)

	# value at the origin cell
	get_cell($t2, grid, $a0, $a1)

	# target cell = origin + offset
	add  $t0, $a0, $a2
	add  $t1, $a1, $a3

	# stay on the board
	blt  $t0, 0, try_move_fail
	bge  $t0, BOARD_SIZE, try_move_fail
	blt  $t1, 0, try_move_fail
	bge  $t1, BOARD_SIZE, try_move_fail

	# target must be empty
	get_cell($t4, grid, $t0, $t1)
	bnez $t4, try_move_fail

	# new cell = origin + 1
	addi $t3, $t2, 1
	set_cell(grid, $t0, $t1, $t3)

	# link origin to the new cell ($a0 and $a1 are still the origin)
	move $a2, $t0
	move $a3, $t1
	jal  set_link

	li   $v0, 1
	j    try_move_done

try_move_fail:
	li   $v0, 0

try_move_done:
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr   $ra


# set_link(r1, c1, r2, c2)   $a0 = r1, $a1 = c1, $a2 = r2, $a3 = c2
# links two adjacent cells (horizontal, vertical or diagonal)
# returns $v0 = 1 if the link was set, 0 if out of bounds or not adjacent
# leaf function, modifies $a0-$a3, $t0, $t8, $t9
set_link:
	# keep points in bounds
	blt  $a0, 0, link_invalid
	bge  $a0, BOARD_SIZE, link_invalid
	blt  $a1, 0, link_invalid
	bge  $a1, BOARD_SIZE, link_invalid
	blt  $a2, 0, link_invalid
	bge  $a2, BOARD_SIZE, link_invalid
	blt  $a3, 0, link_invalid
	bge  $a3, BOARD_SIZE, link_invalid

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
	blt  $t1, BOARD_SIZE, border_loop

	print_str(newline)

	beq  $t0, BOARD_SIZE, print_done

	addi $t4, $t0, 48		# '0' + row
	print_char_reg($t4)
	print_str(row_wall)

	li   $t1, 0

cell_loop:
	get_cell($t3, grid, $t0, $t1)
	get_cell($t5, owners, $t0, $t1)

	la   $t6, player_cells
	beqz $t5, cell_owner_set
	la   $t6, enemy_cells

cell_owner_set:
	print_entry_reg($t6, $t3)

	get_cell($t3, h_links, $t0, $t1)
	lb   $t3, separators($t3)
	print_char_reg($t3)

	addi $t1, $t1, 1
	blt  $t1, BOARD_SIZE, cell_loop

	print_str(newline)

	addi $t0, $t0, 1
	j    row_loop

print_done:
	jr   $ra