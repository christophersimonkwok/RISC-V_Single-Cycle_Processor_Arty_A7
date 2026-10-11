# Testbench validation — 100 MHz beta

The beta runs the same four functional testbenches described in the
[50 MHz validation](../../docs/VALIDATION.md), plus a register-file test.
All five included testbenches passed in Vivado XSim in the author's runs. The counts below were confirmed from console screenshots:

| Testbench | Checks passed |
| --- | --- |
| `tb_processor.v` | 24 |
| `tb_alu.v` | 12 |
| `tb_regression.v` | 26 |
| `tb_board.v` | 38 |
| `tb_regfile.v` | 1,058 |

**Total: 1,158 checks passed.**

`tb_board.v` checks the ideal 100 MHz processor clock and the shared board
controls. `tb_regfile.v` checks all 1,024 read-address pairs, x0 protection,
execution-gated writes, and reset of every register.

Use this folder's five RTL files and testbenches with `BOARD_SIM` defined.
The board test accelerates debounce and playback counters. Simulation checks
functional behavior using an ideal clock/lock model; it does not establish
physical MMCM behavior or routed 100 MHz timing.

## Timing evidence

Report-header dates and timestamps have been omitted; timing results are unchanged.

The Vivado report records design state
`Physopt postRoute`, setup WNS **+0.013 ns**, hold WHS **+0.122 ns**, and zero
failing setup, hold, or pulse-width endpoints. See the
[timing summary](reports/timing_summary.rpt), [clocks](reports/clocks.rpt),
and [worst setup paths](reports/worst_setup.rpt).

Vivado reports LUTAR-1: reset logic may glitch and cause an unintended reset.
Simulation and timing checks pass; this hardware risk remains unresolved.
The reports show zero unconstrained internal endpoints; board I/O uses explicit
false-path exceptions. A timing pass is subject to those constraints.

The 100 MHz margin is only 0.013 ns, so the beta remains experimental.

Use the [XSim instructions](../../docs/VALIDATION.md#running-in-vivado-xsim)
with the beta sources and all five beta testbenches.
