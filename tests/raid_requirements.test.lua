STUB.Fire("ADDON_LOADED", "LevelMates")
local _, ns = ...
STUB.guildMembers = { Tester=true, Ana=true, Ben=true }
STUB.guildRoles = { Tester=2, Ana=4, Ben=4 }
STUB.Fire("PLAYER_ENTERING_WORLD", true, false); STUB.Advance(30)
ns.Roster.InvalidateGuildRoster()
UnitClass = function() return "Rogue", "ROGUE", 4 end
local P, RR = ns.RaidRequirements, ns.RaidReadiness
assert(P.Set("guild",101,"ALL","100:5,200:2"))
assert(P.Set("guild",101,"ROGUE","100:10"))
assert(P.Set("guild",101,"MAGE","999:8"))
assert(P.Set("guild",101,"D","300:3"))
assert(not P.Set("guild",101,"ROGUE","100:1,100:2"))
assert(P.Get("guild",101,"ROGUE").d.i=="100:10", "invalid replacement is atomic")
assert(RR.SetItems(101,"100:7,400:4"))
C_Item.GetItemCount=function() return 8 end
local s=RR.Snapshot(101)
assert(#s.sources==2 and s.role==nil, "no role profile from a class guess")
assert(#s.items==3 and s.items[1].required==10 and #s.items[1].origins==3)
assert(s.items[1].status=="missing" and not RR.Text(101):find("#999",1,true))
ns.Roles.Set("D"); s=RR.Snapshot(101)
assert(#s.sources==3 and #s.items==4)
-- Officer minimums survive a smaller personal requirement or clearing reminders.
assert(RR.SetItems(101,"100:1")); assert(RR.Snapshot(101).items[1].required==10)
assert(RR.SetItems(101,"clear")); assert(RR.Snapshot(101).items[1].required==10)
-- The native roster, not a claimed string/rank, selects the current leader's extra requirements.
IsInRaid=function() return true end
GetNumGroupMembers=function() return 2 end
UnitIsGroupLeader=function(unit) return unit=="raid1" end
local realName=UnitName
UnitName=function(unit) if unit=="raid1" then return "Tester" elseif unit=="raid2" then return "Ana" end; return realName(unit) end
assert(P.CanPublish("raid") and P.Set("raid",101,"ROGUE","100:15,500:2"))
s=RR.Snapshot(101)
assert(s.leader=="Tester" and s.items[1].required==15 and #s.sources==4)
-- Leadership loss deactivates the previous leader's profiles immediately.
UnitName=function(unit) if unit=="raid1" then return "Ana" elseif unit=="raid2" then return "Tester" end; return realName(unit) end
assert(not P.CanPublish("raid") and not P.Set("raid",101,"ROGUE","100:99"))
assert(RR.Snapshot(101).items[1].required==10)
STUB.guildRoles.Tester=4; ns.Roster.InvalidateGuildRoster()
assert(not P.CanPublish("guild") and not P.Set("guild",101,"ALL","100:99"))
assert(#RR.Snapshot(101).sources==0, "demoted authors no longer supply an officer policy")
-- Protected/throwing leader APIs cannot grant publication rights.
IsInRaid=function() error("restricted") end; assert(not P.CanPublish("raid"))
local secret={}; issecretvalue=function(v) return v==secret end
IsInRaid=function() return secret end; assert(P.Leader()==nil)
issecretvalue=nil
-- Members can read central profiles in the editor but cannot save them.
RR.OpenConfig(101)
local f=RR.config
assert(f.frame:IsShown())
f.box:SetText("600:4"); f.save.scripts.OnClick(f.save)
assert(RR.PersonalItems(101)[1].id==600)
local entries
MenuUtil.CreateContextMenu=function(_,fn)
 entries={}; fn(nil,{CreateButton=function(_,label,cb) entries[label]=cb end})
end
f.mode.scripts.OnClick(f.mode); entries[ns.L.READY_MODE_GUILD]()
assert(not f.save:IsEnabled())
STUB.guildRoles.Tester=2; ns.Roster.InvalidateGuildRoster()
RR.OpenConfig(101); assert(f.save:IsEnabled())
f.scopeButton.scripts.OnClick(f.scopeButton); entries[P.ScopeLabel("ROGUE")]()
f.box:SetText("700:6"); f.save.scripts.OnClick(f.save)
assert(P.Get("guild",101,"ROGUE").d.i=="700:6")
local opened; ns.DiscordCopy.OpenText=function(text) opened=text end
f.report.scripts.OnClick(f.report); assert(opened:find("#700",1,true))
SlashCmdList.LEVELMATES("raidready guild 101 ALL 800:4")
assert(P.Get("guild",101,"ALL").d.i=="800:4")
SlashCmdList.LEVELMATES("raidready config 103"); assert(f.id==103)
-- Class/API unknowns do not silently select the wrong class or throw from a report.
UnitClass=function() error("class unavailable") end
assert(RR.Snapshot(101).class==nil and RR.Text(101):find(ns.L.READY_CLASS_UNKNOWN,1,true))
UnitClass=function() return "Rogue","ROGUE",4 end
-- Leader profiles expire independently of guild minima and private reminders.
IsInRaid=function() return true end
UnitName=function(unit) if unit=="raid1" then return "Tester" elseif unit=="raid2" then return "Ana" end; return realName(unit) end
assert(P.Get("raid",101,"ROGUE"))
P.Get("raid",101,"ROGUE").e=GetServerTime()-1
assert(not P.Get("raid",101,"ROGUE"))
-- Equal-revision tombstones win for opted-in mutable requirement profiles; replay cannot revive them.
STUB.guildRoles.Ana=2; ns.Roster.InvalidateGuildRoster()
local rev=GetServerTime()+10
local fields={id="g103.ALL",a=103,s="ALL",i="900:2",v=rev,e=GetServerTime()+1000}
STUB.Receive("LVLM2",ns.Comm.Encode("rpg",fields),"GUILD","Ana-Testrealm")
assert(P.Get("guild",103,"ALL"))
STUB.Receive("LVLM2",ns.Comm.Encode("x",{t="rpg",id="g103.ALL",v=rev,e=GetServerTime()+1000}),"GUILD","Ana-Testrealm")
assert(not P.Get("guild",103,"ALL"))
STUB.Receive("LVLM2",ns.Comm.Encode("rpg",fields),"GUILD","Ana-Testrealm")
assert(not P.Get("guild",103,"ALL"))
