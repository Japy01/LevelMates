# LevelMates bot tag: format v1

**Who sends it:** LevelMates sends a line to the guild's linked Discord channel when a player creates a group with "Announce in Discord", joins one, leaves one, or cancels or withdraws it. Each line comes from that player's own Discord account (the game's link).

**When the tag appears:** on a line about a group that was made with the tag, whatever the sender's own setting. A group is made with the tag when its leader has it on, either through their own **Options → Share → "Tag for the guild's Discord bot"** or because the guild master or an officer turned on **"Discord bot tag for the whole guild"** (a player may opt out of the guild's choice). Lines about groups made without the tag carry it only if the sender has it on. The line then starts with a tag that a bot can read:

```
[LM1 id=a1b2c3d4 ev=join act=101 src=run at=29333333 by=Santo_Fiämbre lr=T who=Ana_Bel wr=H s=T1/5,H1/10,D0/25] [LevelMates] Ana Bel se apunta como sanador · …
```

**Where the tag sits:** it comes first, so it survives if the game's Discord bridge cuts a long line (it cuts at about 246 characters). The whole line is at most 236 bytes. What comes after the tag is for people to read and may be shortened.

## Fields

The tag is `[LM1` followed by `key=value` pairs separated by spaces, and closes with `]`.

- **Values:** never contain spaces (shown as `_`), `[`, `]`, `=` or `|`.
- **Order:** keys may come in any order.
- **Unknown keys:** ignore them. New ones may be added in v1.

| Key | Meaning |
|---|---|
| `id` | The group's id, 8 characters. It is the same in every line about that group. |
| `ev` | The event (see the table below). |
| `act` | The activity: 1–14 dungeons, 101–107 raids, 190 a raid with a name, 201–203 battlegrounds, 290 world PvP, 300 anything else. |
| `src` | `now` for a group looking for people right away; `run` for one with a day and hour. |
| `at` | When a `run` starts, in **minutes since 1970 (UTC)**: multiply by 60 for a Unix timestamp. Missing for `now`. |
| `n` | The name the leader gave, for activities 190, 290 and 300. Turn `_` back into spaces. |
| `by` | The leader's character name. |
| `lr` | The leader's role. |
| `lc`, `wc` | The class of the leader and of `who`, as the game's class tokens (`MAGE`, `PRIEST`, `WARRIOR`…), when the sender knows it. |
| `who`, `wr` | The character the event is about, and their role (for `join`, `leave`, `add`, `remove`). |
| `s` | The places **after** this event, per role, as `have/cap` (missing on `cancel`): `T1/5,H1/10,D0/25`, or `A12/40` for groups without roles. |

**Events (`ev`):**

| Event | What happened |
|---|---|
| `new` | The group was created. |
| `join` | `who` joined with role `wr`. |
| `leave` | `who` left. |
| `add` | The leader added `who`. |
| `remove` | The leader took `who` out. |
| `cancel` | The leader cancelled the run, or withdrew the Now group. |

**Roles:** `T` tank, `H` healer, `D` damage, `A` any (groups without roles).

## What a bot can rely on

- **Who sends what:**
  - the leader sends `new` and `cancel` (and `add`/`remove`);
  - each player sends their own `join` and `leave`.
- **Missing lines:** they happen (someone offline, a line held by the game until a click), so take `s` as the latest truth for the counts.
- **Who is in:** members known by name come from `by`/`lr` and the `who`/`wr` of joins, adds, leaves and removes.
- **When a group ends:**
  - a `run` is over 3 hours after `at`;
  - a `now` group lives 20 minutes from its last line unless renewed.
- **Reading back:** the game passes Discord text back to addons only as protected placeholders, so a bot cannot reply into the addon.
