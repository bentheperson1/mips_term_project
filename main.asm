.include "SysCalls.asm"
.include "helpers.asm"

.data
x_prompt: .asciiz "\nEnter the x-coordinate of your origin (0 - 5): "
y_prompt: .asciiz "Enter the y-coordinate of your origin: (0 - 5) "
dir_prompt: .asciiz "Enter the direction you want to move in (u, d, l, r, ur, ul, dr, dl): "
invalid_start_pos_prompt: .asciiz "Your start position is invalid. Try again.\n"
invalid_move_prompt: .asciiz "That move is invalid. Try again.\n"
dir_input: .space 12     # small buffer for move direction

down_input: .asciiz "d\n"
up_input: .asciiz "u\n"
left_input: .asciiz "l\n"
right_input: .asciiz "r\n"

down_right_input: .asciiz "dr\n"
down_left_input: .asciiz "dl\n"
up_right_input: .asciiz "ur\n"
up_left_input: .asciiz "ul\n"

new_board_space: .asciiz "\n\n"

.align 2

.text
.globl main

.macro compare_string(%str1, %str2, %result, %t1, %t2)
	move $t7, %str1          # Copy pointer 1
	move $t8, %str2          # Copy pointer 2
	li %result, 1            # Assume equal initially

_loop:
	lb %t1, 0($t7)           # Load byte from string 1
	lb %t2, 0($t8)           # Load byte from string 2

	bne %t1, %t2, _notequal  # If bytes do not match, strings are not equal
	beq %t1, $zero, _done    # If both are null terminator '\0', strings match completely

	addi $t7, $t7, 1         # Move to next char in string 1
	addi $t8, $t8, 1         # Move to next char in string 2
	j _loop

_notequal:
	li %result, 0            # Set result to 0 (not equal)

_done:
.end_macro


main:
	# Get system time
	li $v0, SysGetTime         # Syscall 30: Get system time
	syscall            # $a0 contains the low-order 32 bits of time

	# Set seed
	move $a1, $a0      # Move time value to $a1 (seed)
	li $a0, 0          # Seed RNG 0
	li $v0, SysRandSeed         # Syscall 40: Set seed
	syscall
	
	irandom_range($t0, 0, 100)

	# Set up game state (clear_board + starting numbers)
	jal  reset_game_board

	jal  print_board         # print the initial state

	jal  game_loop

	li   $v0, SysExit
	syscall


game_loop:
	# take in x coord
	li   $v0, SysPrintString
	la   $a0, x_prompt
	syscall

	li   $v0, SysReadInt
	syscall

	addu $s1, $v0, $zero


	# take in y coord
	li   $v0, SysPrintString
	la   $a0, y_prompt
	syscall

	li   $v0, SysReadInt
	syscall

	addu $s0, $v0, $zero


	move $a0, $s0
	move $a1, $s1
	jal  verify_starting_position

	beqz $v0, start_invalid


	# take in move direction
	li   $v0, SysPrintString
	la   $a0, dir_prompt
	syscall

	li   $v0, SysReadString
	la   $a0, dir_input      # a0 = address of our buffer
	li   $a1, 12             # a1 = max chars to read (matches buffer size)
	syscall

	la   $s2, dir_input      # store the buffer's address

	la   $a0, down_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_down

	la   $a0, up_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up

	la   $a0, left_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_left

	la   $a0, right_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_right

	la   $a0, down_right_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_down_right

	la   $a0, down_left_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_down_left

	la   $a0, up_right_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up_right

	la   $a0, up_left_input
	compare_string($s2, $a0, $t0, $t2, $t3)
	bnez $t0, input_is_up_left

	# invalid input, ask again
	j    move_invalid


direction_done:
	# create space for printing new game state
	print_str(new_board_space)

	# the board decides if the move is legal and applies it
	attempt_move($s0, $s1, $s4, $s3)

	bnez $v0, redraw


move_invalid:
	print_str(invalid_move_prompt)

redraw:
	jal  print_board

	j    game_loop


start_invalid:
	print_str(invalid_start_pos_prompt)

	j    game_loop


input_is_down:
	li   $s3, 0              # x ofs = 0
	li   $s4, 1              # y ofs = 1
	j    direction_done

input_is_up:
	li   $s3, 0              # x ofs = 0
	li   $s4, -1             # y ofs = -1
	j    direction_done

input_is_left:
	li   $s3, -1             # x ofs = -1
	li   $s4, 0              # y ofs = 0
	j    direction_done

input_is_right:
	li   $s3, 1              # x ofs = 1
	li   $s4, 0              # y ofs = 0
	j    direction_done

input_is_down_right:
	li   $s3, 1              # x ofs = 1
	li   $s4, 1              # y ofs = 1
	j    direction_done

input_is_down_left:
	li   $s3, -1             # x ofs = -1
	li   $s4, 1              # y ofs = 1
	j    direction_done

input_is_up_right:
	li   $s3, 1              # x ofs = 1
	li   $s4, -1             # y ofs = -1
	j    direction_done

input_is_up_left:
	li   $s3, -1             # x ofs = -1
	li   $s4, -1             # y ofs = -1
	j    direction_done
