.include "SysCalls.asm"

.data
grid:    .space 144       # 6x6 grid = 36 words * 4 bytes = 144 bytes
space:   .asciiz " "      # single space, used as a separator when printing
newline: .asciiz "\n"     # newline, used to end each printed row

game_board_prompt: .asciiz "Behold, the game board:\n"
invalid_start_pos_prompt: .asciiz "Your start position is invalid. Try again.\n"

.text
.globl reset_game_board
.globl set_element
.globl get_element
.globl print_grid
.globl verify_starting_position

# reset_game_board()
# writes a diagonal pattern of values into the grid
# (row 0 -> 1, row 1 -> 2, row 2 -> 3, row 3 -> 3, row 4 -> 2, row 5 -> 1)
# uses $a0-$a2, calls set_element
reset_game_board:
	addi $sp, $sp, -4      # allocate 4 bytes of stack space
	sw   $ra, 0($sp)        # save return address (jal set_element will overwrite $ra)

	# 0, 0 = 1
	li   $a0, 0             # a0 = row 0
	li   $a1, 0             # a1 = col 0
	li   $a2, 1             # a2 = value 1
	jal  set_element         # grid[0][0] = 1

	# 1, 1 = 2
	li   $a0, 1             # a0 = row 1
	li   $a1, 1             # a1 = col 1
	li   $a2, 2             # a2 = value 2
	jal  set_element         # grid[1][1] = 2

	# 2, 2 = 3
	li   $a0, 2             # a0 = row 2
	li   $a1, 2             # a1 = col 2
	li   $a2, 3             # a2 = value 3
	jal  set_element         # grid[2][2] = 3

	# 3, 3 = 3
	li   $a0, 3             # a0 = row 3
	li   $a1, 3             # a1 = col 3
	li   $a2, 3             # a2 = value 3
	jal  set_element         # grid[3][3] = 3

	# 4, 4 = 2
	li   $a0, 4             # a0 = row 4
	li   $a1, 4             # a1 = col 4
	li   $a2, 2             # a2 = value 2
	jal  set_element         # grid[4][4] = 2

	# 5, 5 = 1
	li   $a0, 5             # a0 = row 5
	li   $a1, 5             # a1 = col 5
	li   $a2, 1             # a2 = value 1
	jal  set_element         # grid[5][5] = 1

	lw   $ra, 0($sp)        # restore return address
	addi $sp, $sp, 4        # deallocate stack space
	jr   $ra                # return to caller


# set_element(row, col, value)
# $a0 = row, $a1 = col, $a2 = value
# modifies $t2, $t3
set_element:
	# evil math of doom (of despair)
	mul  $t2, $a0, 6        # t2 = row * 6
	add  $t2, $t2, $a1      # t2 = row * 6 + col  (flat index into grid)
	mul  $t2, $t2, 4        # t2 = flat index * 4  (convert to byte offset)
	la   $t3, grid          # t3 = base address of grid
	add  $t3, $t3, $t2      # t3 = address of grid[row][col]
	sw   $a2, 0($t3)        # store value at that address
	jr   $ra                # return to caller


# get_element(row, col)
# $a0 = row, $a1 = col
# returns value in $v0
# modifies $t2, $t3
get_element:
	# the cousin of evil math of doom
	mul  $t2, $a0, 6        # t2 = row * 6
	add  $t2, $t2, $a1      # t2 = row * 6 + col  (flat index into grid)
	mul  $t2, $t2, 4        # t2 = flat index * 4  (convert to byte offset)
	la   $t3, grid          # t3 = base address of grid
	add  $t3, $t3, $t2      # t3 = address of grid[row][col]
	lw   $v0, 0($t3)        # load value at that address into return register
	jr   $ra                # return to caller


# verify_starting_position(row, col)
# $a0 = row, $a1 = col
# returns value in $v0
verify_starting_position:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)         # save caller's return address

	blt  $a0, 0, invalid_start    # row < 0 is out of bounds
	bge  $a0, 6, invalid_start    # row > 5 is out of bounds
	blt  $a1, 0, invalid_start    # col < 0 is out of bounds
	bge  $a1, 6, invalid_start    # col > 5 is out of bounds

	jal  get_element          # $v0 = grid[row][col]; safe now, $ra is saved

	move $t0, $v0             # stash the value before it can get clobbered
	beqz $t0, invalid_start

valid_start:
	li   $v0, 1               # return flag: valid
	j    verify_starting_position_done

invalid_start:
	li   $v0, SysPrintString # syscall code for printing a string
	la   $a0, invalid_start_pos_prompt   # a0 = address of prompt string
	syscall                  # print invalid message

	li   $v0, 0               # return flag: invalid

verify_starting_position_done:
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr   $ra

# print_grid()
# prints the full 6x6 grid, space-separated with one row per line
# modifies $t0, $t1, $a0, $a1, $v0
print_grid:
	li   $v0, SysPrintString 		# syscall code for printing a string
	la   $a0, game_board_prompt          	# a0 = address of game board propmt
	syscall  

	addi $sp, $sp, -8        # allocate 8 bytes of stack space
	sw   $ra, 4($sp)         # save return address
	sw   $s0, 0($sp)         # save s0 (callee-saved, used to hold col counter across the get_element call)

	li   $t0, 0              # row counter = 0

print_row_loop:
	li   $t1, 0           # col counter = 0

print_col_loop:
	move $s0, $t1           # stash col counter in s0

	move $a0, $t0            # a0 = row (arg 1 for get_element)
	move $a1, $t1            # a1 = col (arg 2 for get_element)
	jal  get_element          # v0 = grid[row][col]

	move $a0, $v0            # a0 = value to print
	li   $v0, SysPrintInt    # syscall code for printing an integer
	syscall                  # print grid[row][col]

	li   $v0, SysPrintString # syscall code for printing a string
	la   $a0, space          # a0 = address of space string
	syscall                  # print separating space

	move $t1, $s0            # restore col counter from s0
	addi $t1, $t1, 1         # col++
	blt  $t1, 6, print_col_loop   # repeat until col == 6

	li   $v0, SysPrintString # syscall code for printing a string
	la   $a0, newline        # a0 = address of newline string
	syscall                  # end of row: print newline

	addi $t0, $t0, 1        # row++
	blt  $t0, 6, print_row_loop   # repeat until row == 6

	lw   $s0, 0($sp)         # restore s0
	lw   $ra, 4($sp)         # restore return address
	addi $sp, $sp, 8         # deallocate stack space
	jr   $ra                 # return to caller
