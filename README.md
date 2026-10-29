# Ben Holland - CS 2340 Term Project - Number Chain

## Files
All of these files must be in the same folder:
`main.asm`, `board.asm`, `gamelogic.asm`, `input.asm`, `helpers.asm`, `SysCalls.asm`

## Running the game in MARS
1. Open MARS and go to the **Settings** menu. Turn on:
	- **Assemble all files in directory**
	- **Permit extended (pseudo) instructions and formats**
	- **Initialize program counter to global 'main' if defined**
2. Open `main.asm`
3. Assemble and run

## Rules
- The board is 6 x 6. You own the **P** cells and the computer owns the **E** cells.
- Each side starts with a chain of 1, 2, 3 on opposite corners of the board.
- A coin flip decides who moves first, and the game tells you the result.
- On your turn, pick any cell you own and branch into an empty neighbouring cell (up, down, left, right, or diagonal). The new cell gets the origin's number + 1 and becomes yours.
- If one side has no legal moves, it is skipped and the other side goes again.
- When the board is full, whoever owns the highest number wins. Equal highest numbers are a tie.

## Reading the board
```
    0   1   2   3   4   5      <- x (column)
  +---+---+---+---+---+---+
0 |P 1|   |   |   |   |   |    <- y (row) on the left
  +---\---+---+---+---+---+
1 |   |P 2-P 3|   |   |   |
```
- `P 1` is a player cell holding 1, `E 4` is a computer cell holding 4, and blank cells are empty.
- Links show which cell each number grew from: `-` between cells is a horizontal link, `|` in place of `---` is a vertical link, and `/` or `\` at a corner is a diagonal link.
- If two diagonal links cross at the same corner, only the most recent one can be shown.

## Taking a turn
1. Enter the **x-coordinate** (column, 0 – 5) of a cell you own and press Enter.
2. Enter the **y-coordinate** (row, 0 – 5) of that cell and press Enter.
3. Enter a direction and press Enter. Upper or lower case both work:

| Code | Direction | Code | Direction |
|---|---|---|---|
| `u` | up | `ur` | up-right |
| `d` | down | `ul` | up-left |
| `l` | left | `dr` | down-right |
| `r` | right | `dl` | down-left |

Example: to grow from your `P 3` at column 2, row 2 into the empty cell to its right, enter `2`, `2`, `r`.

## Invalid input
- A coordinate that isn't a single digit from 0 – 5, an empty cell, or a computer cell prints "That isn't one of your numbered cells" and asks again.
- An unknown direction, or a move off the board or onto a filled cell, prints "That move is invalid" and shows the board again.
- Invalid input never ends the game.

## End of game
When the board is full, the game prints both sides' highest numbers, announces the winner (or a tie), and the program exits. Assemble and run again to play another game.