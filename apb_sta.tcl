read_liberty -max nangate45_slow.lib
read_liberty -min nangate45_fast.lib
read_verilog apb_slave_nangate45.v
link_design apb_slave

create_clock -name PCLK -period 10 {PCLK}
set_input_delay -clock PCLK 0 {PSEL PENABLE PADDR PWRITE PWDATA}
report_checks -path_delay min_max

