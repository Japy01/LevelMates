import assert from 'node:assert/strict';
import { Net } from '../tools/lua-net.mjs';
const net = new Net(['Ana', 'Eve', 'Ben', 'Cris', 'Dani']);
net.leave('Dani');
for (const who of ['Ana','Eve','Ben','Cris','Dani']) {
 net.run(who,`local _,ns=...
 STUB.guildRoles={Ana=2,Eve=2,Ben=4,Cris=4,Dani=4}; ns.Roster.InvalidateGuildRoster()
 UnitClass=function() return "Class", STUB.player.name=="Ben" and "ROGUE" or "MAGE", 8 end
 IsInRaid=function() return STUB.player.name=="Ben" or STUB.player.name=="Cris" end
 GetNumGroupMembers=function() return 2 end
 UnitIsGroupLeader=function(unit) return unit=="raid1" end
 local original=UnitName
 UnitName=function(unit) if unit=="raid1" then return "Cris" elseif unit=="raid2" then return "Ben" end; return original(unit) end
 C_Item.GetItemCount=function() return 6 end`);
}
net.advance(5);
net.run('Ana','local _,ns=...; assert(ns.RaidRequirements.Set("guild",101,"ALL","100:5"))');
net.run('Eve','local _,ns=...; assert(ns.RaidRequirements.Set("guild",101,"ROGUE","100:10,200:2"))');
net.run('Cris','local _,ns=...; assert(ns.RaidRequirements.Set("raid",101,"ROGUE","100:15"))');
net.run('Ben','local _,ns=...; assert(ns.RaidReadiness.SetItems(101,"100:7,300:9")); assert(not ns.RaidRequirements.Set("guild",101,"ALL","100:99"))');
net.advance(15);
assert.equal(net.run('Ben',`local _,ns=...; local s=ns.RaidReadiness.Snapshot(101)
 assert(s.leader=="Cris" and #s.sources==3 and s.items[1].required==15 and #s.items[1].origins==4)
 assert(s.items[1].count==6 and s.items[1].status=="missing")
 return true`),true);
assert.equal(net.run('Ana','local _,ns=...; local s=ns.RaidReadiness.Snapshot(101); assert(#s.sources==1 and s.leader==nil); return true'),true);
// Member cannot impersonate an officer in a live packet OR in the whisper catch-up path.
for (const channel of ['GUILD','WHISPER']) {
 net.run('Eve',`local _,ns=...; local f={id="g101.ALL",o="Ana",a=101,s="ALL",i="100:999",v=GetServerTime()+30,e=GetServerTime()+9999}
 STUB.Receive("LVLM2",ns.Comm.Encode("rpg",f),"${channel}","Ben-Testrealm")
 assert(ns.RaidRequirements.Get("guild",101,"ALL").d.i=="100:5")
 local x={t="rpg",id="g101.ALL",o="Ana",v=GetServerTime()+40,e=GetServerTime()+9999}
 STUB.Receive("LVLM2",ns.Comm.Encode("x",x),"${channel}","Ben-Testrealm")
 assert(ns.RaidRequirements.Get("guild",101,"ALL"))`);
}
// A member's own candidate leader profile cannot grant them native leadership.
net.run('Ben',`local _,ns=...; STUB.Receive("LVLM2",ns.Comm.Encode("rpl",{id="p"..ns.NameKey("Eve")..".101.ROGUE",a=101,s="ROGUE",i="100:999",v=GetServerTime()+10,e=GetServerTime()+9999}),"GUILD","Eve-Testrealm")
 assert(ns.RaidReadiness.Snapshot(101).items[1].required==15)`);
// Same-second edits by different officers converge deterministically, independent of arrival order.
net.run('Ana','local _,ns=...; assert(ns.RaidRequirements.Set("guild",101,"ALL","100:11"))');
net.run('Eve','local _,ns=...; assert(ns.RaidRequirements.Set("guild",101,"ALL","100:12"))');
net.advance(15);
for (const who of ['Ana','Eve','Ben','Cris']) assert.equal(net.run(who,'local _,ns=...; local r=ns.RaidRequirements.Get("guild",101,"ALL"); assert(r.o=="Eve"); return r.d.i'),'100:12');
// Long profiles use existing chunked transport without silently dropping requirements.
net.run('Ana','local _,ns=...; local t={}; for i=1,20 do t[i]=(100000+i)..":999" end; assert(ns.RaidRequirements.Set("guild",103,"ALL",table.concat(t,",")))');
net.advance(20);
assert.equal(net.run('Ben','local _,ns=...; return #ns.RaidReadiness.Snapshot(103).items'),20);
net.join('Dani'); net.run('Dani',`local _,ns=...; UnitClass=function() return "Rogue","ROGUE",4 end; IsInRaid=function() return true end; GetNumGroupMembers=function() return 3 end; ns.Roster.Announce()`); net.advance(30);
assert.equal(net.run('Dani','local _,ns=...; local s=ns.RaidReadiness.Snapshot(101); assert(#s.sources==3 and s.items[1].required==15, "late member must receive both officer and non-officer leader profiles"); return #ns.RaidReadiness.Snapshot(103).items'),20);
// A missed conflicting packet must still be repaired: equal revisions with different authors
// have different digests, so catch-up cannot mistake the stale value for the current profile.
net.run('Ben', `local _,ns=...; local r=ns.Sync.Store("rpg")["g101.ALL"]; r.o="Ana"; r.d.i="100:11"; ns.Sync.Hello()`);
net.advance(20);
assert.equal(net.run('Ben','local _,ns=...; local r=ns.RaidRequirements.Get("guild",101,"ALL"); assert(r.o=="Eve"); return r.d.i'),'100:12');
// Changing the native leader immediately stops applying the previous leader's additions.
net.run('Ben',`local _,ns=...; UnitName=function(unit) if unit=="raid1" then return "Ben" elseif unit=="raid2" then return "Cris" end; return "Ben" end
 assert(ns.RaidReadiness.Snapshot(101).items[1].required==12)`);
console.log('ok tests/raid_requirements_sync.net.mjs');
