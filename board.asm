.include "SysCalls.asm"				# syscall number constants
.include "helpers.asm"				# shared constants and macros

.data
.align 2					# start on a word boundary so sw/lw work on the arrays

grid:		.space GRID_BYTES		# 6x6 numbers, 0 = empty
h_links:	.space GRID_BYTES		# 6x6, 1 = link between (r,c) and (r,c+1)
v_links:	.space EDGE_BYTES		# 7x6, 1 = link between (r-1,c) and (r,c)
d_links:	.space EDGE_BYTES		# 7x6, 1 = "/", 2 = "\" on junction right of column c
owners:		.space GRID_BYTES		# 6x6 bools (0 = player, 1 = computer)
board_end:					# end of all arrays (used by clear_board)

header:		.asciiz "\n\n    0   1   2   3   4   5   \n"		# column numbers printed above the board
border_start:	.asciiz "  +"						# left edge of each border line
row_wall:	.asciiz " |"						# left wall printed after the row number
newline:	.asciiz "\n"
new_board_space: .asciiz "\n\n==========================================\n\n"	# divider printed between boards

# every entry is 4 bytes (3 characters + null), so index * 4 = byte offset
segments:	
	.asciiz "---"			# index 0 = wall
	.asciiz " | "			# index 1 = vertical link

player_cells:	
	.asciiz "   "			# index 0 = empty
	.asciiz "P 1"			# index 1 ... (the number is the index)
	.asciiz "P 2"
	.asciiz "P 3"
	.asciiz "P 4"
	.asciiz "P 5"
	.asciiz "P 6"
	.asciiz "P 7"
	.asciiz "P 8"
	.asciiz "P 9"
	.asciiz "P10"
	.asciiz "P11"
	.asciiz "P12"
	.asciiz "P13"
	.asciiz "P14"
	.asciiz "P15"
	.asciiz "P16"
	.asciiz "P17"
	.asciiz "P18"
	.asciiz "P19"
	.asciiz "P20"

enemy_cells:	
	.asciiz "   "			# index 0 = empty
	.asciiz "E 1"			# same layout as player_cells but for the computer
	.asciiz "E 2"
	.asciiz "E 3"
	.asciiz "E 4"
	.asciiz "E 5"
	.asciiz "E 6"
	.asciiz "E 7"
	.asciiz "E 8"
	.asciiz "E 9"
	.asciiz "E10"
	.asciiz "E11"
	.asciiz "E12"
	.asciiz "E13"
	.asciiz "E14"
	.asciiz "E15"
	.asciiz "E16"
	.asciiz "E17"
	.asciiz "E18"
	.asciiz "E19"
		.asciiz "E20"

junctions:	.byte '+', '/', 92		# index = d_links value (92 = backslash in ascii)
separators:	.byte '|', '-'			# index = h_links value

.text
.globl clear_board				# make these visible to the other files
.globl reset_game_board
.globl print_board
.globl set_link
.globl grid
.globl owners
.globl new_board_space

# clear_board()
# zeroes grid, h_links, v_links, d_links and owners
clear_board:
	la   $t0, grid				# t0 = current address, starts at the first array
	la   $t1, board_end			# t1 = address just past the last array

clear_loop:
	sw   $zero, 0($t0)			# write a 0 word
	addi $t0, $t0, 4			# advance one word
	bne  $t0, $t1, clear_loop		# repeat until the end is reached
	jr   $ra				# return


# links two cells with constant coordinates by calling set_link
.macro link_cells(%r1, %c1, %r2, %c2)
	li   $a0, %r1				# a0 = first cell row
	li   $a1, %c1				# a1 = first cell col
	li   $a2, %r2				# a2 = second cell row
	li   $a3, %c2				# a3 = second cell col
	jal  set_link				# draw the link
.end_macro


