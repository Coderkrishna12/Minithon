"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";

interface Badge {
  type: string;
  title: string;
  description: string;
  eligible: boolean;
  minted: boolean;
}

interface MintedBadge {
  id: number;
  type: string;
  title: string;
  score_at_mint: number;
  tx_hash: string;
  created_at: string;
}

interface LockdownResult {
  status: string;
  accounts_affected: number;
  actions: Array<{ service: string; actions: string[] }>;
  recovery_steps: string[];
}

interface DataBroker {
  name: string;
  domain: string;
  opt_out_url: string;
  data_types: string[];
}

const badgeColors: Record<string, string> = {
  privacy_champion: "#2E6B4E",
  security_pro: "#23408E",
  two_fa_everywhere: "#6B3A6E",
  zero_reuse: "#1F6E78",
  breach_free: "#A8660F",
  first_audit: "#A8436A",
};

export default function BadgesPage() {
  const [badges, setBadges] = useState<Badge[]>([]);
  const [minted, setMinted] = useState<MintedBadge[]>([]);
  const [lockdownResult, setLockdownResult] = useState<LockdownResult | null>(null);
  const [brokers, setBrokers] = useState<DataBroker[]>([]);
  const [activeTab, setActiveTab] = useState<"badges" | "lockdown" | "brokers">("badges");
  const [minting, setMinting] = useState<string | null>(null);

  useEffect(() => {
    api.get("/features/badges").then((r) => {
      setBadges(r.data.available);
      setMinted(r.data.minted);
    }).catch(() => {});
  }, []);

  const mintBadge = async (type: string) => {
    setMinting(type);
    try {
      const res = await api.post(`/features/badges/mint/${type}`);
      setMinted((prev) => [...prev, res.data]);
      setBadges((prev) => prev.map((b) => (b.type === type ? { ...b, minted: true } : b)));
    } catch {}
    setMinting(null);
  };

  const activateLockdown = async () => {
    try {
      const res = await api.post("/features/lockdown");
      setLockdownResult(res.data);
    } catch {}
  };

  const loadBrokers = async () => {
    try {
      const res = await api.get("/features/data-brokers");
      setBrokers(res.data.brokers);
    } catch {}
  };

  return (
    <div className="space-y-6">
      <div>
        <p className="eyebrow mb-3">Record &middot; 12</p>
        <h1 className="page-title">Special Features</h1>
        <p className="text-[#5B544A] text-sm mt-1">NFT badges, emergency lockdown, and data broker removal</p>
      </div>

      <div className="flex gap-2">
        {(["badges", "lockdown", "brokers"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => {
              setActiveTab(tab);
              if (tab === "brokers" && brokers.length === 0) loadBrokers();
            }}
            className={`px-4 py-2 rounded-sm text-sm font-medium transition-all ${
              activeTab === tab ? "bg-[#17150F] text-white" : "bg-[#FBF9F4] text-[#5B544A] border border-[#DCD4C4]"
            }`}
          >
            {tab === "badges" ? "NFT Badges" : tab === "lockdown" ? "Death Switch" : "Data Brokers"}
          </button>
        ))}
      </div>

      {activeTab === "badges" && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {badges.map((badge) => {
              const color = badgeColors[badge.type] || "#5B544A";
              return (
                <div
                  key={badge.type}
                  className={`bg-[#FBF9F4] border rounded-sm p-5 transition-all ${
                    badge.minted ? "border-[#2E6B4E]/30" : badge.eligible ? "border-[#DCD4C4] hover:border-[#B8AE9A]" : "border-[#DCD4C4] opacity-60"
                  }`}
                >
                  <div className="flex items-center gap-3 mb-3">
                    <div className="w-12 h-12 rounded-sm flex items-center justify-center" style={{ backgroundColor: `${color}20` }}>
                      <svg className="w-6 h-6" style={{ color }} fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-4.5A3.375 3.375 0 0012.75 10.5h-1.5A3.375 3.375 0 007.875 13.875v4.875m9 0H7.875" />
                      </svg>
                    </div>
                    <div>
                      <h3 className="font-semibold text-sm">{badge.title}</h3>
                      <p className="text-xs text-[#8A8274]">{badge.description}</p>
                    </div>
                  </div>
                  {badge.minted ? (
                    <div className="flex items-center gap-2 text-[#2E6B4E]">
                      <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clipRule="evenodd" />
                      </svg>
                      <span className="text-xs font-medium">Minted</span>
                    </div>
                  ) : (
                    <button
                      onClick={() => badge.eligible && mintBadge(badge.type)}
                      disabled={!badge.eligible || minting === badge.type}
                      className={`w-full py-2 rounded-sm text-xs font-medium transition-all ${
                        badge.eligible
                          ? "bg-[#17150F] hover:bg-[#C8321A] text-white"
                          : "bg-[#DCD4C4] text-[#8A8274] cursor-not-allowed"
                      }`}
                    >
                      {minting === badge.type ? "Minting..." : badge.eligible ? "Mint NFT" : "Not Eligible"}
                    </button>
                  )}
                </div>
              );
            })}
          </div>

          {minted.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold mb-3">Your Minted Badges</h3>
              <div className="space-y-2">
                {minted.map((b) => (
                  <div key={b.id} className="bg-[#FBF9F4] border border-[#2E6B4E]/20 rounded-sm p-4 flex items-center justify-between">
                    <div>
                      <span className="font-medium text-sm">{b.title}</span>
                      <p className="text-xs text-[#8A8274]">Score at mint: {b.score_at_mint}</p>
                    </div>
                    <code className="text-[10px] text-[#A8660F] font-mono">{b.tx_hash?.slice(0, 16)}...</code>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === "lockdown" && (
        <div className="space-y-6">
          <div className="bg-[#FBF9F4] border border-[#C8321A]/30 rounded-sm p-8 text-center">
            <div className="w-20 h-20 bg-[#C8321A]/20 rounded-sm flex items-center justify-center mx-auto mb-4">
              <svg className="w-10 h-10 text-[#C8321A]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <h2 className="section-title text-[#C8321A] mb-2">Digital Death Switch</h2>
            <p className="text-[#5B544A] text-sm mb-6 max-w-md mx-auto">
              Emergency lockdown for your entire digital life. Triggers session revocations, password resets, and 2FA enforcement across all accounts.
              Use if your phone/laptop is stolen or you suspect a breach.
            </p>
            <button
              onClick={activateLockdown}
              className="px-8 py-3 bg-[#C8321A] hover:bg-[#A12813] text-white font-bold rounded-sm transition-all text-lg"
            >
              ACTIVATE LOCKDOWN
            </button>
          </div>

          {lockdownResult && (
            <div className="bg-[#FBF9F4] border border-[#C8321A]/30 rounded-sm p-6 animate-slide-up">
              <h3 className="text-lg font-semibold text-[#C8321A] mb-4">
                Lockdown Activated — {lockdownResult.accounts_affected} accounts affected
              </h3>
              <div className="space-y-3 mb-6">
                {lockdownResult.actions.slice(0, 5).map((a, i) => (
                  <div key={i} className="bg-[#F2EEE5] rounded-sm p-3">
                    <span className="font-medium text-sm">{a.service}</span>
                    <div className="flex flex-wrap gap-1 mt-1">
                      {a.actions.map((act, j) => (
                        <span key={j} className="text-[10px] px-2 py-0.5 rounded bg-[#C8321A]/10 text-[#C8321A]">{act}</span>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
              <div>
                <h4 className="text-sm font-medium text-[#5B544A] mb-2">Recovery Steps</h4>
                <div className="space-y-1">
                  {lockdownResult.recovery_steps.map((step, i) => (
                    <p key={i} className="text-sm text-[#5B544A]">{step}</p>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === "brokers" && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <p className="text-sm text-[#5B544A]">Data brokers that may hold your personal information</p>
            <button
              onClick={() => api.post("/features/data-brokers/opt-out-all").catch(() => {})}
              className="px-5 py-2 bg-[#17150F] hover:bg-[#C8321A] text-white rounded-sm text-sm font-medium transition-all"
            >
              Opt-Out All
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {brokers.map((broker) => (
              <div key={broker.name} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium">{broker.name}</span>
                  <span className="text-xs text-[#8A8274]">{broker.domain}</span>
                </div>
                <div className="flex flex-wrap gap-1 mb-3">
                  {broker.data_types.map((d) => (
                    <span key={d} className="text-[10px] px-1.5 py-0.5 rounded bg-[#C8321A]/10 text-[#C8321A]">{d}</span>
                  ))}
                </div>
                <a
                  href={broker.opt_out_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-xs text-[#23408E] hover:underline"
                >
                  Opt-out link &rarr;
                </a>
              </div>
            ))}
          </div>
          {brokers.length === 0 && <p className="text-center text-[#8A8274] py-12">Loading data brokers...</p>}
        </div>
      )}
    </div>
  );
}
