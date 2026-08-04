# APB Slave — Static Timing Analysis

*Files referenced below (netlist, constraints script, Liberty libraries) are located in `sta/`.*

## Tooling

Timing analysis performed with [OpenSTA](https://github.com/parallaxsw/OpenSTA), built from source. Standard cell timing data from the open Nangate45 library (typical, slow, and fast process corners), as distributed with OpenSTA's own example set.

## Technology mapping

The synthesis netlist used for STA is distinct from `apb_slave_netlist.v` (produced in the synthesis stage documented in [SYNTHESIS.md](SYNTHESIS.md)). That netlist uses Yosys's generic internal cells, which have no corresponding entries in any real standard cell library. A second netlist, `apb_slave_nangate45.v`, was produced by mapping the design onto real Nangate45 cells:

```
read_verilog -sv design.sv
synth -top apb_slave
dfflibmap -liberty nangate45_typ.lib
abc -liberty nangate45_typ.lib
write_verilog apb_slave_nangate45.v
```

`dfflibmap` maps generic flip-flops to real Nangate45 sequential cells (`DFF_X1`, `DFFR_X1`, `DFFS_X1`). `abc -liberty` maps generic combinational logic to real Nangate45 gates (`NAND4_X1`, `NOR3_X1`, `MUX2_X1`, etc.), using the Liberty file's actual delay data to inform the mapping.

## Constraints

```tcl
create_clock -name PCLK -period 10 {PCLK}
set_input_delay -clock PCLK 0 {PSEL PENABLE PADDR PWRITE PWDATA}
```

10ns period, matching the clock period used throughout RTL/GLS simulation. Input delay set to 0 (primary inputs assumed aligned with the clock edge) as a first-pass simplification; a real system-level constraint set would derive input delay from the actual upstream driving logic.

## Results

Both setup (`-max`, slow corner) and hold (`-min`, fast corner) checks were run via `report_checks -path_delay min_max`.

**Setup (worst-case slow corner):**
```
Startpoint: _435_ (DFFR_X1)
Endpoint:   _394_ (DFF_X1)
Path: DFFR_X1/Q → NAND4_X1 → NOR3_X1 → MUX2_X1 → DFF_X1/D
Data arrival time: 1.43 ns
Data required time: 9.83 ns
Slack: 8.41 ns (MET)
```

**Hold (worst-case fast corner):**
```
Startpoint: PENABLE (primary input)
Endpoint:   _434_ (DFFS_X1)
Path: PENABLE → OAI21_X1 → DFFS_X1/D
Data arrival time: 0.01 ns
Data required time: 0.00 ns
Slack: 0.01 ns (MET)
```

Both checks pass at the 10ns clock period across both process corners.

## Notes and limitations

- Synthesis was run without flags to preserve original RTL signal names through technology mapping, so timing paths are reported against internal ABC-generated net names (e.g. `_435_`, `_394_`) rather than original RTL signal names (`state`, etc.). Preserving naming through synthesis would improve report readability in a future pass.
- Input delay is set uniformly to 0 across all primary inputs as a simplifying first-pass assumption, not derived from a specific upstream driving scenario.
- Clock network delay is modeled as ideal (zero); no clock tree synthesis or clock uncertainty margin has been applied.