# reset_game_board()
# clears everything, then places the starting numbers and links
reset_game_board:
	addi $sp, $sp, -4			# make room on the stack
	sw   $ra, 0($sp)			# save the return address (we call other functions)

	jal  clear_board			# wipe the board

	# starting numbers
	li   $t0, 0				# row 0
	li   $t1, 0				# col 0
	li   $t2, 1				# number 1
	li   $t3, 0				# owner = player
	set_cell(grid, $t0, $t1, $t2)		# grid[0][0] = 1
	set_cell(owners, $t0, $t1, $t3)		# owners[0][0] = player

	li   $t0, 1				# row 1
	li   $t1, 1				# col 1
	li   $t2, 2				# number 2
	li   $t3, 0				# owner = player
	set_cell(grid, $t0, $t1, $t2)		# grid[1][1] = 2
	set_cell(owners, $t0, $t1, $t3)		# owners[1][1] = player

	li   $t0, 2				# row 2
	li   $t1, 2				# col 2
	li   $t2, 3				# number 3
	li   $t3, 0				# owner = player
	set_cell(grid, $t0, $t1, $t2)		# grid[2][2] = 3
	set_cell(owners, $t0, $t1, $t3)		# owners[2][2] = player

	li   $t0, 3				# row 3
	li   $t1, 3				# col 3
	li   $t2, 3				# number 3
	li   $t3, 1				# owner = computer
	set_cell(grid, $t0, $t1, $t2)		# grid[3][3] = 3
	set_cell(owners, $t0, $t1, $t3)		# owners[3][3] = computer

	li   $t0, 4				# row 4
	li   $t1, 4				# col 4
	li   $t2, 2				# number 2
	li   $t3, 1				# owner = computer
	set_cell(grid, $t0, $t1, $t2)		# grid[4][4] = 2
	set_cell(owners, $t0, $t1, $t3)		# owners[4][4] = computer

	li   $t0, 5				# row 5
	li   $t1, 5				# col 5
	li   $t2, 1				# number 1
	li   $t3, 1				# owner = computer
	set_cell(grid, $t0, $t1, $t2)		# grid[5][5] = 1
	set_cell(owners, $t0, $t1, $t3)		# owners[5][5] = computer

	# starting links
	link_cells(0, 0, 1, 1)			# player 1 -> player 2
	link_cells(1, 1, 2, 2)			# player 2 -> player 3
	link_cells(3, 3, 4, 4)			# computer 3 -> computer 2
	link_cells(4, 4, 5, 5)			# computer 2 -> computer 1

	lw   $ra, 0($sp)			# restore the return address
	addi $sp, $sp, 4			# free the stack space
	jr   $ra				# return


# set_link(r1, c1, r2, c2)   $a0 = r1, $a1 = c1, $a2 = r2, $a3 = c2
# links two adjacent cells (horizontal, vertical or diagonal)
# returns $v0 = 1 if the link was set, 0 if out of bounds or not adjacent
# leaf function, modifies $a0-$a3, $t0, $t8, $t9
set_link:
	# keep points in bounds
	blt  $a0, 0, link_invalid		# r1 too small
	bge  $a0, BOARD_SIZE, link_invalid	# r1 too big
	blt  $a1, 0, link_invalid		# c1 too small
	bge  $a1, BOARD_SIZE, link_invalid	# c1 too big
	blt  $a2, 0, link_invalid		# r2 too small
	bge  $a2, BOARD_SIZE, link_invalid	# r2 too big
	blt  $a3, 0, link_invalid		# c2 too small
	bge  $a3, BOARD_SIZE, link_invalid	# c2 too big

	# make sure the first cell is the upper one (r1 <= r2)
	ble  $a0, $a2, link_rows_ordered	# already in order

	move $t0, $a0				# swap row cells
	move $a0, $a2
	move $a2, $t0

	move $t0, $a1				# swap column cells
	move $a1, $a3
	move $a3, $t0

link_rows_ordered:
	li   $t9, 1				# default link value = 1
	sub  $t0, $a2, $a0			# t0 = row difference (0 or more now)
	beq  $t0, 0, link_horizontal		# same row
	beq  $t0, 1, link_down			# one row apart
	j    link_invalid			# further apart than 1, not adjacent

