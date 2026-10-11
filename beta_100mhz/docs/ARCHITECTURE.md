# Architecture — 100 MHz beta

This beta uses the same single-cycle processor described in the
[main 50 MHz architecture](../../docs/ARCHITECTURE.md). The instruction set,
ROM program, memory capacities, register storage and writes, ALU, controller,
fault behavior, and board controls are the same. The implementation differences
are:

- **Clock:** the MMCM output divider is 8 instead of 16, producing a 100 MHz
  processor clock with a 10 ns period. Input divide 1 and multiply 8 are unchanged.
- **Memory address path:** a dedicated 32-bit base-plus-immediate adder supplies
  the RAM address for LW/SW, bypassing general ALU operand and operation selection.
  The ALU still supplies the displayed result.
- **Address validation:** the datapath checks alignment and range using a 12-bit
  addition, its carry, and parallel comparisons of the upper base bits. The
  processor uses this validity signal to gate commits. This preserves the same
  valid addresses and 32-bit wraparound behavior as the 50 MHz check.
- **Register reads:** each read address is decoded and the selected register
  bits are combined with an OR reduction. Storage, reset, and write logic are
  unchanged.
- **Observation counters:** debounce is 1,000,000 cycles and `RUN_CYCLES` is
  50,000,000, preserving 10 ms debounce and 0.5-second playback at 100 MHz.

These changes retain one enabled clock edge per instruction; no pipeline stages
or extra load/store cycles are added. The simulation clock model uses a 10 ns
processor period instead of 20 ns.
