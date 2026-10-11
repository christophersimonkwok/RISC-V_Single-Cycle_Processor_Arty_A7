# Provenance

I originally developed the processor RTL in my digital systems course and later extended the project to run on the Arty A7-100T.

The 100MHz version was made using the help with AI. I was able to get my project running at 50 MHz, and I tried to get it to run at 100MHz. After running a more efficient implementation method, I reviewed the timing reports and had a very close margin to close. I used a little bit of advice from AI to help me optimize the parts with the worst timing delays in order to get it to work. After a bit of trial and error, I was eventually able to get it to work verifying the logic works using slightly modified testbenches, completed synthesis and implementation, and making the bitstream to test it in real life. I'm keeping it as a "experimental version" because I haven't fully tested it.

Only things AI assisted with was the experimental 100 MHz version, repository organization,
and the Tcl project-creation and build scripts (`scripts/create_project.tcl`
and `beta_100mhz/scripts/create_project.tcl`). I reviewed the changes, ran simulations, examined Vivado timing reports, and tested the design on the physical board.

The 100 MHz version retains the same single-cycle architecture and instruction set, with changes to register reads, memory addressing, and address validation. No pipeline stages were added.

Constraints and hardware references

constraints/arty_a7_100t.xdc is derived from Digilent’s Arty A7-100 master constraints. board_io.xdc adds timing exceptions for the asynchronous board interface and MMCM lock-to-reset path.

Hardware references:

- [AMD MMCME2_BASE documentation](https://docs.amd.com/r/2023.2-English/ug953-vivado-7series-libraries/MMCME2_BASE)
- [AMD automatically derived clocks](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Automatically-Derived-Clocks)
- [Digilent Arty A7-100 master constraints](https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-100-Master.xdc)

Instructor testbench files are omitted from this package.

The Digilent-derived constraints in both versions are covered by the notice in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The project's own files are licensed under the [MIT License](LICENSE); the
Digilent notice remains applicable to the Digilent-derived content.
