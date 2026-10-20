# Ben Holland CS 2340 Term Project

### MARS settings to run program
1. "Assemble all files in directory" -> TRUE
2. "Permit extended (pseudo) instructions and formats" -> TRUE
3. "Initialize program counter to global 'main' if defined" -> TRUE


## How to play
The game splits cells into two categories: Player (P) and Computer/enemy (E). Each player can only branch off of cells that they own.

At the beginning of the game, a coin is flipped to decided who starts first. If the enemy goes first, they automatically take their turn and return the input to you, the player.

Every turn, you will input a starting cell location (x then y) and then input a movement direction to branch to. Branching to a new cell sets that cell's value to +1 of the origin cell.

You and the computer will take turns branching out from the starting state until the board is filled and the winner is decided.