import assert from 'node:assert/strict';
import { Net } from '../tools/lua-net.mjs';

const net = new Net(['Ana', 'Ben', 'Cris', 'Dani']);
net.leave('Dani');
for (const player of ['Ana', 'Ben', 'Cris', 'Dani']) {
  net.run(player, `local _,ns=...
    STUB.guildRoles={Ana=2,Ben=2,Cris=4,Dani=4}
    ns.Roster.InvalidateGuildRoster()`);
}
const exists = player => net.run(player, 'local _,ns=...; return ns.Sync.Get("gan","raidfood") ~= nil');
net.advance(5);
net.run('Ana', 'local _,ns=...; assert(ns.Sync.Put("gan","raidfood",{h="Raid food",b="Bring food"}))');
net.advance(7);
assert.equal(exists('Ben'), true);
assert.equal(exists('Cris'), true);
net.leave('Ana');
net.join('Dani');
net.run('Dani','local _,ns=...; ns.Roster.Announce()');
net.advance(25);
assert.equal(exists('Dani'), true);
net.leave('Dani');
net.run('Ben', 'local _,ns=...; assert(ns.Sync.Remove("gan","raidfood"))');
net.advance(7);
assert.equal(exists('Cris'), false);
net.join('Dani');
net.run('Dani','local _,ns=...; ns.Roster.Announce()');
net.advance(65);
assert.equal(exists('Dani'), false);
console.log("ok announcements relay and withdrawal");
for (const player of ['Ana', 'Ben', 'Cris', 'Dani']) {
  net.run(player, `local _,ns=...
    STUB.guildRoles={Ana=1,Ben=2,Cris=4,Dani=4}
    ns.Roster.InvalidateGuildRoster()
    local members={}
    for i,name in ipairs({"Ana","Ben","Cris","Dani"}) do
      members[i]={name=name,role=STUB.guildRoles[name],verifiedRank=i-1,
        rankName=({"Master","Officer","Veteran","Member"})[i],fullName=name.."-Testrealm",online=true}
    end
    ns.Roster.GuildMembers=function() return members end`);
}
net.run('Ben', `local _,ns=...
 local f={id=ns.NameKey("Ana").."9",h="Veteran food",b="Bring food",v=GetServerTime(),r=2,n="Veteran"}
 STUB.Receive("LVLM2",assert(ns.Comm.Encode("gar",f)),"WHISPER","Ana-Testrealm")`);
const restrictedAuthor = who => net.run(who,`local _,ns=...;
 for _,r in ipairs(ns.GuildAnnouncements.List()) do if r.d.h=="Veteran food" then return r.o end end
 return ""`);
assert.equal(restrictedAuthor('Ben'), 'Ana');
net.advance(61);
for (const who of ['Cris','Dani']) net.run(who, 'local _,ns=...; ns.Roster.Announce()');
net.advance(25);
assert.equal(restrictedAuthor('Cris'), 'Ana');
assert.equal(restrictedAuthor('Dani'), '');
console.log('ok restricted announcement relay and rank separation');
net.leave('Cris');
net.join('Ana');
const withdrawalAt = net.run('Ben', 'return GetServerTime()');
net.run('Ana', `local _,ns=...
 local f={id=ns.NameKey("Ana").."9",h="-",b="-",v=${withdrawalAt},r=2,n="Veteran",x=1}
 assert(ns.Comm.Whisper("gar",f,"Ben"))`);
net.advance(5);
assert.equal(restrictedAuthor('Ben'), '');
net.leave('Ana');
net.join('Cris');
net.advance(65);
net.run('Cris','local _,ns=...; ns.Roster.Announce()');
net.advance(25);
assert.equal(restrictedAuthor('Cris'), '');
assert.equal(restrictedAuthor('Dani'), '');
console.log('ok restricted withdrawal reaches an offline recipient via an officer');
