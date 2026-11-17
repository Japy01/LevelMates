# Shared raid requirements and personal preparation

`/lm raidready config` opens the configuration editor. Choose a raid activity,
profile source and audience. `/lm raidready 101` opens your personal report for
Molten Core; 102 Onyxia, 103 ZG, 104 BWL, 105/106 AQ20/AQ40, 107 Naxx, 108/109 the
catalogue's custom raids and 190 free-named raid. Catalogue presence is not proof
a raid is open on the realm. No dependency on a scheduled event, Discord roster,
or the withdrawn weekly/composition PRs is introduced.

## Profiles and permissions

| Source | Who edits/publishes | Where it applies |
| --- | --- | --- |
| Personal reminders | This character | Private extras for the chosen activity |
| Guild minimums | Guild master/officers recognized by the existing roster permission model | Chosen activity, for everyone, a class or a selected role |
| Raid-leader profile | The actual current leader of an in-game raid | Chosen activity, while that author remains your current raid leader |

A class officer publishes the relevant class profile (for example ROGUE); an
officer may publish common requirements or any class/role profile. There is no
guess based on rank titles, and no new system of class-specific edit delegation:
all recognized guild officers retain edit rights. Raid assistants and scheduled
event creators gain no leader permission merely through those roles.

A non-officer raid leader may publish class/role/general requirements while
leading an actual raid. Native group APIs identify the leader on the receiving
client. Another member's stored/claimed leader profile is not applied. Leaving,
disbanding, changing leader or losing readable roster data stops applying the
previous leader's profile. Profiles are per author/activity, reusable if that
author leads again within eight hours, not tied to an invented encounter/session
ID. Clearing a leader profile publishes an empty list; expiry is eight hours.
Guild profiles expire after a year unless republished.

The report combines guild ALL + own class + explicitly chosen role, then the
current leader's matching profiles, then personal reminders. For a repeated item
it uses the **highest count**, never the sum. Thus a guild minimum of 10, leader
requirement of 15 and personal reminder of 7 require 15. Private lists and lower
leader counts cannot remove officer minimums. The report shows sources, authors,
update times and per-item origins. Roles are never inferred from class: without
a role selected in the existing Options, role-specific requirements are unknown.
Unreadable class data is explicitly unknown as well.

## Editor and commands

The editor has raid, source and audience menus, an item/count input, author/time,
permission feedback, Save profile and View my report. Members can inspect guild
profiles; publishing is disabled unless authorized and permissions are checked
again when saving. Switching the selected profile loads its existing contents.

Enter `itemID:count,itemID:count`, up to 20 distinct items per profile, IDs
1–999999, counts 1–999. Empty or `clear` clears that profile only. Invalid input
rejects the whole replacement. Personal reminders from the first version remain
personal; shared profiles are never copied into or used to overwrite them.

Equivalent commands (item numbers are configuration examples, not class advice):

```
/lm raidready config 101
/lm raidready guild 101 ALL 13446:10
/lm raidready guild 101 ROGUE 13446:15,13444:5
/lm raidready guild 101 D 13446:12
/lm raidready raid 101 ROGUE 13446:20
/lm raidready items 101 13444:8
/lm raidready access 101 yes
/lm raidready 101
```

Audience tokens: ALL, WARRIOR, PALADIN, HUNTER, ROGUE, PRIEST, SHAMAN, MAGE,
WARLOCK, DRUID, or T/H/D. `items` and `access` always remain private.

## Distribution and trust

Publishing profiles sends guild addon records, never public chat/Discord messages.
`rpg` contains mutable officer profiles keyed by activity/audience; `rpl` contains
leader profiles keyed by author/activity/audience. Existing record persistence,
chunking, pending sends and guild scoping are reused. Long 20-item profiles use
chunked transport. Saving is not proof of delivery; instance/realm restrictions
still apply and older clients do not understand these new profiles.

To prevent a member from claiming another author's policy through catch-up,
profile records **and tombstones** are accepted only from their author or a trusted
officer relay. Only officers claim general profile catch-up responses; a current
non-officer raid leader directly serves their own profiles on hello, throttled
per requester. New clients need an online officer for guild-policy catch-up;
ordinary members cannot relay cached policies as authoritative. Previously
received profiles remain saved locally. A missing/partial set is not a readiness
certificate: the report identifies the profiles it actually has, and explicitly
says when no shared profile is present.

Simultaneous same-revision officer edits resolve by deterministic author order;
the shared-profile digest includes the author so a missed conflict can reconcile.
Equal-revision deletion wins over a live record. These sync options are opt-in
for the requirement types; existing record types keep their previous behavior.
This trusts the guild's officers, not cryptographic signatures.

## API and privacy limits

The report is personal: inventory counts, access declarations and lockout lists
are not transmitted. Only published item requirements are shared. Access remains
a dated self-report, expired after seven days; no attunement/key/quest verdict.
Counts use carried inventory with bank/reagent/account-bank/charge-counting flags
disabled. Missing, protected, invalid or throwing APIs show Unknown. Combat or an
unreadable combat state blocks snapshot reads. There is no raid-wide inventory,
buff/aura inspection or automatic eligibility verdict.

Lockouts are cached client data; review/refresh the game's Raid Info manually.
There is no automatic activity-to-instance matching and an empty cache proves
nothing about eligibility. Run the command again to refresh an open snapshot.
`/lm raidprobe` remains the separate explicit transport diagnostic.

API basis: the client source mirror's
[raid info consumer](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RaidFrame/Mainline/RaidFrame.lua)
and [generated item documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua).
Native raid leadership reads are guarded; unknown results do not grant rights.

## Validation

Run `npm test`. The original readiness test covers API fallbacks, protected/throwing
values, zero counts, cached/extended lockouts, combat, personal expiry and guild
scoping. New unit tests cover permissions, class/role selection, max-count merge,
personal preservation, leader changes and the editor. The multi-client test covers
distribution, late arrival, a non-officer leader, long profiles, concurrent edits,
and rejection of forged live/catch-up policy updates and tombstones.

**No in-game tests performed.** With updated clients, test officer ROGUE/general
profiles on a rogue and another class; test a non-officer leader, leadership
transfer, profile clearing, selected roles, normal reload, delayed transport and
late login. Verify editor/report layout in English/Spanish. Keep real guild
standards out of test edits unless intentionally changing them.
