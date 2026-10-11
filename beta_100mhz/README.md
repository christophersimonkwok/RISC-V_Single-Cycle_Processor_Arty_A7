# Arty 100 MHz — unstable beta 

**Status: unstable beta / experimental.** Use the [complete 50 MHz version](../README.md)
at the repository root for the main project. All paths and commands below are
relative to this `beta_100mhz` folder. Keep its sources separate from the 50 MHz
sources when creating a Vivado project.

This is an experimental 100 MHz version of the [main 50 MHz project](../README.md), targeting the same **Arty A7-100T** (`xc7a100tcsg324-1`). It uses the same single-cycle processor, supported instructions, demo program, board controls, and 0.5-second playback interval.

The differences are:

- **Processor clock:** 100 MHz instead of 50 MHz, reducing the clock period from 20 ns to 10 ns.
- **Memory addressing:** a dedicated base-plus-immediate path and simplified address-validity logic.
- **Register reads:** decoded selection with an OR reduction to improve timing.

The register storage, ALU, and controller remain the same. The supplied final
Vivado report shows **+0.013 ns setup WNS**, **+0.122 ns hold WHS**, and zero
failing setup or hold endpoints. This version remains an **experimental beta**
because the setup margin is very small. See [validation evidence](docs/VALIDATION.md). Refer to the main README for the shared controls and demo instructions.

Building this version uses different steps so use setup instructions below. A fresh build still needs Vivado verification. Single-cycle execution is retained. Button debounce and run pacing stay at 10 ms and about
one instruction every 0.5 seconds.

## Manual Vivado setup

1. Extract into a new folder and create a new RTL project. After the project
   opens, go to Settings > General and check/set the project part to
   `xc7a100tcsg324-1` (Arty A7-100T).
2. Click Add Sources > Add or Create Design Sources. Add the five `.v` files
   from the `rtl` folder, then click Finish. Click Add Sources again, choose
   Add or Create Constraints, add both `.xdc` files from the `constraints`
   folder, then click Finish. The `.v` files belong under Design Sources;
   the `.xdc` files belong under Constraints.
3. Set `arty_a7_top` as the synthesis top. Do not define `BOARD_SIM` for synthesis.
4. In Settings > Implementation, select `Performance_ExplorePostRoutePhysOpt`
   in the Strategy dropdown under Settings (not the Report Settings dropdown).
5. Run synthesis and implementation. Open the final implemented design.
6. Optional: if the completed implementation already passes timing, skip the
   extra optimization. Otherwise, in the Tcl Console run the extra pass and
   display its report:

   ```tcl
   phys_opt_design -directive AggressiveExplore
   report_timing_summary -delay_type min_max -report_unconstrained -name timing_final
   ```

7. Check Report Clocks: the MMCM processor output must be **100 MHz / 10 ns**.
   Use the final implemented-design timing report, or `timing_final` if you ran
   step 6, rather than a report from an earlier stage.
   Check Report Timing Summary: setup WNS and hold WHS must be nonnegative,
   with zero failing endpoints. Review pulse-width, unconstrained-path, CDC,
   and DRC reports too. Earlier builds reported LUTAR-1 (LUT drives
   asynchronous reset); the current build's methodology report determines
   whether that warning remains.
8. Once checks pass, use the Tcl Console to save the currently open optimized
   design. Use a new output directory to keep the original working files intact:

   ```tcl
   set out_dir [file join [get_property DIRECTORY [current_project]] build final_100mhz]
   file mkdir $out_dir
   report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out_dir timing_final.rpt]
   write_checkpoint -force [file join $out_dir arty_100mhz_optimized.dcp]
   write_bitstream -force [file join $out_dir arty_100mhz_optimized.bit]
   puts $out_dir
   ```

   Program that new `.bit` through Hardware Manager. The normal Generate Bitstream
   run does not automatically include edits made in the open design.

If setup still fails, export the timing summary and the worst setup path with
its startpoint, endpoint, logic cells, and routing delays. That identifies the
next small change. Do not relax the clock or cut internal processor paths.

## Run and build

Run the Verilog testbenches in `tb` using your simulator. Add the five RTL
files as design sources and the desired testbench as a simulation source.
Set that testbench as the simulation top. Define `BOARD_SIM` for simulation
only; keep it unset for synthesis.

The optional script applies the strategy and extra AggressiveExplore pass. With Vivado installed:

```sh
vivado -mode batch -source scripts/create_project.tcl
```

Open `build/vivado/arty_address_v3.xpr` in Vivado, or build in batch mode:

```sh
vivado -mode batch -source scripts/create_project.tcl -tclargs build
```

The build script saves reports in `build/reports`, checks for a 10 ns processor
clock, setup/hold timing failures, and DRC errors before generating a bitstream.
Review the CDC and check-timing reports, then program
`build/arty_100mhz_optimized.bit` using Hardware Manager.
`build` is generated locally and excluded from Git. This source package includes the supplied timing reports in
`docs/reports/`; bitstreams and checkpoints are not included.

To change the program, edit `InstMem` in `rtl/dataPath.v` and rebuild.
`program/lab_program.hex` is a reference copy, not an automatically loaded file.
The tests are in `tb`; architecture and validation notes are in `docs`.
See the shared [provenance document](../PROVENANCE.md).
