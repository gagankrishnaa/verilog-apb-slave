# APB Slave — RTL Design & Verification

A from-scratch implementation and full verification of an AMBA APB (Advanced Peripheral Bus) slave, following the actual AMBA APB protocol specification.

## Why this project

Second full-depth hardware project, deliberately chosen to mirror a real industry-recognized pattern: verifying a named, standard bus protocol (analogous to interfaces like Intel's 8255A) rather than a fully custom design. Reuses the complete toolchain proven on a prior UART project — FSM design, class-based UVM-style verification, SystemVerilog Assertions, Yosys synthesis, gate-level simulation — with zero new tools, so the focus stays on protocol correctness and verification depth rather than tooling.

## Architecture

3-state FSM (`IDLE` → `SETUP` → `ACCESS`), 4×8-bit addressable register file, full read/write support per the APB spec. See [VERIFICATION.md](VERIFICATION.md) for the complete signal list and protocol details.

## Frame / Transfer format

| Phase | PSEL | PENABLE | Duration |
|---|---|---|---|
| IDLE | 0 | 0 | until PSEL asserted |
| SETUP | 1 | 0 | always exactly 1 cycle |
| ACCESS | 1 | 1 | until PREADY asserted |

## Verification

Three layers, matching the UART project's rigor:
1. **Directed testbench** — manual write/read test, 2 real timing bugs found and fixed
2. **Class-based (UVM-style) testbench** — constrained-random, self-checking, independent reference model, 8 real bugs found and fixed across RTL/testbench/monitor/scoreboard
3. **SVA layer** — 3 protocol-legality properties, each proven via deliberate bug injection. **One of these properties found a genuine, previously-undetected RTL deadlock bug** that the class-based scoreboard alone never caught.

Full debugging log and interview-ready explanations: [VERIFICATION.md](VERIFICATION.md)

## Synthesis & GLS

Synthesized in Yosys (118 cells, 44 flip-flops). Gate-level simulation surfaced a genuine RTL-vs-netlist mismatch on memory reads, traced to an inferred address-pipeline register from indexed memory synthesis — a well-known, real category of GLS finding, documented rather than force-fixed same-session.

Full synthesis stats, flip-flop count investigation, and GLS root-cause analysis: [SYNTHESIS.md](SYNTHESIS.md)

## Files

- `design.sv` — APB slave RTL with embedded SVA assertions
- `testbench.sv` — class-based (UVM-style) constrained-random testbench
- `apb_slave_netlist.v` — post-synthesis gate-level netlist
- `apb_slave_schematic.png` — synthesized gate-level schematic
- `VERIFICATION.md` — full verification writeup and debugging log
- `SYNTHESIS.md` — synthesis results and GLS findings

## Next steps

- Fix the GLS-identified memory read-port timing mismatch
- STA (OpenSTA) timing analysis
- Companion project to [verilog-uart](https://github.com/gagankrishnaa/verilog-uart)
