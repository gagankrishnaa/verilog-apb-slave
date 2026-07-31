# APB Slave — RTL Design & Verification

An RTL implementation and verification of an AMBA APB (Advanced Peripheral Bus) slave, built to the AMBA APB protocol specification.

## Overview

Second hardware verification project, built on the same toolchain used for [verilog-uart](https://github.com/gagankrishnaa/verilog-uart): FSM design, class-based constrained-random verification, SystemVerilog Assertions, Yosys synthesis, and gate-level simulation.

## Architecture

3-state FSM (`IDLE` → `SETUP` → `ACCESS`), 4×8-bit addressable register file. Full protocol and signal details in [VERIFICATION.md](VERIFICATION.md).

| Phase | PSEL | PENABLE | Duration |
|---|---|---|---|
| IDLE | 0 | 0 | until PSEL asserted |
| SETUP | 1 | 0 | exactly 1 cycle |
| ACCESS | 1 | 1 | until PREADY asserted |

## Verification

- Directed testbench
- Class-based (UVM-style) constrained-random testbench with independent reference model
- 3 SVA properties, each verified via fault injection

Full verification writeup and debugging log: [VERIFICATION.md](VERIFICATION.md)

## Synthesis & GLS

Synthesized in Yosys (118 cells, 44 flip-flops). Gate-level simulation identified an RTL/netlist behavioral mismatch on memory reads.

Full synthesis results and root-cause analysis: [SYNTHESIS.md](SYNTHESIS.md)

## Files

- `design.sv` — APB slave RTL with embedded SVA
- `testbench.sv` — class-based constrained-random testbench
- `apb_slave_netlist.v` — post-synthesis gate-level netlist
- `apb_slave_schematic.png` — synthesized gate-level schematic
- `VERIFICATION.md` — verification methodology and findings
- `SYNTHESIS.md` — synthesis results and GLS findings

## Status / next steps

- Resolve the GLS-identified memory read-port timing mismatch
- STA (OpenSTA) timing analysis
