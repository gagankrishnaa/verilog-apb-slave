# APB Slave — Verification

## Architecture

3-state APB (Advanced Peripheral Bus) slave implementing the AMBA APB protocol.

- **States:** IDLE → SETUP → ACCESS (SETUP lasts exactly one cycle)
- **Register file:** 4 × 8-bit registers (`mem[0:3]`), addressed by 2-bit `PADDR`
- **Signals:** `PCLK`, `PRESETn` (active-low), `PSEL`, `PENABLE`, `PADDR`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`

## Directed testbench

Manual write-then-read test. Two issues found and fixed:

1. Non-blocking-assignment race on `PRDATA` — checking the value immediately after `@(posedge PCLK)` without allowing the DUT's non-blocking updates to settle. Fixed with a `#1` delay after the edge before sampling results.
2. `PENABLE` must be held for two full clock edges after being asserted, not one — `state <= ACCESS` takes effect one edge before the `ACCESS` branch is dispatched, since case branches evaluate against the state at the start of the edge, not the state being assigned during it.

## Class-based (UVM-style) testbench

Constrained-random self-checking environment: `apb_transaction`, `apb_sequencer`, `apb_driver`, `apb_monitor`, `apb_scoreboard`, with an independent `ref_mem` reference model. 10/10 randomized transactions passing.

Issues found and fixed during development:

1. Attempted to drive `PENABLE` (an input) from inside the slave.
2. Read/write branches swapped in the `ACCESS` state.
3. Missing array indexing (`mem` instead of `mem[PADDR]`).
4. `PREADY` never cleared back to 0 after being set.
5. Incomplete case coverage — added `default: state <= IDLE;`.
6. Same-edge double assignment to `PREADY`: `PREADY <= 1` (from the `if(PENABLE)` branch) and `PREADY <= 0` (from a separate `if(PSEL)/else` block in the same `ACCESS` case, same clock edge) were both scheduled on the same edge; the last non-blocking assignment in program order silently won, leaving `PREADY` stuck at 0. Fixed by moving `PREADY <= 1` inside the `if(PSEL)/else` branches directly.
7. Monitor never set `txn.PWRITE` on the transaction object it created, defaulting to 0 and making the scoreboard's write-update path unreachable for all transactions. `ref_mem` was never updated by any write. Fixed by explicitly setting `txn.PWRITE = PWRITE` in both monitor branches.
8. Scoreboard originally overwrote `txn.PRDATA` with the expected value before comparing, making every check pass regardless of actual hardware output. Fixed to leave the field under test unmodified.

## SVA (SystemVerilog Assertions)

Three protocol-legality properties, embedded in `apb_slave` and guarded with `` `ifndef SYNTHESIS `` so they are excluded from synthesis.

```systemverilog
property p_penable_needs_psel;
  @(posedge PCLK) disable iff (!PRESETn) PENABLE |-> PSEL;
endproperty
```
PENABLE must not be high unless PSEL is also high in the same cycle.

```systemverilog
property p_setup_one_cycle;
  @(posedge PCLK) disable iff (!PRESETn) state == SETUP |=> state == ACCESS;
endproperty
```
SETUP must advance to ACCESS after exactly one cycle.

```systemverilog
property p_paddr_pwdata_stable;
  @(posedge PCLK) disable iff (!PRESETn) (state == ACCESS && PREADY == 0)
    |-> $stable(PADDR) && $stable(PWDATA);
endproperty
```
PADDR and PWDATA must not change while a transfer is pending (ACCESS, PREADY not yet high).

Each property was verified by injecting a matching violation into a scratch copy of the design or testbench and confirming the corresponding assertion fires with the expected message, while remaining silent against unmodified RTL.

### RTL bug identified via SVA

`p_paddr_pwdata_stable` fired against the unmodified driver, indicating a real RTL defect: the FSM could reach `ACCESS` with `PENABLE` low (e.g. following a back-to-back transaction where `PSEL` remains high) and remain there permanently. The `ACCESS` case's `else` branch (taken when `PENABLE` is low) only cleared `PREADY` and never reassigned `state`, leaving no exit path.

**Fix:** added `state <= IDLE;` to that branch so every path through the `ACCESS` case has an explicit next-state assignment.

## Debugging method

Issues were isolated using `$display` checkpoints placed at the entry of each `run()` task, followed by per-cycle checkpoints inside both the testbench and the DUT where needed to narrow down the exact cycle and signal responsible. Debug instrumentation was removed before the final commit.
