# Guild sync practices: notes for LevelMates

Prose notes for designing our own sync layer. They come from studying how another WoW Forever guild addon behaves; no code was taken. Our implementation is written from these notes only.

## Transport
- One prefix. Every message carries a protocol version; unknown versions are dropped.
- Compact delimiter format; escape the delimiters. Send IDs, never item links. Refuse anything over the limit (about 240 chars); never truncate.
- Large payloads go out in chunks:
  - about 150 chars each, with blob id, index and total;
  - reassembled in any order, duplicates ignored;
  - partial buffers dropped after 30 s;
  - no acks: the next occasion resends.
- One central queue at a fixed pace (about 5 msg/s):
  - an urgent lane ahead of a bulk lane;
  - a hard cap (300); oldest bulk dropped first;
  - drops counted.
- Restrictions: check before every send (restricted instance, restricted combat, chat lockdown).
  - Hold messages while restricted: urgent expire after about 10 min, bulk after 60.
  - Resume 2 s after zone change, regen enabled or entering world.
- Trust only the server's sender name. A client publishes only its own data, stored under the sender's name. On whisper or group channels, accept only roster members. If membership is unknown, drop the message and rebuild the roster.

## Relay / catch-up
- Owner-only publishing for personal records, each with a timestamp. Newer wins. Your own live measurement is never overwritten by synced data.
- Shared boards (runs, quest requests, notes) are stored by everyone and relayed to newcomers:
  - the relay names the original author;
  - your own items are sent at once; others' items after a random 0–6 s, and only if nobody broadcast that item in the last 20 s;
  - tombstones go with the answer, and expire on the data's horizon;
  - expired items are pruned before answering;
  - incoming items are rejected if tombstoned, our own, not newer, or out of time bounds (more than 1 h in the future, or past the lifetime).
- Requests carry the requester's newest stamp or a manifest of ids and revisions. Only holders of something newer answer, with a random delay, at most once a minute, capped per request.
- Digest catch-up:
  - a tiny periodic digest (count + newest stamp), every 10 min plus jitter;
  - a client that is behind whispers one peer, after a random 2–10 s, with one request pending at a time;
  - the answer goes oldest first, at most 20 per round.
- Hello: answered by whisper to the sender only, carrying the digest, so a fresh client catches up in seconds.
- Authority: one owner per record (a run's leader owns its member list). Joins for a full role are ignored, and the leader answers joins with the authoritative list.
- "Only one client speaks" for visible chat lines: the first to notice sends a claim on the addon channel, waits 1–5 s at random, and others back off. Claims expire after 60 s.
- Startup is staggered: each module waits its own delay after login (7–45 s). Notices are muted for the first 20 s.

## Positions
- Check every 3 s.
- Send only after moving at least 0.006 of the map width (or changing map), and at most every 15 s.
- Keep-alive every 5 min. Forced send on zone change.
- Opening the world map sends a request (30 s cooldown); others answer after a random 0.5–6.5 s.
- Pins go stale after 5 min. Positions live in memory only, never saved. Sharing is one switch for both directions.

## Discord through guild chat
- Detect the link with `C_Discord.IsEnabled()` (in pcall: true / false / unknown).
- Send with `SendChatMessage(text, "GUILD_DISCORD")`. The guild master must link Discord and tick "separate chat". Reading Discord text back is not possible (protected).
- Bridge limit: measured 246 chars; keep lines at 236 or less. Replace pipes.
- Each client writes only its own action (post, join, role change, leave, cancel), and only for items flagged "announce".
- Lines: dungeon, day, HH:MM, leader, open roles (or "full"), note.
- When locked:
  - keep only the latest line per item;
  - retry every 10 s, 3 s between lines;
  - drop held lines after 30 min.
- After `ADDON_ACTION_BLOCKED` during our own send: no automatic retry; a 30 s cooldown and a "Send to Discord" click button instead.

## Performance
- Memory figures count allocations (churn), not what is held. Measure before and after a collect.
- Avoid closures and timers in hot paths:
  - one persistent ticker frame with an accumulator, not chained `C_Timer.After`;
  - check the time gate before any work;
  - helpers at file scope.
- One event frame for all modules; register an event only while it has handlers.
- Lazy views, refreshed only while visible. Debounce resize and scans (1.2–1.5 s quiet). Recycle rows; never recreate frames.
- Cache roster lookups (about 30 s) in flat tables.
- Prune and compact old records. Cap every list. Session-only data is never saved.

## Forever names
- Names can be "First Last". Split name and realm only at the hyphen.
- `UnitName("player")` returns only the first word, and puts the second word in the realm slot. Use the roster or the sender name for the full name.
- Compare by word-boundary prefix within the same realm.
- Whisper targets use the bare name (no realm). Invites use the roster spelling.
- Never treat "unknown" as "empty": an empty list never overwrites a full one, and a partial roster never removes members.
