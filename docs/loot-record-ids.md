# Loot record identity across reloads

Loot ledger entries (`lk`), awards (`la`) and +1 adjustments (`lp`) previously
used a module-local sequence in their IDs. Reloading the module in the same
second reset that sequence and could generate an ID already in the local store.
`Sync.Put` then treated the supposed new entry as an update, overwriting it.
A deterministic harness reproduction posts +10, reloads Loot.lua without
advancing the clock, then posts +5: the old balance is 5 instead of 15.

The allocator now persists its sequence in character SavedVariables and checks
all three retained stores before returning an ID. The store check also covers
older profiles, a lost/reset sequence, a repeated clock and retained tombstones.
The counter rolls over within Lua's signed 32-bit integer range, retaining the
existing wire format and the 24-byte record/reference bound. This is local ID
collision protection; it does not claim to deduplicate two independent officers'
separate decisions or two intentional awards of the same item.

No existing ledger entry, award, reference or protocol schema is migrated.
Already overwritten history cannot be reconstructed by this fix. Reconcile such
history against external evidence and use the existing adjustment/refund tools.
Normal reload/logout persists the counter; an unsaved crash can lose its latest
value, but retained records are still checked on allocation.

`tests/loot_reload_ids.net.mjs` reproduces module reloads without clock advance,
checks balances/history/+1 adjustments and wire validation, and resets the saved
counter to exercise migration/collision handling. It is an out-of-game harness,
not evidence of an actual WoW client reload. Run `npm test` for the full suite.

In-game validation remains outstanding: on a disposable test profile, record
points and awards, reload immediately, record new ones, and verify both clients'
ledger/history retain every entry without changing prior amounts. Do not test
this by editing a production guild's balances.
