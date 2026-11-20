read_liberty /foss/designs/sky130.lib
read_verilog ../../synthesis/netlist/synth_sync_fifo.v
link_design sync_fifo
read_sdc ../common.sdc
puts "setup ---------------------------------"
report_checks -path_delay max -fields {slew cap input_pins nets fanout} -digits 3 > ../reports/sync_fifo_setup_200Mhz.rpt
puts [exec cat ../reports/sync_fifo_setup_200Mhz.rpt]
puts "hold ----------------------------------"
report_checks -path_delay min -fields {slew cap input_pins nets fanout} -digits 3 > ../reports/sync_fifo_hold_200Mhz.rpt
puts [exec cat ../reports/sync_fifo_hold_200Mhz.rpt]
puts "summary -------------------------------"
report_wns
report_tns
