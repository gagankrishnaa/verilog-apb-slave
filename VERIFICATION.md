# APB Slave — Verification

## Architecture

A 3-state APB (Advanced Peripheral Bus) slave implementing the AMBA APB protocol:

- **States:** IDLE → SETUP → ACCESS (SETUP always lasts exactly one cycle)
- **Register file:** 4 × 8-bit registers (`mem[0:3]`), addressed by 2-bit `PADDR`
- **Signals:** `PCLK`, `PRESETn` (active-low), `PSEL`, `PENABLE`, `PADDR`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`

## Verification (1): Directed testbench

Manual write-then-read directed test. Found and fixed two real bugs during this stage:

1. **Non-blocking-assignment race on `PRDATA`** — checking `PRDATA` immediately after `@(posedge PCLK)` without letting the DUT's non-blocking updates settle. Fixed with a `#1;` settle delay after the edge before reading results.
2. **PENABLE hold-time off-by-one** — PENABLE needs to be held for **two** full clock edges after asserting it, not one, because `state <= ACCESS` takes effect one edge before the `ACCESS:` branch is ever dispatched (case branches evaluate based on what `state` was at the *start* of that edge, never what it's being changed to during that edge).

## Verification (2): Class-based (UVM-style) testbench

Constrained-random self-checking environment: `apb_transaction`, `apb_sequencer`, `apb_driver`, `apb_monitor`, `apb_scoreboard`, with an independently-built `ref_mem` reference model (deliberately not sharing logic with the DUT). 10/10 randomized transactions passing, 100% pass rate.

**Bugs found and fixed during RTL/testbench development:**

1. Attempted to drive `PENABLE` (an input) from inside the slave — can't write to inputs.
2. Read/write branches swapped in the `ACCESS` state.
3. Forgot to index into the `mem` array (`mem` vs `mem[PADDR]`).
4. `PREADY` never cleared back to 0 after being set — added clearing logic.
5. Incomplete case coverage (`CASEINCOMPLETE` warning) — added `default: state <= IDLE;`.
6. **Same-edge double-assignment race on `PREADY`** — `PREADY <= 1` (from the `if(PENABLE)` branch) and `PREADY <= 0` (from a separate `if(PSEL)/else` block, same `ACCESS:` case, same clock edge) were both scheduled on the same edge — last non-blocking assignment in program order silently won, keeping `PREADY` permanently stuck at 0. Fixed by restructuring so `PREADY <= 1` happens inside the `if(PSEL)/else` branches themselves.
7. In the monitor, `txn.PWRITE` was never explicitly set on the transaction object it created — defaulted to 0 always, making the scoreboard's write-update branch structurally unreachable for all transactions. `ref_mem` never got updated by any write. Fixed by explicitly setting `txn.PWRITE = PWRITE;` in both monitor branches.
8. Scoreboard originally overwrote `txn.PRDATA` with the expected value *before* comparing, making every check trivially pass regardless of actual hardware behavior. Fixed to never modify the field it's checking.

## Verification (3): SVA (SystemVerilog Assertions)

Three protocol-legality properties, each embedded directly in `apb_slave`, guarded with `` `ifndef SYNTHESIS `` so they simulate but never reach synthesis:

```systemverilog
property p_penable_needs_psel;
  @(posedge PCLK) disable iff (!PRESETn) PENABLE |-> PSEL;
endproperty
```
PENABLE can never be high unless PSEL is high on that same cycle.

```systemverilog
property p_setup_one_cycle;
  @(posedge PCLK) disable iff (!PRESETn) state == SETUP |=> state == ACCESS;
endproperty
```
SETUP always advances to ACCESS after exactly one cycle.

```systemverilog
property p_paddr_pwdata_stable;
  @(posedge PCLK) disable iff (!PRESETn) (state == ACCESS && PREADY == 0)
    |-> $stable(PADDR) && $stable(PWDATA);
endproperty
```
PADDR/PWDATA must not change while a transfer is still pending (ACCESS, PREADY not yet high).

**All three properties proven** via deliberate bug injection into scratch copies of the design/testbench — each confirmed to stay silent on correct RTL and correctly fire on an injected violation of exactly the rule it enforces.

### Real bug found via SVA

While proving `p_paddr_pwdata_stable`, the property fired on **correct-looking driver code**, revealing a genuine RTL bug: the FSM could reach `ACCESS` with `PENABLE` low (e.g. immediately after a back-to-back transaction where `PSEL` stays high) and then get **permanently stuck** — the `ACCESS` case's `else` branch (taken when `PENABLE` is low) only cleared `PREADY`; it never reassigned `state`, so the FSM silently held `state <= state` forever with no legal exit path.

**Fix:** added an explicit `state <= IDLE;` in that `else` branch, giving every path out of the `ACCESS` case an explicit next-state assignment.

This is a genuine example of SVA catching a defect the class-based scoreboard alone could never find, since the scoreboard only checks data correctness, not protocol/FSM legality.

## Debugging methodology (systematic, not guesswork)

Used `$display` checkpoints at the entry of every `run()` task, then progressively more granular checkpoints (per-cycle state snapshots inside both the testbench and the DUT itself) to bisect exactly where and why the pipeline broke — the same bisection method used throughout the UART project. All debug scaffolding removed before final commit; only the real fixes remain.
