.include "SysCalls.asm"			# syscall number constants (SysGetTime, SysRandSeed, ...)
.include "helpers.asm"			# shared constants and macros (irandom_range, ...)

.text
.globl main				# entry point

main:
	# get system time
	li   $v0, SysGetTime		# syscall 30: get system time
	syscall				# $a0 contains the low-order 32 bits of time

	# set seed
	move $a1, $a0			# move time value to $a1 (seed)
	li   $a0, 0			# seed RNG 0
	li   $v0, SysRandSeed		# syscall 40: set seed
	syscall

	jal  reset_game_board		# fill the board with the starting numbers and links
	jal  print_board		# draw the starting board

	irandom_range($t0, 0, 1)	# 0 = player, 1 = computer
	beqz $t0, player_first		# player goes first if the roll was 0

	j    computer_move		# otherwise the computer goes first (gamelogic.asm)

player_first:
	j    game_loop			# player's turn (gamelogic.asm)