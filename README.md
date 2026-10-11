# Single-cycle processor on Arty A7

Hello, here is my original processor I made, a single-cycle processor using a custom subset of RISC-V, and runs it from a real Arty A7-100T (`xc7a100tcsg324-1`). All the rtl files are originally made in my class, and I developed the wrapper after completing the course.
There are two versions, the 50MHz and 100 MHz versions. More information in is the versions section.

I will make a little disclaimer here, a little bit of AI was used for the 100MHz version and organizing this repo. Other than that, everything about the hardware design is my own. I want to be honest with my work. I would recommend reading `PROVENANCE.md` to see what was specifically used since it wasn't a whole lot.

The setup instructions here are for the 50 MHz version and runs it from a real 50 MHz internal clock using the Arty A7-100T (`xc7a100tcsg324-1`).
The board input remains 100 MHz; the MMCM in `arty_a7_top.v` converts it to 50 MHz. 

The demo executes a predefined 20-instruction program. To run a different program using the supported instructions, edit the InstMem module in rtl/dataPath.v and rebuild the bitstream. program/lab_program.hex contains a reference copy of the demo instructions so it is not loaded automatically.

The project provides a small, inspectable example of how instruction decoding, registers, arithmetic, memory, and board controls work together in an RTL processor. This project is designed to be simple to help others understand basic rtl cpu design and how it flows. 

## Versions

| Version | Location | Status |
| --- | --- | --- |
| 50 MHz | Repository root | Main version |
| 100 MHz | [`beta_100mhz`](beta_100mhz/README.md) | Experimental beta |

The supplied final Vivado reports show setup WNS of **+5.185 ns at 50 MHz**
and **+0.013 ns at 100 MHz**, with zero setup or hold failures. The 100 MHz
version remains experimental because its timing margin is small. See the
[validation results](docs/VALIDATION.md) and
[beta results](beta_100mhz/docs/VALIDATION.md). Recheck timing after hardware
changes. Build one version at a time; do not combine their RTL files.

## Demo videos

Both finished demos are included in [`media/`](media/):

- [Autoplay, pause, step, and resume](media/DEMO_auto.mp4)
- [Manual walkthrough of the instruction sequence](media/DEMO_manual.mp4)

## Build the 50 MHz version

Use Vivado with part `xc7a100tcsg324-1` and top module `arty_a7_top`.
Add the five Verilog files from `rtl/` and both constraint files from
`constraints/`. Keep `BOARD_SIM` undefined for synthesis. Run synthesis and
implementation, then verify the reported processor clock is 50 MHz (20 ns),
setup and hold slack are nonnegative, and there are no failing endpoints
before generating a bitstream. Review the CDC, unconstrained-path, DRC, and
reset-methodology reports as well.

An optional Tcl build is available from the repository root:

```sh
vivado -mode batch -source scripts/create_project.tcl
```

To run synthesis, implementation, and bitstream generation in batch mode, use:

```sh
vivado -mode batch -source scripts/create_project.tcl -tclargs build
```

The script writes generated files under `build/`. Review the reports before
programming the generated bitstream. See [`docs/VALIDATION.md`](docs/VALIDATION.md)
for validation notes and [`beta_100mhz/README.md`](beta_100mhz/README.md) for
separate instructions for the experimental build.

## Board controls

The board resets into a paused state. The ordinary LEDs LD4–LD7 display the
selected four-bit group; LD0 is the RGB status LED.

| Control | Action |
| --- | --- |
| BTN0 | Reset and restart, paused, in result view |
| BTN1 | Step once while paused; pause while running |
| BTN2 | Start or pause automatic playback (one instruction every 0.5 seconds) |
| BTN3 | Toggle between result and PC views |
| SW3 | Select ALU result (0) or register writeback (1) in result view |
| SW[2:0] | Select one of eight four-bit groups, from least to most significant |
| LD4–LD7 | Display the selected four bits; LD4 is the least significant bit |
| LD0 (RGB) | Blue: paused/finished; green: running; red: fault requiring reset |

The included program runs 20 instructions and stops at PC `0x50`. Its final
ALU result is `0x30` (the load address), and its final register writeback is
`5`. Press BTN0 to restart. The board controls, instruction list, and expected
values are also demonstrated in the included videos.

To change the program, edit `InstMem` in `rtl/dataPath.v` and rebuild.
`program/lab_program.hex` is a reference copy; it is not loaded automatically.
The supported subset and design structure are described in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Simulation

The included testbenches passed in Vivado XSim: **100 checks for 50 MHz**
and **1,158 checks for the beta**. Follow the
[simulation instructions](docs/VALIDATION.md#running-in-vivado-xsim).

## Acknowledgments

Thank you to Professor Mahmoud Elfar for teaching the digital systems course
where I developed the original processor and for providing the foundation
for this project. I later extended the design to run on the Arty A7.

## License and credit

This project is licensed under the [MIT License](LICENSE). You may use,
modify, and redistribute it under that license, including commercially.
Copies or substantial portions must retain the copyright and license notice.
If you use or build on this project, please also credit me and link back to
this repository; this is a request, not an additional license condition.

The original processor RTL was developed for coursework. Instructor testbench
files are omitted. The Digilent-derived constraints retain their separate MIT
notice in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
See [PROVENANCE.md](PROVENANCE.md) for project history and AI-assisted work.
