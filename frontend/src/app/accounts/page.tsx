"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";

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
    setForm({
      service_name: "",
      service_url: "",
      email_used: "",
      category: "social",
      has_2fa: false,
      password_group: "",
      login_method: "password",
      permissions: [],
    });
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

  const getRiskColor = (score: number) => {
    if (score >= 75) return "#E54D2E";
    if (score >= 50) return "#D97706";
    if (score >= 25) return "#D4D6DC";
    return "#3E9B66";
  };

  const filtered = filter ? accounts.filter((a) => a.category === filter) : accounts;

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-[#222429] gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#3E9B66]" />
            <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
              NODE REPOSITORY // IDENTITY ASSETS
            </span>
          </div>
          <h1 className="text-2xl font-bold font-display tracking-tight text-[#F4F4F6] mt-1">
            Accounts & Identity Vault
          </h1>
          <p className="text-xs text-[#A1A3AA] mt-0.5">
            {accounts.length} monitored identity nodes tracked across web and mobile services.
          </p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="monolith-btn-primary text-xs"
        >
          {showForm ? "DISMISS FORM" : "+ ENROLL ACCOUNT"}
        </button>
      </div>

      {/* Account Ingestion Form */}
      {showForm && (
        <form onSubmit={addAccount} className="monolith-card p-6 space-y-4 animate-slide-up">
          <div className="flex items-center justify-between pb-3 border-b border-[#222429]">
            <span className="text-xs font-bold tracking-widest text-[#F4F4F6] uppercase font-display">
              ENROLL NEW IDENTITY NODE
            </span>
            <span className="text-[10px] font-mono text-[#6B6E78]">ENCLAVE ENCRYPTION: ACTIVE</span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
                SERVICE NAME *
              </label>
              <input
                value={form.service_name}
                onChange={(e) => setForm((f) => ({ ...f, service_name: e.target.value }))}
                className="w-full px-3.5 py-2 text-xs"
                placeholder="e.g. GitHub, ProtonMail, AWS"
                required
              />
            </div>
            <div>
              <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
                EMAIL OR IDENTIFIER USED
              </label>
              <input
                value={form.email_used}
                onChange={(e) => setForm((f) => ({ ...f, email_used: e.target.value }))}
                className="w-full px-3.5 py-2 text-xs"
                placeholder="identity@example.com"
              />
            </div>
            <div>
              <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
                CATEGORY
              </label>
              <select
                value={form.category}
                onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
                className="w-full px-3.5 py-2 text-xs"
              >
                {categories.map((c) => (
                  <option key={c} value={c}>{c.toUpperCase()}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
                AUTHENTICATION METHOD
              </label>
              <select
                value={form.login_method}
                onChange={(e) => setForm((f) => ({ ...f, login_method: e.target.value }))}
                className="w-full px-3.5 py-2 text-xs"
              >
                <option value="password">Master Password</option>
                <option value="google_sso">Google SSO</option>
                <option value="apple_sso">Apple SSO</option>
                <option value="github_sso">GitHub SSO</option>
              </select>
            </div>
            <div>
              <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
                PASSWORD GROUP (REUSE CLUSTER)
              </label>
              <input
                value={form.password_group}
                onChange={(e) => setForm((f) => ({ ...f, password_group: e.target.value }))}
                className="w-full px-3.5 py-2 text-xs"
                placeholder="e.g. cluster-1 if shared"
              />
            </div>
            <div className="flex items-center gap-3 pt-6">
              <input
                type="checkbox"
                checked={form.has_2fa}
                onChange={(e) => setForm((f) => ({ ...f, has_2fa: e.target.checked }))}
                className="w-4 h-4 rounded accent-[#F4F4F6]"
                id="2fa_check"
              />
              <label htmlFor="2fa_check" className="text-xs font-mono text-[#F4F4F6] cursor-pointer">
                HARDWARE 2FA / TOTP ENABLED
              </label>
            </div>
          </div>

          <div>
            <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-2 font-display">
              PERMISSIONS GRANTED TO APPLICATION
            </label>
            <div className="flex flex-wrap gap-2">
              {["location", "contacts", "camera", "microphone", "storage", "photos", "notifications", "calendar"].map((p) => {
                const active = form.permissions.includes(p);
                return (
                  <button
                    key={p}
                    type="button"
                    onClick={() => togglePermission(p)}
                    className={`px-2.5 py-1 rounded text-[11px] font-mono tracking-wider uppercase transition-all ${
                      active
                        ? "bg-[#F4F4F6] text-[#0B0C0E] font-bold"
                        : "bg-[#0B0C0E] text-[#A1A3AA] border border-[#222429] hover:border-[#383B43]"
                    }`}
                  >
                    {p}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="pt-2">
            <button type="submit" className="monolith-btn-primary text-xs">
              COMMIT NODE TO VAULT
            </button>
          </div>
        </form>
      )}

      {/* Category Filter Pills */}
      <div className="flex items-center gap-1.5 flex-wrap">
        <button
          onClick={() => setFilter("")}
          className={`px-3 py-1 rounded text-xs font-mono uppercase transition-all ${
            !filter
              ? "bg-[#18191E] text-[#F4F4F6] border border-[#2B2E36]"
              : "text-[#6B6E78] hover:text-[#A1A3AA] border border-transparent"
          }`}
        >
          ALL ({accounts.length})
        </button>
        {categories.map((c) => {
          const count = accounts.filter((a) => a.category === c).length;
          return (
            <button
              key={c}
              onClick={() => setFilter(c)}
              className={`px-3 py-1 rounded text-xs font-mono uppercase transition-all ${
                filter === c
                  ? "bg-[#18191E] text-[#F4F4F6] border border-[#2B2E36]"
                  : "text-[#6B6E78] hover:text-[#A1A3AA] border border-transparent"
              }`}
            >
              {c} ({count})
            </button>
          );
        })}
      </div>

      {/* Accounts Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map((account) => {
          const riskColor = getRiskColor(account.risk_score);
          return (
            <div key={account.id} className="monolith-card p-5 flex flex-col justify-between group">
              <div>
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="font-bold text-sm font-display text-[#F4F4F6] group-hover:text-white">
                      {account.service_name}
                    </h3>
                    <p className="text-[10px] font-mono text-[#6B6E78] uppercase mt-0.5">
                      CATEGORY: {account.category}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className="text-[10px] font-mono px-2 py-0.5 rounded border font-bold"
                      style={{
                        backgroundColor: `${riskColor}10`,
                        borderColor: `${riskColor}30`,
                        color: riskColor,
                      }}
                    >
                      {account.risk_score.toFixed(0)} PTS
                    </span>
                    <button
                      onClick={() => deleteAccount(account.id)}
                      className="opacity-0 group-hover:opacity-100 text-[#6B6E78] hover:text-[#E54D2E] transition-all p-1"
                      title="De-register account"
                    >
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                </div>

                {account.email_used && (
                  <p className="text-xs font-mono text-[#A1A3AA] mb-3 truncate bg-[#0B0C0E] px-2 py-1 rounded border border-[#222429]">
                    {account.email_used}
                  </p>
                )}

                <div className="flex flex-wrap gap-1.5 mb-3 text-[10px] font-mono">
                  <span
                    className={`px-2 py-0.5 rounded border ${
                      account.has_2fa
                        ? "bg-[#3E9B66]/10 text-[#3E9B66] border-[#3E9B66]/20"
                        : "bg-[#E54D2E]/10 text-[#E54D2E] border-[#E54D2E]/20"
                    }`}
                  >
                    {account.has_2fa ? "2FA VERIFIED" : "NO 2FA"}
                  </span>
                  <span className="px-2 py-0.5 rounded bg-[#0B0C0E] border border-[#222429] text-[#A1A3AA] uppercase">
                    {account.login_method.replace(/_/g, " ")}
                  </span>
                  {account.password_group && (
                    <span className="px-2 py-0.5 rounded bg-[#D97706]/10 border border-[#D97706]/20 text-[#D97706]">
                      REUSE: {account.password_group}
                    </span>
                  )}
                </div>

                {account.permissions.length > 0 && (
                  <div className="flex flex-wrap gap-1">
                    {account.permissions.map((p) => (
                      <span key={p} className="text-[9px] font-mono px-1.5 py-0.5 rounded bg-[#0B0C0E] text-[#6B6E78] uppercase">
                        {p}
                      </span>
                    ))}
                  </div>
                )}
              </div>

              {account.breach_count > 0 && (
                <div className="mt-4 pt-3 border-t border-[#1C1E24] text-[11px] font-mono text-[#E54D2E] flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#E54D2E]" />
                  <span>
                    MATCHED IN {account.breach_count} LEAK{account.breach_count > 1 ? "S" : ""}
                  </span>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {filtered.length === 0 && !loading && (
        <div className="text-center py-20 border border-dashed border-[#222429] rounded p-8">
          <p className="text-xs font-mono text-[#6B6E78]">
            {filter ? "No registered nodes match this category filter." : "Vault is empty. Click '+ Enroll Account' to begin monitoring."}
          </p>
        </div>
      )}
    </div>
  );
}
