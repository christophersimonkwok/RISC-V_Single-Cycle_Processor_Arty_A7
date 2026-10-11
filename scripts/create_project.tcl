# vivado -mode batch -source scripts/create_project.tcl
# Add -tclargs build to synthesize, route, check timing, and write a bitstream.
set root [file normalize [file join [file dirname [info script]] ..]]
set build [file join $root build vivado]
set mode project
if {$argc > 0} {set mode [lindex $argv 0]}
if {$mode ni {project build}} {error "Expected project or build"}

create_project -force arty_processor $build -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
add_files [glob [file join $root rtl *.v]]
add_files -fileset constrs_1 [glob [file join $root constraints *.xdc]]
add_files -fileset sim_1 [glob [file join $root tb *.v]]
set_property top arty_a7_top [get_filesets sources_1]
set_property top tb_processor [get_filesets sim_1]
# BOARD_SIM is exclusively a simulation define; synthesis uses the MMCM.
set_property verilog_define {BOARD_SIM} [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {$mode eq "build"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
    launch_runs impl_1 -to_step route_design -jobs 4
    wait_on_run impl_1
    if {[get_property STATUS [get_runs impl_1]] ne "route_design Complete!"} {
        error "Routing failed; inspect the Vivado run log"
    }
    open_run impl_1

    set reports [file join $root build reports]
    file mkdir $reports
    report_clocks -file [file join $reports clocks.rpt]
    report_utilization -file [file join $reports utilization.rpt]
    report_timing_summary -delay_type min_max -report_unconstrained -file [file join $reports timing_summary.rpt]
    report_timing -delay_type max -max_paths 10 -path_type full_clock_expanded -file [file join $reports setup_paths.rpt]
    report_timing -delay_type min -max_paths 10 -path_type full_clock_expanded -file [file join $reports hold_paths.rpt]
    report_drc -file [file join $reports drc.rpt]
    report_cdc -file [file join $reports cdc.rpt]
    check_timing -verbose -file [file join $reports check_timing.rpt]

    # Verify the real MMCM-derived clock, rather than relaxing the input clock.
    set cpu_clocks [get_clocks -of_objects [get_pins clock_mmcm/CLKOUT0]]
    if {[llength $cpu_clocks] != 1} {error "Missing MMCM output clock; see clocks.rpt"}
    if {abs([get_property PERIOD $cpu_clocks] - 20.0) > 0.001} {
        error "Processor clock must have a 20 ns period (50 MHz)"
    }
    foreach delay {max min} {
        set paths [get_timing_paths -delay_type $delay -max_paths 1]
        if {[llength $paths] == 0} {error "No internal timing paths found"}
        if {[get_property SLACK [lindex $paths 0]] < 0} {
            error "Timing failed ($delay); see timing_summary.rpt"
        }
    }
    if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {
        error "DRC errors; inspect drc.rpt"
    }
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
        error "Bitstream generation failed; inspect the implementation log"
    }
    set bitfile [file join $build arty_processor.runs impl_1 arty_a7_top.bit]
    if {![file exists $bitfile]} {error "No bitstream produced; inspect the implementation log"}
    puts "Bitstream: $bitfile"
    puts "Review CDC and check_timing reports before programming."
}
puts "Project: [file join $build arty_processor.xpr]"