link_horizontal:
	# left cell is whichever column is smaller
	blt  $a1, $a3, link_h_ordered		# already left to right
	move $t0, $a1						# swap columns so a1 is the left one
	move $a1, $a3
	move $a3, $t0

link_h_ordered:
	sub  $t0, $a3, $a1					# t0 = column difference
	bne  $t0, 1, link_invalid			# must be exactly side by side

	set_cell(h_links, $a0, $a1, $t9)	# h_links[row][left col] = 1
	j    link_valid

link_down:
	sub  $t0, $a3, $a1					# t0 = column difference
	beq  $t0, 0, link_vertical			# same column, straight down
	beq  $t0, 1, link_diag_back			# down and right, "\"
	beq  $t0, -1, link_diag_forward		# down and left, "/"
	j    link_invalid					# too far sideways

link_vertical:
	set_cell(v_links, $a2, $a1, $t9)	# v_links[lower row][col] = 1
	j    link_valid

link_diag_back:
	# "\" goes from (r, c) to (r + 1, c + 1), junction is right of column c
	li   $t9, 2							# 2 = "\"
	set_cell(d_links, $a2, $a1, $t9)	# d_links[lower row][left col] = 2
	j    link_valid

link_diag_forward:
	# "/" goes from (r, c) to (r + 1, c - 1), junction is right of the smaller column
	set_cell(d_links, $a2, $a3, $t9)	# d_links[lower row][smaller col] = 1 ("/")
	j    link_valid

link_valid:
	li   $v0, 1							# link was set
	jr   $ra

link_invalid:
	li   $v0, 0							# link was not set
	jr   $ra


# print_board()
# $t0 = row, $t1 = col, $t3 = value read
# leaf function (apart from syscalls), only $t registers are used
print_board:
	print_str(header)					# print the column numbers

	li   $t0, 0							# start at row 0

row_loop:
	print_str(border_start)				# "  +" at the start of the border line
	li   $t1, 0							# start at col 0

border_loop:
	get_cell($t3, v_links, $t0, $t1)	# t3 = vertical link above this cell (0 or 1)
	print_entry(segments, $t3)			# print "---" or " | "

	get_cell($t3, d_links, $t0, $t1)	# t3 = diagonal link value at this junction (0, 1, 2)
	lb   $t3, junctions($t3)			# t3 = the character for it ('+', '/' or '\')
	print_char_reg($t3)					# print the junction character

	addi $t1, $t1, 1					# next column
	blt  $t1, BOARD_SIZE, border_loop	# repeat for all columns

	print_str(newline)					# end the border line

	beq  $t0, BOARD_SIZE, print_done	# the last border line is printed after the final row

	addi $t4, $t0, 48					# '0' + row
	print_char_reg($t4)					# print the row number
	print_str(row_wall)					# print " |"

	li   $t1, 0							# back to col 0 for the cell line

cell_loop:
	get_cell($t3, grid, $t0, $t1)		# t3 = number in this cell
	get_cell($t5, owners, $t0, $t1)		# t5 = owner of this cell

	la   $t6, player_cells				# assume the player owns it
	beqz $t5, cell_owner_set			# owner 0 = player, keep player_cells

	la   $t6, enemy_cells				# otherwise use the computer's labels

cell_owner_set:
	print_entry_reg($t6, $t3)			# print the label for this number (e.g. "P 3")

	get_cell($t3, h_links, $t0, $t1)	# t3 = horizontal link to the right (0 or 1)
	lb   $t3, separators($t3)			# t3 = '|' if no link, '-' if linked
	print_char_reg($t3)					# print the separator

	addi $t1, $t1, 1					# next column
	blt  $t1, BOARD_SIZE, cell_loop		# repeat for all columns

	print_str(newline)					# end the cell line

	addi $t0, $t0, 1					# next row
	j    row_loop

print_done:
	jr   $ra