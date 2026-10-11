# Mechanical controls and indicator LEDs have no synchronous external interface.
# Only paths starting/ending at these physical ports are excluded. Internal
# synchronizer stages, processor paths, and reset release remain timed.
set_false_path -from [get_ports {btn[*] sw[*]}]
set_false_path -to [get_ports {led[*] led0_r led0_g led0_b}]

# LOCKED is an MMCM output, not a valid -from timing startpoint.
# Match paths THROUGH it, only to the reset synchronizer asynchronous pins.
# Synchronous reset-release and all internal processor paths remain timed.
set_false_path -through [get_pins clock_mmcm/LOCKED] -to [get_pins -hierarchical -filter {NAME =~ *reset_release_reg* && (REF_PIN_NAME == PRE || REF_PIN_NAME == CLR)}]
