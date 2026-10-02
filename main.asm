.include "SysCalls.asm"

.data
x_prompt: .asciiz "\nEnter the x-coordinate of your origin (0 - 5): "
y_prompt: .asciiz "Enter the y-coordinate of your origin: (0 - 5) "
dir_prompt: .asciiz "Enter the direction you want to move in (u, d, l, r): "

dir_input: .space 8     # small buffer for "u\n" style input + null terminator
dir_x_amt: .float 0
dir_y_amt: .float 0


down_input: .asciiz "d"
up_input: .asciiz "u"
left_input: .asciiz "l"
right_input: .asciiz "r"

new_board_space: .asciiz "\n\n\n\n" 

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
    
    bne %t1, %t2, _notequal   # If bytes do not match, strings are not equal
    beq %t1, $zero, _done    # If both are null terminator '\0', strings match completely
    
    addi $t7, $t7, 1         # Move to next char in string 1
    addi $t8, $t8, 1         # Move to next char in string 2
    j _loop

_notequal:
    li %result, 0            # Set result to 0 (not equal)

_done:
.end_macro


main:
	# Set up game state (clear_board + starting numbers)
	jal reset_game_board

	jal print_board         # print the initial state

	jal game_loop

	li $v0, SysExit
	syscall


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
	
	la $a0, down_input
	#compare_string($s2, $a0,  
	
	
	# create space for printing new game state
	li   $v0, SysPrintString 	# syscall code for printing a string
	la   $a0, new_board_space     	# a0 = address of space string
	syscall                  	# print separating space
	
	
	jal  print_board
	
	j game_loop
	
	li $v0, SysExit
	syscall