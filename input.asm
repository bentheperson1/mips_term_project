.include "SysCalls.asm"				# syscall number constants (SysPrintString, SysReadInt, ...)
.include "helpers.asm"				# shared constants and macros (BOARD_SIZE, get_cell, set_cell, ...)

.data
x_prompt:	.asciiz "\nEnter the x-coordinate of your origin (0 - 5): "				# asks for the column
y_prompt:	.asciiz "Enter the y-coordinate of your origin: (0 - 5) "				# asks for the row
dir_prompt:	.asciiz "Enter the direction you want to move in (u, d, l, r, ur, ul, dr, dl): "	# asks for the move direction
invalid_start_pos_prompt: .asciiz "Your start position is invalid. Try again.\n"					# shown when the origin cell is not usable
invalid_move_prompt:	.asciiz "That move is invalid. Try again.\n"						# shown when the move is rejected or unrecognised

dir_input:	.space 12	# small buffer for move direction (holds the typed text plus the newline and null)

# expected strings (the typed input includes the newline from pressing enter)
down_input:	.asciiz "d\n"
up_input:	.asciiz "u\n"
left_input:	.asciiz "l\n"
right_input:	.asciiz "r\n"

down_right_input:	.asciiz "dr\n"
down_left_input:	.asciiz "dl\n"
up_right_input:	.asciiz "ur\n"
up_left_input:	.asciiz "ul\n"

.text
.globl take_player_turn				# make this visible to gamelogic.asm

# take_player_turn
# asks for the origin and direction, then tries to play the move
# ends by jumping to computer_move (move made) or game_loop (try again)
take_player_turn:
	# take in x coord
	li   $v0, SysPrintString			# print the x prompt
	la   $a0, x_prompt
	syscall

	li   $v0, SysReadInt				# read the x coordinate (column)
	syscall

	addu $s1, $v0, $zero				# s1 = x (column)

	# take in y coord
	li   $v0, SysPrintString			# print the y prompt
	la   $a0, y_prompt
	syscall

	li   $v0, SysReadInt				# read the y coordinate (row)
	syscall

	addu $s0, $v0, $zero				# s0 = y (row)

	move $a0, $s0						# a0 = row
	move $a1, $s1						# a1 = col
	jal  verify_starting_position		# v0 = 1 if the player may start from this cell

	beqz $v0, start_invalid			# bad origin, report it and ask again

	# take in move direction
	li   $v0, SysPrintString		# print the direction prompt
	la   $a0, dir_prompt
	syscall

	li   $v0, SysReadString			# read the direction text
	la   $a0, dir_input				# a0 = address of our buffer
	li   $a1, 12					# a1 = max chars to read (matches buffer size)
	syscall

	la   $s2, dir_input				# store the buffer's address

	# compare the typed text against each valid direction in turn
	la   $a0, down_input			# a0 = "d\n"
	compare_string($s2, $a0, $t0, $t2, $t3)	# t0 = 1 if input == "d\n"
	bnez $t0, input_is_down

	la   $a0, up_input			# a0 = "u\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up

	la   $a0, left_input			# a0 = "l\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_left

	la   $a0, right_input			# a0 = "r\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_right

	la   $a0, down_right_input		# a0 = "dr\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_down_right

	la   $a0, down_left_input		# a0 = "dl\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_down_left

	la   $a0, up_right_input		# a0 = "ur\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up_right

	la   $a0, up_left_input			# a0 = "ul\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up_left

	# invalid input, ask again
	j    move_invalid			# nothing matched


direction_done:
	# create space for printing new game state
	print_str(new_board_space)		# divider line

	# the board decides if the move is legal and applies it
	attempt_move($s0, $s1, $s4, $s3)	# origin = (row s0, col s1), offsets = (row s4, col s3)

	beqz $v0, move_invalid			# move was rejected, ask again

player_moved:
	jal  print_board			# show the board with the player's new move

	j    computer_move			# computer's turn (it ends with j game_loop)

move_invalid:
	print_str(invalid_move_prompt)		# tell the player the move was rejected
	jal  print_board			# show the unchanged board

	j    game_loop				# ask for a new move

start_invalid:
	print_str(invalid_start_pos_prompt)	# tell the player the origin was bad

	j    game_loop				# ask for the coordinates again


# direction handlers
# each one sets x ofs ($s3) and y ofs ($s4) then jumps to direction_done
input_is_down:
	li   $s3, 0				# x ofs = 0
	li   $s4, 1				# y ofs = 1
	j    direction_done

input_is_up:
	li   $s3, 0				# x ofs = 0
	li   $s4, -1				# y ofs = -1
	j    direction_done

input_is_left:
	li   $s3, -1				# x ofs = -1
	li   $s4, 0				# y ofs = 0
	j    direction_done

input_is_right:
	li   $s3, 1				# x ofs = 1
	li   $s4, 0				# y ofs = 0
	j    direction_done

input_is_down_right:
	li   $s3, 1				# x ofs = 1
	li   $s4, 1				# y ofs = 1
	j    direction_done

input_is_down_left:
	li   $s3, -1				# x ofs = -1
	li   $s4, 1				# y ofs = 1
	j    direction_done

input_is_up_right:
	li   $s3, 1				# x ofs = 1
	li   $s4, -1				# y ofs = -1
	j    direction_done

input_is_up_left:
	li   $s3, -1				# x ofs = -1
	li   $s4, -1				# y ofs = -1
	j    direction_done