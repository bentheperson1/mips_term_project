.include "SysCalls.asm"						# syscall number constants (SysPrintString, SysReadString, ...)
.include "helpers.asm"						# shared constants and macros (BOARD_SIZE, get_cell, set_cell, ...)

.data
x_prompt:	.asciiz "\nEnter the x-coordinate of your origin (0 - 5): "							# asks for the column
y_prompt:	.asciiz "Enter the y-coordinate of your origin (0 - 5): "							# asks for the row
dir_prompt:	.asciiz "Enter the direction you want to move in (u, d, l, r, ur, ul, dr, dl): "	# asks for the move direction
invalid_start_pos_prompt: .asciiz "Your start position is invalid. Try again.\n"				# shown when the origin cell is not usable
invalid_move_prompt:	.asciiz "That move is invalid. Try again.\n"							# shown when the move is rejected or unrecognised

coord_input:	.space 12																	# buffer for a typed coordinate (the digit, the newline and the null)
dir_input:	.space 12																		# small buffer for move direction (holds the typed text plus the newline and null)

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
.globl take_player_turn						# make this visible to gamelogic.asm

# take_player_turn()
# asks for the origin and direction until a legal move is made, then shows the board
# $s0 = row, $s1 = col, $s2 = direction buffer, $s3 = col offset, $s4 = row offset
# saves $ra and $s0-$s4 because it calls other procedures
take_player_turn:
	addi $sp, $sp, -24						# make room on the stack
	sw   $ra, 0($sp)						# save the return address
	sw   $s0, 4($sp)						# save the s registers this procedure uses
	sw   $s1, 8($sp)
	sw   $s2, 12($sp)
	sw   $s3, 16($sp)
	sw   $s4, 20($sp)

player_prompt:
	# take in x coord
	li   $v0, SysPrintString				# print the x prompt
	la   $a0, x_prompt
	syscall

	jal  read_coord							# v0 = digit typed, or -1 if invalid
	move $s1, $v0							# s1 = x (column)

	# take in y coord
	li   $v0, SysPrintString				# print the y prompt
	la   $a0, y_prompt
	syscall

	jal  read_coord							# v0 = digit typed, or -1 if invalid
	move $s0, $v0							# s0 = y (row)

	move $a0, $s0							# a0 = row
	move $a1, $s1							# a1 = col
	jal  verify_starting_position			# v0 = 1 if the player may start from this cell

	beqz $v0, start_invalid					# bad origin, report it and ask again

	# take in move direction
	li   $v0, SysPrintString				# print the direction prompt
	la   $a0, dir_prompt
	syscall

	li   $v0, SysReadString					# read the direction text
	la   $a0, dir_input						# a0 = address of our buffer
	li   $a1, 12							# a1 = max chars to read (matches buffer size)
	syscall

	jal  lowercase_dir						# accept "UR" the same as "ur"

	la   $s2, dir_input						# store the buffer's address

	# compare the typed text against each valid direction in turn
	la   $a0, down_input					# a0 = "d\n"
	compare_string($s2, $a0, $t0, $t2, $t3)	# t0 = 1 if input == "d\n"
	bnez $t0, input_is_down

	la   $a0, up_input						# a0 = "u\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up

	la   $a0, left_input					# a0 = "l\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_left

	la   $a0, right_input					# a0 = "r\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_right

	la   $a0, down_right_input				# a0 = "dr\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_down_right

	la   $a0, down_left_input				# a0 = "dl\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_down_left

	la   $a0, up_right_input				# a0 = "ur\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up_right

	la   $a0, up_left_input					# a0 = "ul\n"
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up_left

	# invalid input, ask again
	j    move_invalid						# nothing matched


direction_done:
	# the board decides if the move is legal and applies it
	attempt_move($s0, $s1, $s4, $s3)		# origin = (row s0, col s1), offsets = (row s4, col s3)

	beqz $v0, move_invalid					# move was rejected, ask again

player_moved:
	print_str(new_board_space)				# divider line
	jal  print_board						# show the board with the player's new move

	lw   $ra, 0($sp)						# restore everything that was saved
	lw   $s0, 4($sp)
	lw   $s1, 8($sp)
	lw   $s2, 12($sp)
	lw   $s3, 16($sp)
	lw   $s4, 20($sp)
	addi $sp, $sp, 24						# free the stack space
	jr   $ra								# back to game_loop

move_invalid:
	print_str(invalid_move_prompt)			# tell the player the move was rejected
	jal  print_board						# show the unchanged board

	j    player_prompt						# ask for a new move

start_invalid:
	print_str(invalid_start_pos_prompt)		# tell the player the origin was bad

	j    player_prompt						# ask for the coordinates again


# direction handlers
# each one sets x ofs ($s3) and y ofs ($s4) then jumps to direction_done
input_is_down:
	li   $s3, 0								# x ofs = 0
	li   $s4, 1								# y ofs = 1
	j    direction_done

input_is_up:
	li   $s3, 0								# x ofs = 0
	li   $s4, -1							# y ofs = -1
	j    direction_done

input_is_left:
	li   $s3, -1							# x ofs = -1
	li   $s4, 0								# y ofs = 0
	j    direction_done

input_is_right:
	li   $s3, 1								# x ofs = 1
	li   $s4, 0								# y ofs = 0
	j    direction_done

input_is_down_right:
	li   $s3, 1								# x ofs = 1
	li   $s4, 1								# y ofs = 1
	j    direction_done

input_is_down_left:
	li   $s3, -1							# x ofs = -1
	li   $s4, 1								# y ofs = 1
	j    direction_done

input_is_up_right:
	li   $s3, 1								# x ofs = 1
	li   $s4, -1							# y ofs = -1
	j    direction_done

input_is_up_left:
	li   $s3, -1							# x ofs = -1
	li   $s4, -1							# y ofs = -1
	j    direction_done


# read_coord()
# reads the coordinate as text so typing a letter can't crash the program
# returns $v0 = the digit typed, or -1 if the input wasn't exactly one character
# anything that isn't 0 - 5 is out of bounds and gets rejected by verify_starting_position
# leaf function, modifies $v0, $a0, $a1, $t0, $t1
read_coord:
	li   $v0, SysReadString					# read the line as text
	la   $a0, coord_input					# a0 = address of our buffer
	li   $a1, 12							# a1 = max chars to read (matches buffer size)
	syscall

	lb   $t0, coord_input					# t0 = first character typed
	lb   $t1, coord_input + 1				# t1 = second character, must be the newline

	li   $v0, -1							# assume invalid
	bne  $t1, '\n', read_coord_done			# more (or less) than one character was typed

	subi $v0, $t0, '0'						# ascii digit -> number

read_coord_done:
	jr   $ra


# lowercase_dir()
# converts any uppercase letters in dir_input to lowercase
# leaf function, modifies $t0, $t1
lowercase_dir:
	la   $t0, dir_input						# t0 = current character address

lowercase_loop:
	lb   $t1, 0($t0)						# t1 = current character
	beqz $t1, lowercase_done				# null terminator, finished

	blt  $t1, 'A', lowercase_next			# below 'A', not an uppercase letter
	bgt  $t1, 'Z', lowercase_next			# above 'Z', not an uppercase letter

	addi $t1, $t1, 32						# 'A' + 32 = 'a'
	sb   $t1, 0($t0)						# write the lowercase letter back

lowercase_next:
	addi $t0, $t0, 1						# next character
	j    lowercase_loop

lowercase_done:
	jr   $ra