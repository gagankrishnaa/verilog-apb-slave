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

SVA properties are automatically excluded — they're wrapped in `` `ifndef SYNTHESIS ``, and `property`/`assert property` aren't synthesizable constructs Yosys can parse in the first place.

**Result:** 118 cells, 44 flip-flops, 0 problems reported by `check`.

### Flip-flop count: predicted vs. actual

Hand-counted from source before running `stat`:

| Register | Width | Predicted FFs |
|---|---|---|
| `state` | 2 bits | 2 |
| `mem[0:3]` | 4 × 8 bits | 32 |
| `PREADY` | 1 bit | 1 |
| `PRDATA` | 8 bits | 8 |
| **Total** | | **43** |

**Actual: 44.** Traced the 1-register discrepancy using `select -list` right after the `proc` pass (before technology mapping erases signal names): the extra flip-flop comes from a `mem2reg_rd` address-pipeline register — a byproduct of how Yosys implements a variable-indexed array (`mem[PADDR]`) as explicit read-port logic, not a bug in the RTL or an error in the hand-count method. Hand-counting declared registers gives the architectural register count; tools can add pipeline registers for indexed memory access that aren't obvious from reading the source alone.

## GLS (Gate-Level Simulation)

Synthesized netlist re-simulated against the same class-based testbench used for RTL simulation, output compared via `diff` against a saved RTL reference run.

### Result: genuine RTL-vs-netlist mismatch found

```
< PASS: expected f6, recieved f6      (RTL)
> FAIL: expected f6, recieved 83      (GLS)
```

**Root cause:** the same `mem2reg_rd` address-pipeline register identified during the FF-count investigation above causes the synthesized read port to index memory using the **previous** cycle's `PADDR`, not the current cycle's. On a read immediately following a write to a *different* address, the netlist returns the previous transaction's data instead of the current one — a genuine one-cycle read-latency mismatch introduced by default indexed-memory synthesis, not present in the RTL simulation.

This is a well-known category of GLS finding — RTL sim checks logic correctness against the behavioral description; GLS checks whether synthesis preserved that exact behavior. Here, it didn't, for indexed memory reads specifically.

**Status:** documented, not yet fixed. A fix would require either restructuring the RTL's read-port timing to be synthesis-friendly (e.g. explicitly registering `PADDR` in the RTL itself so behavior matches what Yosys infers) or using memory-blackboxing directives to control array-to-flip-flop mapping directly. Left as a known, understood limitation pending a follow-up session — deliberately not force-fixed same-night to avoid risking regressions in an already-passing design.

## Interview-ready summary

*"During GLS I found a real RTL-vs-netlist mismatch on memory reads — the synthesized netlist has an extra address-pipeline register that RTL simulation doesn't model, causing one-cycle-stale reads after synthesis. I traced it back to the same inferred pipeline register I'd already found while investigating a 1-flip-flop discrepancy between my hand count and Yosys's actual count — using `select -list` right after the `proc` pass to see original signal names before technology mapping erased them."*
