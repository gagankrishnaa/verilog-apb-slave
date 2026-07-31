# APB Slave — Synthesis & GLS

## Yosys synthesis

```
read_verilog -sv design.sv
hierarchy -check -top apb_slave
proc
opt
synth -top apb_slave
stat
```

SVA properties are excluded automatically — they are wrapped in `` `ifndef SYNTHESIS ``, and `property`/`assert property` are not synthesizable constructs.

**Result:** 118 cells, 44 flip-flops, 0 problems reported by `check`.

### Flip-flop count

| Register | Width | Count |
|---|---|---|
| `state` | 2 bits | 2 |
| `mem[0:3]` | 4 × 8 bits | 32 |
| `PREADY` | 1 bit | 1 |
| `PRDATA` | 8 bits | 8 |
| Address-pipeline register (see below) | — | 1 |
| **Total** | | **44** |

The declared registers account for 43 of the 44 flip-flops. The remaining flip-flop was traced using `select -list` immediately after the `proc` pass (before technology mapping discards original signal names) to a `mem2reg_rd` address-pipeline register — an artifact of how Yosys implements a variable-indexed array (`mem[PADDR]`) as explicit read-port logic.

## GLS (Gate-Level Simulation)

Synthesized netlist re-simulated against the same class-based testbench used for RTL simulation. Output compared against a saved RTL reference run via `diff`.

### RTL/netlist mismatch

```
< PASS: expected f6, recieved f6      (RTL)
> FAIL: expected f6, recieved 83      (GLS)
```

**Cause:** the address-pipeline register identified above causes the synthesized read port to index memory using the previous cycle's `PADDR` rather than the current cycle's. On a read immediately following a write to a different address, the netlist returns data from the prior transaction instead of the current one.

**Status:** identified, not yet corrected. A fix requires either registering `PADDR` explicitly in the RTL so its timing matches what synthesis infers, or applying memory-blackboxing directives to control array-to-flip-flop mapping directly.
