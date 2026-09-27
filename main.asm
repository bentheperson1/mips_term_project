.include "SysCalls.asm"

.data
x_prompt: .asciiz "\nEnter the x-coordinate of your origin (0 - 5): "
y_prompt: .asciiz "Enter the y-coordinate of your origin: (0 - 5) "
dir_prompt: .asciiz "Enter the direction you want to move in (u, d, l, r): "

dir_input: .space 8     # small buffer for "u\n" style input + null terminator

new_board_space: .asciiz "\n\n\n\n" 

.align 2

.text
.globl main

main:
	li   $t0, 0           	# row counter = 0
	
	jal init_col_loop 	# print the initial state
	
	jal game_loop
	
	li $v0, SysExit
	syscall


init_row_loop:
	li   $t1, 0           # col counter = 0

init_col_loop:
	move $a0, $t0          # a0 = row (arg 1 for set_element)
	move $a1, $t1          # a1 = col (arg 2 for set_element)
	li   $a2, 0            # a2 = 0, value to write (arg 3 for set_element)
	jal  set_element        # grid[row][col] = 0

	addi $t1, $t1, 1       # col++
	blt  $t1, 6, init_col_loop   # repeat until col == 6

	addi $t0, $t0, 1       # row++
	blt  $t0, 6, init_row_loop   # repeat until row == 6

	# Set up game state
	jal reset_game_board    # write the starting diagonal pattern into the grid

	jal print_grid          # print the grid to verify/display it

game_loop:
	# take in x coord
	li   $v0, SysPrintString 	# syscall code for printing a string
	la   $a0, x_prompt          	# a0 = address of space string
	syscall                  	# print separating space
	
	li   $v0, SysReadInt    	# syscall code for reading an integer
	syscall                  	# print grid[row][col]
	
	addu $s1, $v0, $zero
	
	
	# take in y coord
	li   $v0, SysPrintString 	# syscall code for printing a string
	la   $a0, y_prompt          	# a0 = address of space string
	syscall                  	# print separating space
	
	li   $v0, SysReadInt    	# syscall code for reading an integer
	syscall                  	# print grid[row][col]
	
	addu $s0, $v0, $zero
	
	
	move $a0, $s0
	move $a1, $s1
	jal  verify_starting_position
	
	beqz $v0, game_loop
	
	
	# take in move direction
	li   $v0, SysPrintString
	la   $a0, dir_prompt
	syscall

	li   $v0, SysReadString
	la   $a0, dir_input      # a0 = address of OUR buffer, not the prompt string
	li   $a1, 8               # a1 = max chars to read (matches buffer size)
	syscall

	la   $s2, dir_input       # store the buffer's ADDRESS, not $v0
	
	move $a0, $s0
	move $a1, $s1
	li $a2, 8
	
	jal set_element
	
	# create space for printing new game state
	li   $v0, SysPrintString 	# syscall code for printing a string
	la   $a0, new_board_space     	# a0 = address of space string
	syscall                  	# print separating space
	
	
	jal  print_grid
	
	j game_loop
	
	li $v0, SysExit
	syscall


