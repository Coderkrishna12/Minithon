"use client";

import { useCallback, useEffect, useState } from "react";
import api from "@/lib/api";

type Role = "owner" | "guardian" | "member";
type ShareLevel = "summary" | "detailed";

interface Group {
  id: number;
  name: string;
  group_type: string;
  member_count: number;
  my_role: Role;
  my_share_level: ShareLevel;
  is_owner: boolean;
  invite_code: string | null;
}

interface Issue {
  service: string;
  risk: number;
  reasons: string[];
}

interface Member {
  user_id: number;
  display_name: string;
  role: Role;
  share_level: ShareLevel;
  is_me: boolean;
  privacy_score: number;
  risk_level: string;
  total_accounts: number;
  accounts_at_risk: number;
  without_2fa: number;
  breached_accounts: number;
  reused_password_groups: number;
  darkweb_exposures: number;
  pending_fixes: number;
  completed_fixes: number;
  has_scanned: boolean;
  top_issues: Issue[];
}

interface Recommendation {
  priority: number;
  member_user_id: number | null;
  topic: string;
  title: string;
  detail: string;
}

interface Dashboard {
  group: Group;
  summary: {
    average_score: number;
    member_count: number;
    accounts_at_risk: number;
    breached_accounts: number;
    accounts_without_2fa: number;
    darkweb_exposures: number;
    members_needing_help: number;
    members_not_tracking: number;
    weakest_member: string | null;
  };
  members: Member[];
  recommendations: Recommendation[];
  shared_risks: Array<{ service: string; members: string[]; breached: boolean; advice: string }>;
  activity: Array<{ at: string; kind: "breach" | "fix"; text: string }>;
  nudge_topics: Array<{ id: string; title: string }>;
}

const input =
  "w-full px-4 py-2.5 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-all";
const primary =
  "px-4 py-2.5 bg-[#17150F] hover:bg-[#C8321A] disabled:opacity-50 text-white rounded-sm text-sm font-medium transition-all";
const secondary =
  "px-3 py-1.5 border border-[#DCD4C4] hover:border-[#17150F] rounded-sm text-xs font-medium text-[#17150F] transition-all";
const card = "bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-5";

function errorText(e: unknown): string {
  const detail = (e as { response?: { data?: { detail?: unknown } } })?.response?.data?.detail;
  return typeof detail === "string" ? detail : "Something went wrong. Try again.";
}

function scoreColor(score: number) {
  if (score >= 80) return "#2E6B4E";
  if (score >= 60) return "#23408E";
  if (score >= 40) return "#A8660F";
  return "#C8321A";
}

const riskColor: Record<string, string> = { critical: "#C8321A", high: "#A8660F", medium: "#23408E", low: "#2E6B4E" };

function ShareChoice({ value, onChange }: { value: ShareLevel; onChange: (v: ShareLevel) => void }) {
  return (
    <div>
      <div className="inline-flex border border-[#DCD4C4] rounded-sm overflow-hidden">
        {(["summary", "detailed"] as ShareLevel[]).map((v) => (
          <button
            key={v}
            type="button"
            onClick={() => onChange(v)}
            className={`px-4 py-1.5 text-sm capitalize ${value === v ? "bg-[#17150F] text-white" : "bg-[#F2EEE5] text-[#5B544A]"}`}
          >
            {v}
          </button>
        ))}
      </div>
      <p className="text-xs text-[#8A8274] mt-1.5">
        {value === "summary"
          ? "Your score and counts only. Account names stay private."
          : "Also which accounts are at risk and why, so guardians can help with specifics."}
      </p>
    </div>
  );
}

