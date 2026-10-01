"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Chip, Empty, Headline, Row, SectionTitle, Spinner, StatGrid, StatTile, riskTone } from "@/components/editorial";

interface Account {
  id: number;
  service_name: string;
  service_url: string | null;
  email_used: string | null;
  category: string | null;
  has_2fa: boolean;
  password_group: string | null;
  login_method: string;
  permissions: string[];
  risk_score: number;
  breach_count: number;
}

const categories = ["social", "finance", "email", "cloud", "shopping", "gaming", "productivity", "other"];

export default function AccountsPage() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("");
  const [form, setForm] = useState({
    service_name: "",
    service_url: "",
    email_used: "",
    category: "social",
    has_2fa: false,
    password_group: "",
    login_method: "password",
    permissions: [] as string[],
  });

  useEffect(() => {
    api.get("/accounts/").then((r) => setAccounts(r.data)).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const addAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    const res = await api.post("/accounts/", form);
    setAccounts((prev) => [res.data, ...prev]);
    setShowForm(false);
    setForm({ service_name: "", service_url: "", email_used: "", category: "social", has_2fa: false, password_group: "", login_method: "password", permissions: [] });
  };

  const deleteAccount = async (id: number) => {
    await api.delete(`/accounts/${id}`);
    setAccounts((prev) => prev.filter((a) => a.id !== id));
  };

  const togglePermission = (perm: string) => {
    setForm((f) => ({
      ...f,
      permissions: f.permissions.includes(perm)
        ? f.permissions.filter((p) => p !== perm)
        : [...f.permissions, perm],
    }));
  };

  const groupSize = (a: Account) => (a.password_group ? accounts.filter((o) => o.password_group === a.password_group).length : 0);

  const issues: Record<string, { label: string; test: (a: Account) => boolean }> = {
    no2fa: { label: "No 2FA", test: (a) => !a.has_2fa },
    reused: { label: "Reused password", test: (a) => groupSize(a) > 1 },
    sso: { label: "Signs in with SSO", test: (a) => a.login_method.endsWith("_sso") },
    breached: { label: "Breached", test: (a) => a.breach_count > 0 },
    permissions: { label: "3+ permissions", test: (a) => a.permissions.length >= 3 },
  };

  const worstIssue = (a: Account): { text: string; warn: boolean } | null => {
    if (a.breach_count > 0) return { text: `Found in ${a.breach_count} breach${a.breach_count > 1 ? "es" : ""}.`, warn: true };
    const shared = accounts.filter((o) => o.id !== a.id && a.password_group && o.password_group === a.password_group);
    if (shared.length) return { text: `Shares a password with ${shared.map((o) => o.service_name).join(", ")}.`, warn: true };
    if (!a.has_2fa) return { text: "No second factor: a leaked password is enough to get in.", warn: false };
    return null;
  };

  const filtered = accounts
    .filter((a) => (!filter ? true : filter in issues ? issues[filter].test(a) : a.category === filter))
    .sort((a, b) => b.risk_score - a.risk_score);

  const no2fa = accounts.filter(issues.no2fa.test).length;
  const head =
    accounts.length === 0
      ? { lead: "No accounts yet.", rest: "Add the services you use to see how they connect." }
      : no2fa === 0
        ? { lead: "Every account", rest: "has two-factor authentication." }
        : { lead: `${no2fa} of your ${accounts.length} accounts`, rest: "have no two-factor authentication." };

  if (loading) return <Spinner />;

  return (
    <div className="space-y-12">
      <div className="flex items-start justify-between gap-6">
        <Headline eyebrow="Audit · 02 · Accounts" lead={head.lead} rest={head.rest} sub={`${accounts.length} accounts on file`} />
        <button
          onClick={() => setShowForm(!showForm)}
          className="shrink-0 mt-8 px-5 py-2.5 bg-ink hover:bg-signal text-card rounded-sm text-sm font-medium transition-colors"
        >
          {showForm ? "Cancel" : "Add account"}
        </button>
      </div>

      <StatGrid cols={5}>
        {Object.entries(issues).map(([key, issue]) => {
          const count = accounts.filter(issue.test).length;
          return (
            <StatTile
              key={key}
              value={count}
              label={issue.label}
              dim={!count}
              active={filter === key}
              onClick={() => setFilter(filter === key ? "" : key)}
            />
          );
        })}
      </StatGrid>

      {showForm && (
        <form onSubmit={addAccount} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6 space-y-4 animate-slide-up">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-[#5B544A] mb-1">Service Name *</label>
              <input
                value={form.service_name}
                onChange={(e) => setForm((f) => ({ ...f, service_name: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] text-sm focus:outline-none focus:border-[#17150F]"
                placeholder="e.g. Gmail, Instagram, Netflix"
                required
              />
            </div>
            <div>
              <label className="block text-sm text-[#5B544A] mb-1">Email Used</label>
              <input
                value={form.email_used}
                onChange={(e) => setForm((f) => ({ ...f, email_used: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] text-sm focus:outline-none focus:border-[#17150F]"
                placeholder="email@example.com"
              />
            </div>
            <div>
              <label className="block text-sm text-[#5B544A] mb-1">Category</label>
              <select
                value={form.category}
                onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] text-sm focus:outline-none focus:border-[#17150F]"
              >
                {categories.map((c) => (
                  <option key={c} value={c}>{c.charAt(0).toUpperCase() + c.slice(1)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm text-[#5B544A] mb-1">Login Method</label>
              <select
                value={form.login_method}
                onChange={(e) => setForm((f) => ({ ...f, login_method: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] text-sm focus:outline-none focus:border-[#17150F]"
              >
                <option value="password">Password</option>
                <option value="google_sso">Google SSO</option>
                <option value="apple_sso">Apple SSO</option>
                <option value="facebook_sso">Facebook SSO</option>
                <option value="github_sso">GitHub SSO</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-[#5B544A] mb-1">Password Group Label</label>
              <input
                value={form.password_group}
                onChange={(e) => setForm((f) => ({ ...f, password_group: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] text-sm focus:outline-none focus:border-[#17150F]"
                placeholder="e.g. 'group-a' if reused"
              />
            </div>
            <div className="flex items-center gap-3 pt-6">
              <input
                type="checkbox"
                checked={form.has_2fa}
                onChange={(e) => setForm((f) => ({ ...f, has_2fa: e.target.checked }))}
                className="w-4 h-4 rounded"
              />
              <label className="text-sm text-[#5B544A]">Has 2FA Enabled</label>
            </div>
          </div>

          <div>
            <label className="block text-sm text-[#5B544A] mb-2">Permissions Granted</label>
            <div className="flex flex-wrap gap-2">
              {["location", "contacts", "camera", "microphone", "storage", "photos", "notifications", "calendar"].map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => togglePermission(p)}
                  className={`px-3 py-1.5 rounded-sm text-xs font-medium transition-all ${
                    form.permissions.includes(p)
                      ? "bg-[#17150F] text-white"
                      : "bg-[#F2EEE5] text-[#5B544A] border border-[#DCD4C4] hover:border-[#6B3A6E]"
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          <button type="submit" className="px-6 py-2.5 bg-[#17150F] hover:bg-[#C8321A] text-white rounded-sm text-sm font-medium transition-all">
            Save Account
          </button>
        </form>
      )}

      <section>
        <SectionTitle
          title={filter && filter in issues ? issues[filter].label : filter ? `${filter.charAt(0).toUpperCase()}${filter.slice(1)} accounts` : "Accounts by risk"}
          meta={`${filtered.length} shown`}
          action={
            <select
              value={filter in issues ? "" : filter}
              onChange={(e) => setFilter(e.target.value)}
              className="bg-transparent text-sm text-ink-2 border-b border-rule-strong focus:outline-none focus:border-ink"
              aria-label="Filter by category"
            >
              <option value="">All categories</option>
              {categories.map((c) => (
                <option key={c} value={c}>{c.charAt(0).toUpperCase() + c.slice(1)}</option>
              ))}
            </select>
          }
        />
        {filtered.map((account) => {
          const issue = worstIssue(account);
          return (
            <Row
              key={account.id}
              lead={<span className={`num text-3xl ${riskTone(account.risk_score)}`}>{account.risk_score.toFixed(0)}</span>}
              title={account.service_name}
              meta={[account.category, account.email_used].filter(Boolean).join(" · ")}
              chips={
                <>
                  <Chip tone={account.has_2fa ? "ok" : "warn"}>{account.has_2fa ? "2FA on" : "No 2FA"}</Chip>
                  <Chip>Login {account.login_method.replace(/_/g, " ")}</Chip>
                  {account.password_group && (
                    <Chip tone={groupSize(account) > 1 ? "warn" : "default"}>
                      {groupSize(account) > 1 ? "Reused password" : "Password group"} {account.password_group}
                    </Chip>
                  )}
                  {account.permissions.map((p) => (
                    <Chip key={p} tone="muted">{p}</Chip>
                  ))}
                </>
              }
              note={issue?.text}
              noteTone={issue?.warn ? "warn" : "default"}
              aside={
                <button
                  onClick={() => deleteAccount(account.id)}
                  className="text-sm text-ink-3 opacity-0 group-hover:opacity-100 hover:text-signal transition-opacity"
                >
                  Remove
                </button>
              }
            />
          );
        })}
        {filtered.length === 0 && <Empty>{filter ? "No accounts match this filter." : "No accounts yet. Use Add account to start."}</Empty>}
      </section>
    </div>
  );
}
