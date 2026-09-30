"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";

interface Member {
  id: number;
  username: string;
  email: string;
  privacy_score: number;
}

interface Group {
  id: number;
  name: string;
  type: string;
  invite_code: string;
  members: Member[];
}

interface Dashboard {
  group_name: string;
  aggregate_score: number;
  member_count: number;
  members: Array<{ username: string; privacy_score: number; risk_level: string }>;
  weakest_areas: string[];
}

export default function FamilyPage() {
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [createName, setCreateName] = useState("");
  const [createType, setCreateType] = useState("family");
  const [creating, setCreating] = useState(false);
  const [joinCode, setJoinCode] = useState("");
  const [joining, setJoining] = useState(false);
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [dashboardGroupId, setDashboardGroupId] = useState<number | null>(null);
  const [dashboardLoading, setDashboardLoading] = useState(false);

  useEffect(() => {
    api.get("/family/groups")
      .then((r) => setGroups(Array.isArray(r.data) ? r.data : r.data.groups || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const createGroup = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!createName.trim()) return;
    setCreating(true);
    try {
      const res = await api.post("/family/groups", { name: createName.trim(), type: createType });
      setGroups((prev) => [...prev, res.data]);
      setCreateName("");
    } catch {}
    setCreating(false);
  };

  const joinGroup = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!joinCode.trim()) return;
    setJoining(true);
    try {
      const res = await api.post("/family/join", { invite_code: joinCode.trim() });
      setGroups((prev) => [...prev, res.data]);
      setJoinCode("");
    } catch {}
    setJoining(false);
  };

  const loadDashboard = async (groupId: number) => {
    setDashboardLoading(true);
    setDashboardGroupId(groupId);
    try {
      const res = await api.get(`/family/dashboard/${groupId}`);
      setDashboard(res.data);
    } catch {
      setDashboard(null);
    }
    setDashboardLoading(false);
  };

  const getScoreColor = (score: number) => {
    if (score >= 80) return "#10B981";
    if (score >= 60) return "#3B82F6";
    if (score >= 40) return "#F59E0B";
    return "#EF4444";
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#3B82F6] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Family Shield</h1>
        <p className="text-[#94A3B8] text-sm mt-1">Manage family and team privacy groups</p>
      </div>

      {/* Create & Join Forms */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-4">Create Group</h2>
          <form onSubmit={createGroup} className="space-y-3">
            <input
              type="text"
              value={createName}
              onChange={(e) => setCreateName(e.target.value)}
              placeholder="Group name"
              className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-sm text-[#F8FAFC] placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-all"
            />
            <select
              value={createType}
              onChange={(e) => setCreateType(e.target.value)}
              className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-sm text-[#F8FAFC] focus:outline-none focus:border-[#3B82F6] transition-all"
            >
              <option value="family">Family</option>
              <option value="team">Team</option>
            </select>
            <button
              type="submit"
              disabled={creating || !createName.trim()}
              className="w-full py-2.5 bg-[#8B5CF6] hover:bg-[#7C3AED] disabled:opacity-50 text-white rounded-xl text-sm font-medium transition-all"
            >
              {creating ? "Creating..." : "Create Group"}
            </button>
          </form>
        </div>

        <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-4">Join Group</h2>
          <form onSubmit={joinGroup} className="space-y-3">
            <input
              type="text"
              value={joinCode}
              onChange={(e) => setJoinCode(e.target.value)}
              placeholder="Enter invite code"
              className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-sm text-[#F8FAFC] placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-all"
            />
            <button
              type="submit"
              disabled={joining || !joinCode.trim()}
              className="w-full py-2.5 bg-[#3B82F6] hover:bg-[#2563EB] disabled:opacity-50 text-white rounded-xl text-sm font-medium transition-all"
            >
              {joining ? "Joining..." : "Join Group"}
            </button>
          </form>
        </div>
      </div>

      {/* Groups List */}
      {groups.length > 0 ? (
        <div className="space-y-4">
          <h2 className="text-lg font-semibold">Your Groups</h2>
          {groups.map((group) => (
            <div key={group.id} className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-lg font-semibold">{group.name}</h3>
                  <div className="flex items-center gap-3 mt-1">
                    <span className="text-xs px-2 py-0.5 rounded-full bg-[#8B5CF6]/20 text-[#8B5CF6] capitalize">{group.type}</span>
                    <span className="text-xs text-[#64748B]">
                      Invite: <code className="text-[#F59E0B] font-mono">{group.invite_code}</code>
                    </span>
                  </div>
                </div>
                <button
                  onClick={() => loadDashboard(group.id)}
                  disabled={dashboardLoading && dashboardGroupId === group.id}
                  className="px-4 py-2 bg-[#3B82F6]/20 hover:bg-[#3B82F6]/30 text-[#3B82F6] rounded-xl text-sm font-medium transition-all"
                >
                  {dashboardLoading && dashboardGroupId === group.id ? "Loading..." : "Dashboard"}
                </button>
              </div>

              {/* Members */}
              {group.members && group.members.length > 0 && (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {group.members.map((member) => (
                    <div key={member.id} className="bg-[#0F172A] rounded-xl p-3 flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-[#334155] flex items-center justify-center text-sm font-bold text-[#94A3B8]">
                        {member.username?.[0]?.toUpperCase() || "?"}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate">{member.username}</p>
                        <p className="text-xs text-[#64748B] truncate">{member.email}</p>
                      </div>
                      <div className="text-right">
                        <span className="text-sm font-bold" style={{ color: getScoreColor(member.privacy_score) }}>
                          {member.privacy_score}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* Dashboard */}
              {dashboard && dashboardGroupId === group.id && (
                <div className="mt-4 pt-4 border-t border-[#334155]">
                  <h4 className="text-sm font-semibold text-[#94A3B8] mb-3">Group Dashboard</h4>
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mb-4">
                    <div className="bg-[#0F172A] rounded-xl p-4">
                      <p className="text-xs text-[#64748B]">Aggregate Score</p>
                      <p className="text-2xl font-bold" style={{ color: getScoreColor(dashboard.aggregate_score) }}>
                        {dashboard.aggregate_score}
                      </p>
                    </div>
                    <div className="bg-[#0F172A] rounded-xl p-4">
                      <p className="text-xs text-[#64748B]">Members</p>
                      <p className="text-2xl font-bold text-[#F8FAFC]">{dashboard.member_count}</p>
                    </div>
                    {dashboard.weakest_areas && dashboard.weakest_areas.length > 0 && (
                      <div className="bg-[#0F172A] rounded-xl p-4 col-span-2 md:col-span-1">
                        <p className="text-xs text-[#64748B] mb-1">Weakest Areas</p>
                        <div className="flex flex-wrap gap-1">
                          {dashboard.weakest_areas.map((area) => (
                            <span key={area} className="text-[10px] px-2 py-0.5 rounded bg-[#EF4444]/10 text-[#EF4444]">{area}</span>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                  {dashboard.members && dashboard.members.length > 0 && (
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
                      {dashboard.members.map((m) => (
                        <div key={m.username} className="bg-[#0F172A] rounded-lg p-3 flex items-center justify-between">
                          <div>
                            <p className="text-sm font-medium">{m.username}</p>
                            <p className="text-[10px] capitalize" style={{ color: m.risk_level === "critical" ? "#EF4444" : m.risk_level === "high" ? "#F59E0B" : "#10B981" }}>
                              {m.risk_level} risk
                            </p>
                          </div>
                          <span className="text-lg font-bold" style={{ color: getScoreColor(m.privacy_score) }}>
                            {m.privacy_score}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      ) : (
        <div className="text-center py-16">
          <svg className="w-16 h-16 text-[#334155] mx-auto mb-4" fill="none" viewBox="0 0 24 24" strokeWidth={1} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
          </svg>
          <p className="text-[#64748B] text-lg">No groups yet</p>
          <p className="text-[#64748B] text-sm mt-1">Create a family or team group, or join one with an invite code</p>
        </div>
      )}
    </div>
  );
}
