"use client";

import { useState } from "react";
import api from "@/lib/api";

interface SearchResult {
  accounts: Array<{ id: number; service_name: string; email: string; category: string }>;
  breaches: Array<{ id: number; breach_name: string; domain: string; severity: string }>;
  notifications: Array<{ id: number; title: string; message: string; type: string }>;
  audit_logs: Array<{ id: number; action: string; details: string; timestamp: string }>;
}

const sectionIcons: Record<string, string> = {
  accounts: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197",
  breaches: "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z",
  notifications: "M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0",
  audit_logs: "M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25z",
};

const sectionColors: Record<string, string> = {
  accounts: "#23408E",
  breaches: "#C8321A",
  notifications: "#A8660F",
  audit_logs: "#6B3A6E",
};

export default function SearchPage() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  const handleSearch = async (e?: React.FormEvent) => {
    e?.preventDefault();
    if (!query.trim()) return;
    setLoading(true);
    setSearched(true);
    try {
      const res = await api.get(`/search?q=${encodeURIComponent(query.trim())}`);
      setResults(res.data);
    } catch {
      setResults({ accounts: [], breaches: [], notifications: [], audit_logs: [] });
    }
    setLoading(false);
  };

  const totalResults = results
    ? results.accounts.length + results.breaches.length + results.notifications.length + results.audit_logs.length
    : 0;

  return (
    <div className="space-y-6">
      <div>
        <p className="eyebrow mb-3">Assist &middot; 07</p>
        <h1 className="page-title">Global Search</h1>
        <p className="text-[#5B544A] text-sm mt-1">Search across accounts, breaches, notifications, and audit logs</p>
      </div>

      <form onSubmit={handleSearch} className="flex gap-3">
        <div className="flex-1 relative">
          <svg className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-[#8A8274]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search for accounts, breaches, notifications..."
            className="w-full pl-12 pr-4 py-3 bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm text-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-all"
          />
        </div>
        <button
          type="submit"
          disabled={loading || !query.trim()}
          className="px-6 py-3 bg-[#17150F] hover:bg-[#C8321A] disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-sm text-sm font-medium transition-all"
        >
          {loading ? "Searching..." : "Search"}
        </button>
      </form>

      {loading && (
        <div className="flex items-center justify-center h-48">
          <div className="w-10 h-10 border-2 border-[#17150F] border-t-transparent rounded-full animate-spin" />
        </div>
      )}

      {!loading && searched && results && totalResults === 0 && (
        <div className="text-center py-16">
          <svg className="w-16 h-16 text-[#DCD4C4] mx-auto mb-4" fill="none" viewBox="0 0 24 24" strokeWidth={1} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <p className="text-[#8A8274] text-lg">No results found for &quot;{query}&quot;</p>
          <p className="text-[#8A8274] text-sm mt-1">Try different keywords or check your spelling</p>
        </div>
      )}

      {!loading && !searched && (
        <div className="text-center py-16">
          <svg className="w-16 h-16 text-[#DCD4C4] mx-auto mb-4" fill="none" viewBox="0 0 24 24" strokeWidth={1} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <p className="text-[#8A8274] text-lg">Enter a search query to get started</p>
        </div>
      )}

      {!loading && results && totalResults > 0 && (
        <div className="space-y-6">
          <p className="text-sm text-[#5B544A]">{totalResults} result{totalResults !== 1 ? "s" : ""} found</p>

          {results.accounts.length > 0 && (
            <div>
              <div className="flex items-center gap-2 mb-3">
                <svg className="w-5 h-5" style={{ color: sectionColors.accounts }} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.accounts} />
                </svg>
                <h2 className="section-title">Accounts ({results.accounts.length})</h2>
              </div>
              <div className="space-y-2">
                {results.accounts.map((a) => (
                  <div key={a.id} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-4 flex items-center gap-4">
                    <div className="w-10 h-10 rounded-sm bg-[#23408E]/20 flex items-center justify-center">
                      <svg className="w-5 h-5 text-[#23408E]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.accounts} />
                      </svg>
                    </div>
                    <div>
                      <p className="font-medium text-sm">{a.service_name}</p>
                      <p className="text-xs text-[#8A8274]">{a.email} &middot; {a.category}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {results.breaches.length > 0 && (
            <div>
              <div className="flex items-center gap-2 mb-3">
                <svg className="w-5 h-5" style={{ color: sectionColors.breaches }} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.breaches} />
                </svg>
                <h2 className="section-title">Breaches ({results.breaches.length})</h2>
              </div>
              <div className="space-y-2">
                {results.breaches.map((b) => (
                  <div key={b.id} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-4 flex items-center gap-4">
                    <div className="w-10 h-10 rounded-sm bg-[#C8321A]/20 flex items-center justify-center">
                      <svg className="w-5 h-5 text-[#C8321A]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.breaches} />
                      </svg>
                    </div>
                    <div>
                      <p className="font-medium text-sm">{b.breach_name}</p>
                      <p className="text-xs text-[#8A8274]">{b.domain} &middot; <span className={b.severity === "critical" ? "text-[#C8321A]" : b.severity === "high" ? "text-[#A8660F]" : "text-[#23408E]"}>{b.severity}</span></p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {results.notifications.length > 0 && (
            <div>
              <div className="flex items-center gap-2 mb-3">
                <svg className="w-5 h-5" style={{ color: sectionColors.notifications }} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.notifications} />
                </svg>
                <h2 className="section-title">Notifications ({results.notifications.length})</h2>
              </div>
              <div className="space-y-2">
                {results.notifications.map((n) => (
                  <div key={n.id} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-4 flex items-center gap-4">
                    <div className="w-10 h-10 rounded-sm bg-[#A8660F]/20 flex items-center justify-center">
                      <svg className="w-5 h-5 text-[#A8660F]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.notifications} />
                      </svg>
                    </div>
                    <div>
                      <p className="font-medium text-sm">{n.title}</p>
                      <p className="text-xs text-[#8A8274]">{n.message}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {results.audit_logs.length > 0 && (
            <div>
              <div className="flex items-center gap-2 mb-3">
                <svg className="w-5 h-5" style={{ color: sectionColors.audit_logs }} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.audit_logs} />
                </svg>
                <h2 className="section-title">Audit Logs ({results.audit_logs.length})</h2>
              </div>
              <div className="space-y-2">
                {results.audit_logs.map((l) => (
                  <div key={l.id} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-4 flex items-center gap-4">
                    <div className="w-10 h-10 rounded-sm bg-[#6B3A6E]/20 flex items-center justify-center">
                      <svg className="w-5 h-5 text-[#6B3A6E]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" d={sectionIcons.audit_logs} />
                      </svg>
                    </div>
                    <div>
                      <p className="font-medium text-sm">{l.action}</p>
                      <p className="text-xs text-[#8A8274]">{l.details} &middot; {new Date(l.timestamp).toLocaleDateString()}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
