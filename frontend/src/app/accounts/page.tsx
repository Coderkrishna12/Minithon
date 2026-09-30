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

  const getRiskColor = (score: number) => {
    if (score >= 75) return "#EF4444";
    if (score >= 50) return "#F59E0B";
    if (score >= 25) return "#3B82F6";
    return "#10B981";
  };

  const filtered = filter ? accounts.filter((a) => a.category === filter) : accounts;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#3B82F6] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Accounts Inventory</h1>
          <p className="text-[#94A3B8] text-sm mt-1">{accounts.length} accounts tracked</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="px-5 py-2.5 bg-[#3B82F6] hover:bg-[#2563EB] text-white rounded-xl text-sm font-medium transition-all"
        >
          {showForm ? "Cancel" : "+ Add Account"}
        </button>
      </div>

      {showForm && (
        <form onSubmit={addAccount} className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6 space-y-4 animate-slide-up">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-[#94A3B8] mb-1">Service Name *</label>
              <input
                value={form.service_name}
                onChange={(e) => setForm((f) => ({ ...f, service_name: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-white text-sm focus:outline-none focus:border-[#3B82F6]"
                placeholder="e.g. Gmail, Instagram, Netflix"
                required
              />
            </div>
            <div>
              <label className="block text-sm text-[#94A3B8] mb-1">Email Used</label>
              <input
                value={form.email_used}
                onChange={(e) => setForm((f) => ({ ...f, email_used: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-white text-sm focus:outline-none focus:border-[#3B82F6]"
                placeholder="email@example.com"
              />
            </div>
            <div>
              <label className="block text-sm text-[#94A3B8] mb-1">Category</label>
              <select
                value={form.category}
                onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-white text-sm focus:outline-none focus:border-[#3B82F6]"
              >
                {categories.map((c) => (
                  <option key={c} value={c}>{c.charAt(0).toUpperCase() + c.slice(1)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm text-[#94A3B8] mb-1">Login Method</label>
              <select
                value={form.login_method}
                onChange={(e) => setForm((f) => ({ ...f, login_method: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-white text-sm focus:outline-none focus:border-[#3B82F6]"
              >
                <option value="password">Password</option>
                <option value="google_sso">Google SSO</option>
                <option value="apple_sso">Apple SSO</option>
                <option value="facebook_sso">Facebook SSO</option>
                <option value="github_sso">GitHub SSO</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-[#94A3B8] mb-1">Password Group Label</label>
              <input
                value={form.password_group}
                onChange={(e) => setForm((f) => ({ ...f, password_group: e.target.value }))}
                className="w-full px-4 py-2.5 bg-[#0F172A] border border-[#334155] rounded-xl text-white text-sm focus:outline-none focus:border-[#3B82F6]"
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
              <label className="text-sm text-[#94A3B8]">Has 2FA Enabled</label>
            </div>
          </div>

          <div>
            <label className="block text-sm text-[#94A3B8] mb-2">Permissions Granted</label>
            <div className="flex flex-wrap gap-2">
              {["location", "contacts", "camera", "microphone", "storage", "photos", "notifications", "calendar"].map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => togglePermission(p)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                    form.permissions.includes(p)
                      ? "bg-[#8B5CF6] text-white"
                      : "bg-[#0F172A] text-[#94A3B8] border border-[#334155] hover:border-[#8B5CF6]"
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          <button type="submit" className="px-6 py-2.5 bg-[#10B981] hover:bg-[#059669] text-white rounded-xl text-sm font-medium transition-all">
            Save Account
          </button>
        </form>
      )}

      <div className="flex gap-2 flex-wrap">
        <button
          onClick={() => setFilter("")}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
            !filter ? "bg-[#3B82F6] text-white" : "bg-[#1E293B] text-[#94A3B8] border border-[#334155]"
          }`}
        >
          All
        </button>
        {categories.map((c) => (
          <button
            key={c}
            onClick={() => setFilter(c)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all capitalize ${
              filter === c ? "bg-[#3B82F6] text-white" : "bg-[#1E293B] text-[#94A3B8] border border-[#334155]"
            }`}
          >
            {c}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map((account) => (
          <div key={account.id} className="bg-[#1E293B] border border-[#334155] rounded-2xl p-5 hover:border-[#475569] transition-all group">
            <div className="flex items-start justify-between mb-3">
              <div>
                <h3 className="font-semibold">{account.service_name}</h3>
                <p className="text-xs text-[#64748B] capitalize">{account.category}</p>
              </div>
              <div className="flex items-center gap-2">
                <span
                  className="text-xs px-2.5 py-1 rounded-full font-medium"
                  style={{
                    backgroundColor: `${getRiskColor(account.risk_score)}20`,
                    color: getRiskColor(account.risk_score),
                  }}
                >
                  {account.risk_score.toFixed(0)}
                </span>
                <button
                  onClick={() => deleteAccount(account.id)}
                  className="opacity-0 group-hover:opacity-100 text-[#64748B] hover:text-[#EF4444] transition-all"
                >
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                  </svg>
                </button>
              </div>
            </div>

            {account.email_used && (
              <p className="text-xs text-[#94A3B8] mb-2 truncate">{account.email_used}</p>
            )}

            <div className="flex flex-wrap gap-1.5 mb-3">
              <span className={`text-xs px-2 py-0.5 rounded ${account.has_2fa ? "bg-[#10B981]/15 text-[#10B981]" : "bg-[#EF4444]/15 text-[#EF4444]"}`}>
                {account.has_2fa ? "2FA On" : "No 2FA"}
              </span>
              <span className="text-xs px-2 py-0.5 rounded bg-[#8B5CF6]/15 text-[#8B5CF6]">
                {account.login_method.replace(/_/g, " ")}
              </span>
              {account.password_group && (
                <span className="text-xs px-2 py-0.5 rounded bg-[#F59E0B]/15 text-[#F59E0B]">
                  PW: {account.password_group}
                </span>
              )}
            </div>

            {account.permissions.length > 0 && (
              <div className="flex flex-wrap gap-1">
                {account.permissions.map((p) => (
                  <span key={p} className="text-[10px] px-1.5 py-0.5 rounded bg-[#0F172A] text-[#64748B]">{p}</span>
                ))}
              </div>
            )}

            {account.breach_count > 0 && (
              <div className="mt-3 text-xs text-[#EF4444] flex items-center gap-1">
                <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clipRule="evenodd" />
                </svg>
                {account.breach_count} breach{account.breach_count > 1 ? "es" : ""}
              </div>
            )}
          </div>
        ))}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-16">
          <p className="text-[#64748B]">{filter ? "No accounts in this category" : "No accounts yet. Click '+ Add Account' to start."}</p>
        </div>
      )}
    </div>
  );
}
