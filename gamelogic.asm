.include "SysCalls.asm"						# syscall number constants
.include "helpers.asm"						# shared constants and macros

.data
computer_no_move_prompt:	.asciiz "\nThe computer has no moves left. Your turn again.\n"				# shown when the computer can't move
computer_move_prompt:		.asciiz "The computer made a move.\n"										# shown after the computer moves
player_no_move_prompt:		.asciiz "\nYou have no moves left. The computer goes again.\n"				# shown when the player has to pass
game_over_prompt:			.asciiz "\nThe board is full. Game over!\n\n"								# shown when the board is filled
player_score_prompt:		.asciiz "Your highest number: "												# label for the player's score
computer_score_prompt:		.asciiz "\nThe computer's highest number: "									# label for the computer's score
player_wins_prompt:			.asciiz "\n\nCongratulations, you win! That was some great chaining!\n"		# congratulate the player
computer_wins_prompt:		.asciiz "\n\nThe computer wins this time. Sorry, better luck next game!\n"	# commiserate with the player
tie_prompt:					.asciiz "\n\nIt's a tie! Well played by both sides.\n"						# shown when both sides have the same highest number

.align 2																								# word tables must start on a word boundary

# direction order: u, d, l, r, ur, ul, dr, dl
dir_row_ofs:	.word -1, 1, 0, 0, -1, -1, 1, 1															# row offset for each direction (negative = up)
dir_col_ofs:	.word 0, 0, -1, 1, 1, -1, 1, -1															# col offset for each direction (negative = left)

.text
.globl game_loop							# make these visible to the other files
.globl computer_move
.globl game_over
.globl verify_starting_position
.globl try_move

# game_loop(first)   $a0 = who moves first (0 = player, 1 = computer)
# plays turns until neither side can move, then returns
# a side that can't move is skipped and the other side goes again
# $s7 = whose turn it is (0 = player, 1 = computer)
# saves $ra and $s7
game_loop:
	addi $sp, $sp, -8						# make room on the stack
	sw   $ra, 0($sp)						# save the return address
	sw   $s7, 4($sp)						# save s7

	move $s7, $a0							# s7 = side that moves first

turn_loop:
	move $a0, $s7							# a0 = owner to check (the side whose turn it is)
	jal  owner_has_move						# v0 = 1 if that side has a legal move
	bnez $v0, take_turn						# it can move, play the turn normally

	xori $a0, $s7, 1						# a0 = the other side
	jal  owner_has_move						# v0 = 1 if the other side has a legal move
	beqz $v0, game_loop_done				# neither side can move, the game is over

	beqz $s7, player_stuck					# the stuck side is the player

	print_str(computer_no_move_prompt)		# the computer is stuck, the player goes again
	j    next_turn

player_stuck:
	print_str(player_no_move_prompt)		# the player is stuck, the computer goes again
	j    next_turn

take_turn:
	beqz $s7, player_turn					# 0 = player's turn

	jal  computer_move						# computer's turn
	j    next_turn

player_turn:
	jal  take_player_turn					# player's turn (input.asm)

next_turn:
	xori $s7, $s7, 1						# flip 0 <-> 1 to pass the turn
	j    turn_loop

game_loop_done:
	lw   $ra, 0($sp)						# restore the return address
	lw   $s7, 4($sp)						# restore s7
	addi $sp, $sp, 8						# free the stack space
	jr   $ra								# back to main


# computer_move()
# picks a random starting cell, then checks every cell (wrapping around)
# for a computer owned number. for each one, tries every direction in order
# and plays the first move try_move accepts
# $s0 = cell index (0 - 35), $s1 = cells left to check
# $s2 = row, $s3 = col, $s4 = direction index
# saves $ra and $s0-$s4
computer_move:
	addi $sp, $sp, -24						# make room on the stack
	sw   $ra, 0($sp)						# save the return address
	sw   $s0, 4($sp)						# save the s registers this procedure uses
	sw   $s1, 8($sp)
	sw   $s2, 12($sp)
	sw   $s3, 16($sp)
	sw   $s4, 20($sp)

	irandom_range($s0, 0, LAST_CELL)		# s0 = random starting cell index
	li   $s1, CELL_COUNT					# s1 = how many cells are left to check (the whole board)

computer_cell_loop:
	beqz $s1, computer_move_done			# every cell was checked and none had a move

	# index -> row and col
	li   $t0, BOARD_SIZE					# t0 = 6
	div  $s0, $t0							# index / 6
	mflo $s2								# s2 = quotient = row
	mfhi $s3								# s3 = remainder = col

	# must be a numbered cell
	get_cell($t1, grid, $s2, $s3)			# t1 = number in this cell
	beqz $t1, computer_next_cell			# 0 = empty, skip it

	# must be owned by the computer
	get_cell($t1, owners, $s2, $s3)			# t1 = owner of this cell (0 = player, 1 = computer)
	beqz $t1, computer_next_cell			# player's cell, skip it

	li   $s4, 0								# start with direction 0 (up)

