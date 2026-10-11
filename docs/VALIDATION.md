# Testbench validation — 50 MHz

The four included testbenches passed in Vivado XSim in the author's
October 11, 2026 runs. The counts below were confirmed from console screenshots:

| Testbench | Checks passed | Coverage |
| --- | --- | --- |
| `tb_processor.v` | 24 | The 20-instruction demo, register results, store/load, x0, and debug outputs |
| `tb_alu.v` | 12 | AND, OR, ADD, SUB, signed SLT, NOR, equality, and carry/overflow/zero outputs |
| `tb_regression.v` | 26 | Execution enable, clocked stores, reset and RAM retention, NOP padding and PC wrap, memory boundaries, and instruction/address faults |
| `tb_board.v` | 38 | Ideal 50 MHz clock, startup and lock loss, debounce and held buttons, step/run/pause, pause priority, result/writeback/PC views, nibble selection, demo completion, and fault indicators |

**Total: 100 checks passed.**

Each testbench uses explicit expected values; a failed check stops simulation.
For simulation, add the five files from `rtl`, select one testbench from `tb` as
the simulation top, and define `BOARD_SIM`.

`BOARD_SIM` uses an ideal clock and lock model. The board test accelerates the
debounce and playback counters; these simulations check functional behavior,
not physical MMCM behavior or routed timing.

## Timing evidence

The Vivado report records design state
`Routed`, setup WNS **+5.185 ns**, hold WHS **+0.100 ns**, and zero
failing setup, hold, or pulse-width endpoints. See the
[timing summary](reports/timing_summary.rpt), [clocks](reports/clocks.rpt),
and [worst setup paths](reports/worst_setup.rpt).

Vivado reports LUTAR-1: reset logic may glitch and cause an unintended reset.
Simulation and timing checks pass; this hardware risk remains unresolved.
The reports show zero unconstrained internal endpoints; board I/O uses explicit
false-path exceptions. A timing pass is subject to those constraints.

## Running in Vivado XSim

1. Add this version's five `rtl/*.v` files as design sources and its `tb/*.v`
   files as simulation sources. Use a separate project for the beta.
2. In simulation compilation settings, set the Verilog define to `BOARD_SIM`
   for the simulation fileset only. Leave it undefined for synthesis.
3. Set one testbench as the simulation top and launch behavioral simulation.
4. Select Run All, or enter `run -all` at the `xsim%` prompt. Check for the
   matching `PASS` line and count in the table above.
5. Close the simulation, select the next testbench as top, and repeat.

The XSim version was not captured in the supplied PASS screenshots. The timing
reports separately identify Vivado 2025.2. These results establish the included
functional checks, not exhaustive ISA coverage or hardware timing.