export default function FamilyPage() {
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [createName, setCreateName] = useState("");
  const [createType, setCreateType] = useState("family");
  const [joinCode, setJoinCode] = useState("");
  const [joinShare, setJoinShare] = useState<ShareLevel>("summary");
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<number | null>(null);
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [openMember, setOpenMember] = useState<number | null>(null);
  const [nudge, setNudge] = useState<{ member: Member; topic: string; note: string } | null>(null);

  const flash = (text: string, error = false) => setMessage({ text, error });

  const loadGroups = useCallback(async () => {
    try {
      const res = await api.get<Group[]>("/family/groups");
      setGroups(res.data);
      return res.data;
    } catch (e) {
      flash(errorText(e), true);
      return [];
    } finally {
      setLoading(false);
    }
  }, []);

  const loadDashboard = useCallback(async (groupId: number) => {
    try {
      const res = await api.get<Dashboard>(`/family/dashboard/${groupId}`);
      setDashboard(res.data);
    } catch (e) {
      setDashboard(null);
      flash(errorText(e), true);
    }
  }, []);

  const openGroup = useCallback(
    (groupId: number) => {
      setSelected(groupId);
      return loadDashboard(groupId);
    },
    [loadDashboard],
  );

  useEffect(() => {
    api
      .get<Group[]>("/family/groups")
      .then((res) => {
        setGroups(res.data);
        if (res.data.length) openGroup(res.data[0].id);
      })
      .catch((e) => flash(errorText(e), true))
      .finally(() => setLoading(false));
  }, [openGroup]);

  const run = async (action: () => Promise<unknown>, success?: string) => {
    setBusy(true);
    try {
      await action();
      if (success) flash(success);
      await loadGroups();
      if (selected !== null) await loadDashboard(selected);
    } catch (e) {
      flash(errorText(e), true);
    } finally {
      setBusy(false);
    }
  };

  const createGroup = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!createName.trim()) return;
    setBusy(true);
    try {
      const res = await api.post<Group>("/family/groups", { name: createName.trim(), group_type: createType });
      setCreateName("");
      await loadGroups();
      await openGroup(res.data.id);
      flash(`Created ${res.data.name}. Share invite code ${res.data.invite_code} with your family.`);
    } catch (err) {
      flash(errorText(err), true);
    } finally {
      setBusy(false);
    }
  };

  const joinGroup = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!joinCode.trim()) return;
    setBusy(true);
    try {
      const res = await api.post("/family/join", { invite_code: joinCode.trim(), share_level: joinShare });
      setJoinCode("");
      await loadGroups();
      await openGroup(res.data.group.id);
      flash(`You joined ${res.data.group_name}.`);
    } catch (err) {
      flash(errorText(err), true);
    } finally {
      setBusy(false);
    }
  };

  const copyInvite = async (g: Group) => {
    const text = `Join my PrivacyShield group "${g.name}". Open Family Shield → Join, and enter code: ${g.invite_code}`;
    try {
      await navigator.clipboard.writeText(text);
      flash("Invite copied. Paste it into any chat.");
    } catch {
      flash(`Invite code: ${g.invite_code}`);
    }
  };

  const leave = (g: Group) => {
    const note = g.is_owner
      ? "Ownership passes to a guardian or the longest-standing member. If you're alone, the group is deleted."
      : "The group will no longer see your privacy snapshot.";
    if (!confirm(`Leave ${g.name}? ${note}`)) return;
    run(async () => {
      await api.post(`/family/groups/${g.id}/leave`);
      setSelected(null);
      setDashboard(null);
    }, `You left ${g.name}.`);
  };

  const deleteGroup = (g: Group) => {
    if (!confirm(`Delete ${g.name}? Everyone is removed and the invite code stops working.`)) return;
    run(async () => {
      await api.delete(`/family/groups/${g.id}`);
      setSelected(null);
      setDashboard(null);
    }, `Deleted ${g.name}.`);
  };

  const sendNudge = () => {
    if (!nudge || !dashboard) return;
    const { member, topic, note } = nudge;
    run(
      () =>
        api.post(`/family/groups/${dashboard.group.id}/nudge`, {
          member_user_id: member.user_id,
          topic,
          ...(note.trim() ? { message: note.trim() } : {}),
        }),
      `Nudge sent to ${member.display_name}.`,
    ).then(() => setNudge(null));
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#17150F] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const g = dashboard?.group;
  const canManage = g?.my_role === "owner" || g?.my_role === "guardian";
  const byId = new Map(dashboard?.members.map((m) => [m.user_id, m]) ?? []);

  return (
    <div className="space-y-6">
      <div>
        <p className="eyebrow mb-3">Assist &middot; 08</p>
        <h1 className="page-title">Family Shield</h1>
        <p className="text-[#5B544A] text-sm mt-1">
          Keep each other safe online. Everyone keeps their own account; the group sees scores, who needs help, and risks you share.
        </p>
      </div>

      {message && (
        <div
          className={`flex items-start justify-between gap-4 px-4 py-3 rounded-sm text-sm border ${
            message.error ? "bg-[#C8321A]/10 border-[#C8321A]/40 text-[#C8321A]" : "bg-[#2E6B4E]/10 border-[#2E6B4E]/40 text-[#2E6B4E]"
          }`}
        >
          <span>{message.text}</span>
          <button onClick={() => setMessage(null)} aria-label="Dismiss" className="opacity-70 hover:opacity-100">
            ✕
          </button>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <form onSubmit={createGroup} className={`${card} space-y-3`}>
          <h2 className="section-title">Create a group</h2>
          <input value={createName} onChange={(e) => setCreateName(e.target.value)} placeholder="Group name, e.g. The Sharmas" className={input} />
          <select value={createType} onChange={(e) => setCreateType(e.target.value)} className={input}>
            <option value="family">Family</option>
            <option value="friends">Friends</option>
            <option value="team">Team</option>
            <option value="organization">Organization</option>
          </select>
          <button type="submit" disabled={busy || !createName.trim()} className={`${primary} w-full`}>
            Create group
          </button>
        </form>

        <form onSubmit={joinGroup} className={`${card} space-y-3`}>
          <h2 className="section-title">Join with a code</h2>
          <input
            value={joinCode}
            onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
            placeholder="8-character invite code"
            className={`${input} tracking-[0.3em] font-mono`}
          />
          <ShareChoice value={joinShare} onChange={setJoinShare} />
          <button type="submit" disabled={busy || !joinCode.trim()} className={`${primary} w-full`}>
            Join group
          </button>
        </form>
      </div>

      {groups.length === 0 ? (
        <div className="text-center py-12 text-[#8A8274]">
          <p className="text-lg">No groups yet</p>
          <p className="text-sm mt-1">Create one and share its invite code, or join with a code someone sent you.</p>
        </div>
      ) : (
        <div className="flex flex-wrap gap-2">
          {groups.map((grp) => (
            <button
              key={grp.id}
              onClick={() => openGroup(grp.id)}
              className={`px-4 py-2 rounded-sm text-sm border transition-all ${
                selected === grp.id ? "bg-[#17150F] text-white border-[#17150F]" : "bg-[#FBF9F4] border-[#DCD4C4] hover:border-[#17150F]"
              }`}
            >
              {grp.name} <span className="opacity-60">· {grp.member_count} · {grp.my_role}</span>
            </button>
          ))}
        </div>
      )}

      {dashboard && g && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
            <div className={`${card} lg:col-span-2`}>
              <div className="flex flex-wrap items-end justify-between gap-4">
                <div>
                  <p className="text-xs text-[#8A8274]">Family privacy score</p>
                  <p className="text-5xl font-bold" style={{ color: scoreColor(dashboard.summary.average_score) }}>
                    {dashboard.summary.members_not_tracking === dashboard.summary.member_count ? "–" : dashboard.summary.average_score}
                  </p>
                  {dashboard.summary.members_not_tracking > 0 && (
                    <p className="text-xs text-[#A8660F]">{dashboard.summary.members_not_tracking} member(s) have no accounts tracked yet</p>
                  )}
                  <p className="text-sm text-[#5B544A] mt-1">
                    {dashboard.summary.members_needing_help > 0
                      ? `${dashboard.summary.members_needing_help} of ${dashboard.summary.member_count} need help${
                          dashboard.summary.weakest_member ? ` · lowest: ${dashboard.summary.weakest_member}` : ""
                        }`
                      : "Everyone is in good shape"}
                  </p>
                </div>
                <div className="grid grid-cols-4 gap-4 text-center">
                  {[
                    [dashboard.summary.accounts_at_risk, "at risk", "#A8660F"],
                    [dashboard.summary.breached_accounts, "breached", "#C8321A"],
                    [dashboard.summary.accounts_without_2fa, "no 2FA", "#6B3A6E"],
                    [dashboard.summary.darkweb_exposures, "dark web", "#C8321A"],
                  ].map(([v, label, color]) => (
                    <div key={label as string}>
                      <p className="text-2xl font-bold" style={{ color: color as string }}>{v}</p>
                      <p className="text-[11px] text-[#8A8274]">{label}</p>
                    </div>
                  ))}
                </div>
              </div>
              <div className="mt-5 pt-4 border-t border-[#DCD4C4] flex flex-wrap items-start justify-between gap-4">
                <div>
                  <p className="text-sm font-medium mb-2">What the group sees about you</p>
                  <ShareChoice
                    value={g.my_share_level}
                    onChange={(v) => run(() => api.patch(`/family/groups/${g.id}/sharing`, { share_level: v }), "Sharing updated.")}
                  />
                </div>
                <div className="flex gap-2">
                  <button onClick={() => leave(g)} className={secondary} disabled={busy}>Leave group</button>
                  {g.is_owner && (
                    <button onClick={() => deleteGroup(g)} className={`${secondary} text-[#C8321A]`} disabled={busy}>
                      Delete group
                    </button>
                  )}
                </div>
              </div>
            </div>

            <div className={`${card} bg-[#23408E]/5`}>
              <p className="text-sm font-medium">Invite code</p>
              {g.invite_code ? (
                <>
                  <p className="text-3xl font-mono font-bold tracking-[0.3em] text-[#23408E] my-3 select-all">{g.invite_code}</p>
                  <p className="text-xs text-[#5B544A] mb-3">Family members join from Family Shield → Join with a code.</p>
                  <div className="flex flex-wrap gap-2">
                    <button onClick={() => copyInvite(g)} className={secondary}>Copy invite</button>
                    <button
                      onClick={() =>
                        confirm("Make a new code? The current one stops working; existing members stay.") &&
                        run(() => api.post(`/family/groups/${g.id}/invite-code`), "New invite code ready.")
                      }
                      className={secondary}
                      disabled={busy}
                    >
                      New code
                    </button>
                  </div>
                </>
              ) : (
                <p className="text-sm text-[#5B544A] mt-2">Ask the owner or a guardian for the invite code.</p>
              )}
            </div>
          </div>

          <section>
            <h2 className="section-title mb-3">What to do next</h2>
            {dashboard.recommendations.length === 0 ? (
              <p className="text-sm text-[#8A8274]">No open actions. Nice work, everyone.</p>
            ) : (
              <div className="space-y-2">
                {dashboard.recommendations.map((r, i) => {
                  const target = r.member_user_id !== null ? byId.get(r.member_user_id) : undefined;
                  return (
                    <div key={i} className={`${card} !p-4 flex items-start gap-3`}>
                      <span className="mt-0.5 text-xs font-bold" style={{ color: r.priority === 1 ? "#C8321A" : "#A8660F" }}>
                        {r.priority === 1 ? "URGENT" : "NEXT"}
                      </span>
                      <div className="flex-1">
                        <p className="text-sm font-medium">{r.title}</p>
                        <p className="text-xs text-[#5B544A]">{r.detail}</p>
                      </div>
                      {canManage && target && !target.is_me && (
                        <button onClick={() => setNudge({ member: target, topic: r.topic, note: "" })} className={secondary}>
                          Nudge
                        </button>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </section>

          <section>
            <h2 className="section-title mb-3">Members</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {dashboard.members.map((m) => (
                <div key={m.user_id} className={card}>
                  <button className="w-full text-left" onClick={() => setOpenMember(openMember === m.user_id ? null : m.user_id)}>
                    <div className="flex items-center gap-3">
                      <div
                        className="w-10 h-10 rounded-full flex items-center justify-center font-bold"
                        style={{ background: `${scoreColor(m.privacy_score)}22`, color: scoreColor(m.privacy_score) }}
                      >
                        {m.display_name[0]?.toUpperCase()}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate">{m.display_name}{m.is_me && " (you)"}</p>
                        <p className="text-xs text-[#8A8274]">
                          {m.role} · shares {m.share_level} · {m.total_accounts} accounts
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-2xl font-bold" style={{ color: scoreColor(m.privacy_score) }}>{m.privacy_score}</p>
                        <p className="text-[10px] uppercase" style={{ color: m.has_scanned ? riskColor[m.risk_level] : "#8A8274" }}>
                          {m.has_scanned ? `${m.risk_level} risk` : "no data yet"}
                        </p>
                      </div>
                    </div>
                  </button>
                  {openMember === m.user_id && (
                    <div className="mt-4 pt-4 border-t border-[#DCD4C4] space-y-3">
                      <div className="grid grid-cols-3 gap-2 text-center text-xs">
                        {[
                          [m.accounts_at_risk, "at risk"],
                          [m.breached_accounts, "breached"],
                          [m.without_2fa, "no 2FA"],
                          [m.reused_password_groups, "reused pw"],
                          [m.darkweb_exposures, "dark web"],
                          [`${m.completed_fixes}/${m.completed_fixes + m.pending_fixes}`, "fixes done"],
                        ].map(([v, label]) => (
                          <div key={label as string} className="bg-[#F2EEE5] rounded-sm py-2">
                            <p className="text-base font-bold">{v}</p>
                            <p className="text-[#8A8274]">{label}</p>
                          </div>
                        ))}
                      </div>
                      {m.top_issues.length > 0 ? (
                        <ul className="space-y-1.5">
                          {m.top_issues.map((issue) => (
                            <li key={issue.service} className="text-xs flex justify-between gap-2">
                              <span><b>{issue.service}</b> · {issue.reasons.join(" · ")}</span>
                              <span className="text-[#8A8274] shrink-0">risk {issue.risk}</span>
                            </li>
                          ))}
                        </ul>
                      ) : (
                        <p className="text-xs text-[#8A8274]">
                          {m.share_level === "summary" && !m.is_me
                            ? `${m.display_name} shares a summary only, so account names stay private.`
                            : "Nothing risky found yet."}
                        </p>
                      )}
                      {!m.is_me && (
                        <div className="flex flex-wrap gap-2">
                          {canManage && (
                            <button onClick={() => setNudge({ member: m, topic: dashboard.nudge_topics[0].id, note: "" })} className={secondary}>
                              Send nudge
                            </button>
                          )}
                          {g.is_owner && m.role !== "owner" && (
                            <>
                              <button
                                className={secondary}
                                disabled={busy}
                                onClick={() =>
                                  run(
                                    () => api.patch(`/family/groups/${g.id}/members/${m.user_id}`, { role: m.role === "guardian" ? "member" : "guardian" }),
                                    `${m.display_name} role updated.`,
                                  )
                                }
                              >
                                {m.role === "guardian" ? "Make member" : "Make guardian"}
                              </button>
                              <button
                                className={`${secondary} text-[#C8321A]`}
                                disabled={busy}
                                onClick={() =>
                                  confirm(`Remove ${m.display_name} from ${g.name}?`) &&
                                  run(() => api.delete(`/family/groups/${g.id}/members/${m.user_id}`), `${m.display_name} removed.`)
                                }
                              >
                                Remove
                              </button>
                            </>
                          )}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </section>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <section className={card}>
              <h2 className="section-title mb-3">Risks you share</h2>
              {dashboard.shared_risks.length === 0 ? (
                <p className="text-sm text-[#8A8274]">No services used by more than one member yet. Members sharing &ldquo;Detailed&rdquo; are compared.</p>
              ) : (
                <ul className="space-y-3">
                  {dashboard.shared_risks.map((r) => (
                    <li key={r.service}>
                      <p className="text-sm font-medium" style={{ color: r.breached ? "#C8321A" : undefined }}>
                        {r.service} · {r.members.join(", ")}
                      </p>
                      <p className="text-xs text-[#5B544A]">{r.advice}</p>
                    </li>
                  ))}
                </ul>
              )}
            </section>
            <section className={card}>
              <h2 className="section-title mb-3">Recent activity</h2>
              {dashboard.activity.length === 0 ? (
                <p className="text-sm text-[#8A8274]">No breaches or completed fixes in the last 30 days.</p>
              ) : (
                <ul className="space-y-2">
                  {dashboard.activity.map((a, i) => (
                    <li key={i} className="text-sm flex justify-between gap-3">
                      <span style={{ color: a.kind === "breach" ? "#C8321A" : "#2E6B4E" }}>{a.text}</span>
                      <span className="text-xs text-[#8A8274] shrink-0">{new Date(a.at).toLocaleDateString()}</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </div>
        </div>
      )}

      {nudge && dashboard && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center p-4 z-50" onClick={() => setNudge(null)}>
          <div className={`${card} w-full max-w-md space-y-3`} onClick={(e) => e.stopPropagation()}>
            <h3 className="section-title">Nudge {nudge.member.display_name}</h3>
            <p className="text-xs text-[#5B544A]">They get a notification in PrivacyShield.</p>
            <select value={nudge.topic} onChange={(e) => setNudge({ ...nudge, topic: e.target.value })} className={input}>
              {dashboard.nudge_topics.map((t) => (
                <option key={t.id} value={t.id}>{t.title}</option>
              ))}
            </select>
            <textarea
              value={nudge.note}
              maxLength={500}
              onChange={(e) => setNudge({ ...nudge, note: e.target.value })}
              placeholder={nudge.topic === "custom" ? "Message" : "Add a personal note (optional)"}
              className={input}
              rows={3}
            />
            <div className="flex justify-end gap-2">
              <button onClick={() => setNudge(null)} className={secondary}>Cancel</button>
              <button onClick={sendNudge} disabled={busy} className={primary}>Send nudge</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