computer_dir_loop:
	beq  $s4, 8, computer_next_cell			# all 8 directions failed, go to the next cell

	sll  $t5, $s4, 2						# t5 = direction index * 4 (byte offset into the word tables)
	lw   $t6, dir_row_ofs($t5)				# t6 = row offset for this direction
	lw   $t7, dir_col_ofs($t5)				# t7 = col offset for this direction
	attempt_move($s2, $s3, $t6, $t7)		# try to move from (row, col) in that direction

	bnez $v0, computer_move_made			# the move worked, finish the turn

	addi $s4, $s4, 1						# try the next direction
	j    computer_dir_loop

computer_next_cell:
	addi $s0, $s0, 1						# move to the next cell index
	rem  $s0, $s0, CELL_COUNT				# wrap back to 0 after the last cell
	addi $s1, $s1, -1						# one fewer cell left to check
	j    computer_cell_loop

computer_move_made:
	# try_move already gave the new cell the computer's owner value
	print_str(new_board_space)				# divider line
	print_str(computer_move_prompt)			# tell the player the computer moved
	jal  print_board						# show the updated board

computer_move_done:
	lw   $ra, 0($sp)						# restore everything that was saved
	lw   $s0, 4($sp)
	lw   $s1, 8($sp)
	lw   $s2, 12($sp)
	lw   $s3, 16($sp)
	lw   $s4, 20($sp)
	addi $sp, $sp, 24						# free the stack space
	jr   $ra								# back to game_loop


# game_over()
# the board is full, so find each side's highest number, print both, and decide the winner
# leaf function (apart from syscalls), modifies $t0-$t5, $t8
# $t0 = row, $t1 = col, $t2 = player's highest, $t3 = computer's highest
game_over:
	li   $t0, 0								# t0 = row
	li   $t2, 0								# t2 = player's highest number so far
	li   $t3, 0								# t3 = computer's highest number so far

final_row_loop:
	li   $t1, 0								# t1 = col

final_col_loop:
	get_cell($t4, grid, $t0, $t1)			# t4 = number in this cell
	beqz $t4, final_next_cell				# empty cell, skip it

	get_cell($t5, owners, $t0, $t1)			# t5 = owner of this cell (0 = player, 1 = computer)
	bnez $t5, final_check_computer			# computer's cell, check it against the computer's best

	ble  $t4, $t2, final_next_cell			# not higher than the player's best, skip it
	move $t2, $t4							# new player best
	j    final_next_cell

final_check_computer:
	ble  $t4, $t3, final_next_cell			# not higher than the computer's best, skip it
	move $t3, $t4							# new computer best

final_next_cell:
	addi $t1, $t1, 1						# next column
	blt  $t1, BOARD_SIZE, final_col_loop	# repeat for the rest of the row

	addi $t0, $t0, 1						# next row
	blt  $t0, BOARD_SIZE, final_row_loop	# repeat for the rest of the board

	print_str(game_over_prompt)				# tell the player the board is full

	print_str(player_score_prompt)			# "Your highest number: "
	print_int_reg($t2)

	print_str(computer_score_prompt)		# "The computer's highest number: "
	print_int_reg($t3)

	bgt  $t2, $t3, final_player_wins		# player's number is larger
	blt  $t2, $t3, final_computer_wins		# computer's number is larger

	print_str(tie_prompt)					# same highest number on both sides
	jr   $ra

final_player_wins:
	print_str(player_wins_prompt)			# congratulate the player
	jr   $ra

final_computer_wins:
	print_str(computer_wins_prompt)			# commiserate with the player
	jr   $ra


# verify_starting_position(row, col)   $a0 = row, $a1 = col
# returns $v0 = 1 if in bounds, on a numbered cell, and owned by the player, else 0
# leaf function, modifies $v0, $t4, $t8
verify_starting_position:
	blt  $a0, 0, start_invalid				# row above the board
	bge  $a0, BOARD_SIZE, start_invalid		# row below the board
	blt  $a1, 0, start_invalid				# col left of the board
	bge  $a1, BOARD_SIZE, start_invalid		# col right of the board

	get_cell($v0, grid, $a0, $a1)			# v0 = number in the cell
	beqz $v0, start_invalid					# empty cell, can't start here

	get_cell($t4, owners, $a0, $a1)			# t4 = owner of the cell
	bnez $t4, start_invalid					# computer's cell, can't start here

	li   $v0, 1								# everything checks out
	jr   $ra

