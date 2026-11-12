# Optional NeedRoll wishlist source

`/lm wishsource needroll` explicitly opts this character into reading and sharing
the first ten distinct items of NeedRoll's **current** named wishlist through
Forever Guild's existing wishlist transport. `/lm wishsource` reports the source,
active count and total; `/lm wishsource local` restores the original character list.
The default remains local. Normal guild sharing/transport controls still apply.

No items are imported into `LevelMatesDB` and no code writes `NeedRollDB`. The
original Forever Guild list remains intact while the external source is active.
The Wishes page identifies NeedRoll, disables Add, and sends editing/removal/
priority actions back to NeedRoll instructions. Receiving loot does not remove a
NeedRoll wish. Gifts continue to use Forever Guild normally. External priorities
are not invented or copied.

The existing guild wishlist limit is ten items. NeedRoll's order determines the
first ten; duplicates count once. Reorder/select the desired list in NeedRoll to
choose what is shared. Extra items are neither shown as personal Forever Guild
wishes nor shared, so the two addons' personal alerts may cover different items.
Other members' ordinary guild wishlists remain visible. The displayed "since"
for external items is when this character selected the source, not NeedRoll's
item-addition date. Changes are detected within five seconds; guild delivery
still depends on existing transport restrictions. This is a transient view plus
ordinary peer caches, not a second editable/persisted personal list.

## Compatibility

There is no public wishlist accessor in the inspected NeedRoll API. This original
adapter reads only its SavedVariables wishlist structure, observed in reference
v1.4.1 and the installed v1.7.0 `Core/Wishlist.lua`. No NeedRoll source is bundled.
It validates the selected named list and item IDs, with bounded list/item scans,
and requires NeedRoll to be loaded. The optional TOC dependency handles load order.
This is schema-dependent interoperability, not an upstream-guaranteed API.

If NeedRoll is absent, its current list cannot be found, or the schema/items are
incompatible, the source stays selected but contributes no wishes; the existing
transport withdraws previous shared wishes. It never silently falls back to an
unrelated local list. Selecting local restores that list. The status command
explains how to recover. NeedRoll's account-wide current selection can differ
between characters; this preference belongs to the Forever Guild character.

## Validation

Run `npm test`. The focused `tests/needroll_source.test.lua` covers opt-in,
no source writes, local-list preservation/restoration, duplicate filtering, live
selection changes, the ten-item limit, missing/incompatible/unloaded sources,
empty withdrawal, read-only edit paths, loot handling, commands and board controls.

**Not tested in game.** On WoW Forever with NeedRoll v1.7.0, verify source status,
list selection/reordering, guild reception on another client, overflow/unavailable
labels, source switching/reload, loot receipt and English/Spanish board layout.
Check that switching back restores the old list and NeedRoll's data is unchanged.
