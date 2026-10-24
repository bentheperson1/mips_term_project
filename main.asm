.include "SysCalls.asm"					# syscall number constants (SysGetTime, SysRandSeed, ...)
.include "helpers.asm"					# shared constants and macros (irandom_range, ...)

.data
player_first_prompt:	.asciiz "\nCoin flip: you go first!\n"				# shown when the player wins the flip
computer_first_prompt:	.asciiz "\nCoin flip: the computer goes first.\n"	# shown when the computer wins the flip

.text
.globl main								# entry point

main:
	# get system time
	li   $v0, SysGetTime				# syscall 30: get system time
	syscall								# $a0 contains the low-order 32 bits of time

	# set seed
	move $a1, $a0						# move time value to $a1 (seed)
	li   $a0, 0							# seed RNG 0
	li   $v0, SysRandSeed				# syscall 40: set seed
	syscall

	jal  reset_game_board				# fill the board with the starting numbers and links
	jal  print_board					# draw the starting board

	irandom_range($s0, 0, 1)			# 0 = player, 1 = computer
	beqz $s0, player_first				# player goes first if the roll was 0

	print_str(computer_first_prompt)	# otherwise the computer goes first
	j    start_game

player_first:
	print_str(player_first_prompt)		# tell the player they go first

start_game:
	move $a0, $s0						# a0 = who moves first
	jal  game_loop						# play turns until nobody can move (gamelogic.asm)

	jal  game_over						# print the scores and the winner (gamelogic.asm)

	li   $v0, SysExit					# exit the program
	syscall