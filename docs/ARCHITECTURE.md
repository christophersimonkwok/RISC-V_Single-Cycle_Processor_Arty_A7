# Architecture - 50 MHz

The main design is a 32-bit single-cycle processor for the Arty A7-100T.
`processor` connects `Controller`, `ALUController`, and `data_path`.
`arty_a7_top` supplies the clock, reset, execution controls, and LED display.
The [100 MHz beta](../beta_100mhz/docs/ARCHITECTURE.md) uses the same architecture
with a few implementation changes.

## Instruction execution

Instruction fetch, decoding, register reads, immediate generation, ALU
operations, and load-data selection are combinational. An enabled rising clock
edge advances the PC by four bytes and commits register writes, stores, and
debug results. Pausing prevents instruction commits while the clock continues
running. There are no pipeline stages, branches, or jumps.

Supported instructions are ADD, SUB, AND, OR, signed SLT, ADDI, ANDI, ORI,
SLTI, LW, SW, and custom NOR/NORI. NOR/NORI use `funct3 = 100`, which standard
RISC-V assigns to XOR/XORI; this processor implements a custom subset.

## Storage and datapath

| Component | Organization and behavior |
| --- | --- |
| PC | 8-bit byte address; wraps after 64 sequential instructions |
| Instruction ROM | 64 x 32-bit words; 20 demo instructions followed by 44 NOPs (`00000013`) |
| Register file | 32 x 32-bit registers; two combinational reads and one enabled write; x0 remains zero |
| Immediate generator | Sign-extends the supported 12-bit arithmetic and memory offsets |
| ALU and multiplexers | Select the second ALU operand and choose ALU or loaded data for register writeback |
| Data RAM | 128 x 32-bit words (512 bytes); asynchronous reads and writes on the commit edge |

The program is initialized in `InstMem` in `rtl/dataPath.v`.
`program/lab_program.hex` is a reference copy rather than an automatically
loaded file. FPGA configuration initializes RAM to zero; processor reset clears
the PC, registers, fault state, and debug values while retaining RAM contents.

LW/SW use the ALU's base-plus-immediate result as the byte address. Only aligned
word accesses from byte address 0 through 508 are valid. Unsupported instruction
encodings and invalid memory accesses latch a fault and prevent commits until
reset.

## Clock and board wrapper

The MMCM converts the board's 100 MHz input to 50 MHz using input divide 1,
multiply 8, and output divide 16. Global buffers distribute the feedback and
processor clocks. Reset release waits for MMCM lock and three processor clock
edges. Buttons and switches use two synchronizer stages; button debounce is
500,000 cycles (10 ms).

The wrapper uses clock enables for manual stepping and automatic playback.
`RUN_CYCLES = 25,000,000` gives one instruction every 0.5 seconds without changing
the 20 ns processor clock period. The demo stops after 20 instructions at PC
`0x50`, retaining the final ALU address `0x30` and loaded writeback value `5`.
`DEMO_INSTRUCTIONS = 0` disables this wrapper stop.

The display selects four bits of the retained ALU result, register writeback,
or PC. Button presses can pause, resume, step, reset, or toggle the display;
pause requests take priority over an automatic tick. The [main README](../README.md)
explains the controls and demo.

Vivado derives the MMCM output clock from the 10 ns input constraint.
`board_io.xdc` excepts the asynchronous board interface and MMCM lock-to-reset
entry; internal processor paths and synchronizer stages remain timed.
