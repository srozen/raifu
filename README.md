# Raifu

Conway's Game of Life with GenServers

## Description

This Conway's Game of Life implementation through GenServers mainly serves my learing purposes of OTP 
usage and testing, as well as build process of an Elixir app.

The game of life is composed by a single Board server of dimension x\*y that orchestrate x\*y Cell.
The Cells are dynamically instanciated through a CellSupervisor.
The Runner is used to trigger ticks on the Board and display the state of the game to the user.

```mermaid
sequenceDiagram
    participant Runner
    participant Board
    participant CellSupervisor
    participant Cell
    participant OtherCell

    Runner->>Board: start_game
    Board->>CellSupervisor: instantiate cells
    CellSupervisor->>Board: cell_references
    Board->>Runner: :ok
    Runner->>Board: tick
    Board->>Cell: compute_next_state
    Cell->>OtherCell: get_neighborhood_status
    Cell->>Cell: next_state
    Cell->>Board: :ok
    Board->>Cell: update_state
    Cell->>Board: new_state
    Board->>Runner: board_state
    Runner->>Runner: render board
```

## How to launch it

```bash
iex -S mix run --no-halt

# Then in iex, launch the game through the Runner
Raifu.Runner.start_game(6,6)
```

The Runner will then display the Game's board and update it upon each tick with the following format :

![Conway's Game of Life with GenServers](/docs/output.png "Conway's Game of Life with GenServers")