start_invalid:
	li   $v0, 0								# invalid start position
	jr   $ra


# try_move(row, col, row_offset, col_offset)
# $a0 = origin row, $a1 = origin col, $a2 = row offset, $a3 = col offset
# fills the neighbouring cell with origin + 1, gives it the origin's owner, and links the two cells
# returns $v0 = 1 if the move was made, 0 if it leaves the board or the target is taken
# modifies $a0-$a3, $t0-$t4, $t8, $t9
try_move:
	addi $sp, $sp, -4						# make room on the stack
	sw   $ra, 0($sp)						# save the return address (we call set_link)

	# value at the origin cell
	get_cell($t2, grid, $a0, $a1)			# t2 = number at the origin

	# target cell = origin + offset
	add  $t0, $a0, $a2						# t0 = target row
	add  $t1, $a1, $a3						# t1 = target col

	# stay on the board
	blt  $t0, 0, try_move_fail				# target row above the board
	bge  $t0, BOARD_SIZE, try_move_fail		# target row below the board
	blt  $t1, 0, try_move_fail				# target col left of the board
	bge  $t1, BOARD_SIZE, try_move_fail		# target col right of the board

	# target must be empty
	get_cell($t4, grid, $t0, $t1)			# t4 = number in the target cell
	bnez $t4, try_move_fail					# already occupied

	# new cell = origin + 1
	addi $t3, $t2, 1						# t3 = origin number + 1
	set_cell(grid, $t0, $t1, $t3)			# grid[target] = new number

	# new cell belongs to whoever owns the origin
	get_cell($t4, owners, $a0, $a1)			# t4 = origin owner
	set_cell(owners, $t0, $t1, $t4)			# owners[target] = origin owner

	# link origin to the new cell ($a0 and $a1 are still the origin)
	move $a2, $t0							# a2 = target row
	move $a3, $t1							# a3 = target col
	jal  set_link							# draw the link between the two cells

	li   $v0, 1								# success
	j    try_move_done

try_move_fail:
	li   $v0, 0								# failure

try_move_done:
	lw   $ra, 0($sp)						# restore the return address
	addi $sp, $sp, 4						# free the stack space
	jr   $ra


# owner_has_move(owner)   $a0 = owner (0 = player, 1 = computer)
# returns $v0 = 1 if any numbered cell of that owner has an empty neighbour on the board, else 0
# only looks, never changes the board
# leaf function, modifies $v0, $t0-$t7
owner_has_move:
	li   $t0, 0								# t0 = row

has_move_row_loop:
	li   $t1, 0								# t1 = col

has_move_col_loop:
	get_cell($t2, grid, $t0, $t1)			# t2 = number in this cell
	beqz $t2, has_move_next_cell			# empty cell, skip it

	get_cell($t2, owners, $t0, $t1)			# t2 = owner of this cell
	bne  $t2, $a0, has_move_next_cell		# belongs to the other side, skip it

	li   $t3, 0								# t3 = direction index, start at 0 (up)

has_move_dir_loop:
	beq  $t3, 8, has_move_next_cell			# all 8 directions are blocked, next cell

	sll  $t4, $t3, 2						# t4 = direction index * 4 (byte offset into the word tables)
	lw   $t5, dir_row_ofs($t4)				# t5 = row offset for this direction
	lw   $t6, dir_col_ofs($t4)				# t6 = col offset for this direction
	add  $t5, $t5, $t0						# t5 = neighbour row
	add  $t6, $t6, $t1						# t6 = neighbour col

	blt  $t5, 0, has_move_next_dir			# neighbour row above the board
	bge  $t5, BOARD_SIZE, has_move_next_dir	# neighbour row below the board
	blt  $t6, 0, has_move_next_dir			# neighbour col left of the board
	bge  $t6, BOARD_SIZE, has_move_next_dir	# neighbour col right of the board

	get_cell($t7, grid, $t5, $t6)			# t7 = number in the neighbour cell
	beqz $t7, has_move_found				# neighbour is empty, a move exists

has_move_next_dir:
	addi $t3, $t3, 1						# try the next direction
	j    has_move_dir_loop

has_move_next_cell:
	addi $t1, $t1, 1						# next column
	blt  $t1, BOARD_SIZE, has_move_col_loop	# repeat for the rest of the row

	addi $t0, $t0, 1						# next row
	blt  $t0, BOARD_SIZE, has_move_row_loop	# repeat for the rest of the board

	li   $v0, 0								# checked every cell, no move found
	jr   $ra

has_move_found:
	li   $v0, 1								# a move exists
	jr   $ra