read_liberty /foss/designs/sky130.lib
read_verilog ../synthesis/netlist/synth_rr_arbiter.v
link_design rr_arbiter
read_sdc sdc_files/rr_arbiter.sdc
puts "setup ---------------------------------"
report_checks -path_delay max -fields {slew cap input_pins nets fanout} -digits 3 > reports/rr_arbiter_setup_200Mhz.rpt
puts [exec cat reports/rr_arbiter_setup_200Mhz.rpt]
puts "hold ----------------------------------"
report_checks -path_delay min -fields {slew cap input_pins nets fanout} -digits 3 > reports/rr_arbiter_hold_200Mhz.rpt
puts [exec cat reports/rr_arbiter_hold_200Mhz.rpt]
puts "summary -------------------------------"
report_wns
report_tns
