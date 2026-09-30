"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";

interface AuditEntry {
  id: number;
  action: string;
  details: string;
  data_hash: string;
  blockchain_tx_hash: string;
  blockchain_block: number;
  created_at: string;
}

interface Block {
  index: number;
  timestamp: string;
  data: unknown;
  previous_hash: string;
  hash: string;
}

interface ZKPCertificate {
  verified: boolean;
  proof: { commitment: string; challenge: string; response: string; proof_hash: string };
  claim: string;
  timestamp: string;
}

export default function BlockchainPage() {
  const [auditLog, setAuditLog] = useState<AuditEntry[]>([]);
  const [chain, setChain] = useState<{ chain: Block[]; length: number; valid: boolean } | null>(null);
  const [zkp, setZkp] = useState<ZKPCertificate | null>(null);
  const [zkpThreshold, setZkpThreshold] = useState(70);
  const [activeTab, setActiveTab] = useState<"audit" | "chain" | "zkp">("audit");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      api.get("/blockchain/audit-log"),
      api.get("/blockchain/chain"),
    ]).then(([auditRes, chainRes]) => {
      setAuditLog(auditRes.data);
      setChain(chainRes.data);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const generateZKP = async () => {
    try {
      const res = await api.post(`/blockchain/zkp-certificate?threshold=${zkpThreshold}`);
      setZkp(res.data);
    } catch {}
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#F59E0B] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Blockchain Audit Trail</h1>
        <p className="text-[#94A3B8] text-sm mt-1">Immutable, tamper-proof record of every privacy action</p>
      </div>

      {chain && (
        <div className="flex gap-4">
          <div className="bg-[#1E293B] border border-[#334155] rounded-xl px-4 py-3 flex items-center gap-3">
            <div className={`w-3 h-3 rounded-full ${chain.valid ? "bg-[#10B981]" : "bg-[#EF4444]"}`} />
            <span className="text-sm">Chain: {chain.valid ? "Valid" : "Invalid"}</span>
          </div>
          <div className="bg-[#1E293B] border border-[#334155] rounded-xl px-4 py-3">
            <span className="text-sm text-[#94A3B8]">Blocks: <span className="text-white font-medium">{chain.length}</span></span>
          </div>
        </div>
      )}

      <div className="flex gap-2">
        {(["audit", "chain", "zkp"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
              activeTab === tab ? "bg-[#F59E0B] text-black" : "bg-[#1E293B] text-[#94A3B8] border border-[#334155]"
            }`}
          >
            {tab === "audit" ? "Audit Log" : tab === "chain" ? "Block Explorer" : "ZKP Certificate"}
          </button>
        ))}
      </div>

      {activeTab === "audit" && (
        <div className="space-y-3">
          {auditLog.map((entry) => (
            <div key={entry.id} className="bg-[#1E293B] border border-[#334155] rounded-xl p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="font-medium text-sm">{entry.action.replace(/_/g, " ").toUpperCase()}</span>
                <span className="text-xs text-[#64748B]">Block #{entry.blockchain_block}</span>
              </div>
              {entry.details && <p className="text-sm text-[#94A3B8] mb-2">{entry.details}</p>}
              <div className="flex flex-col gap-1">
                <div className="flex items-center gap-2">
                  <span className="text-[10px] text-[#64748B] w-12">Hash:</span>
                  <code className="text-[10px] text-[#F59E0B] font-mono truncate">{entry.data_hash}</code>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[10px] text-[#64748B] w-12">TX:</span>
                  <code className="text-[10px] text-[#06B6D4] font-mono truncate">{entry.blockchain_tx_hash}</code>
                </div>
              </div>
              {entry.created_at && (
                <p className="text-[10px] text-[#64748B] mt-2">{new Date(entry.created_at).toLocaleString()}</p>
              )}
            </div>
          ))}
          {auditLog.length === 0 && <p className="text-center text-[#64748B] py-12">No audit entries yet. Actions are recorded as you use the platform.</p>}
        </div>
      )}

      {activeTab === "chain" && chain && (
        <div className="space-y-3">
          {chain.chain.slice().reverse().map((block) => (
            <div key={block.index} className="bg-[#1E293B] border border-[#334155] rounded-xl p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="font-medium">Block #{block.index}</span>
                <span className="text-xs text-[#64748B]">{new Date(block.timestamp).toLocaleString()}</span>
              </div>
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <span className="text-[10px] text-[#64748B] w-16">Hash:</span>
                  <code className="text-[10px] text-[#10B981] font-mono truncate">{block.hash}</code>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[10px] text-[#64748B] w-16">Prev Hash:</span>
                  <code className="text-[10px] text-[#8B5CF6] font-mono truncate">{block.previous_hash}</code>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {activeTab === "zkp" && (
        <div className="space-y-6">
          <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6">
            <h2 className="text-lg font-semibold mb-2">Zero-Knowledge Proof Certificate</h2>
            <p className="text-sm text-[#94A3B8] mb-6">
              Prove your privacy score meets a threshold WITHOUT revealing your actual score or account details.
              Share with insurers, employers, or platforms for trust verification.
            </p>
            <div className="flex items-center gap-4 mb-6">
              <label className="text-sm text-[#94A3B8]">Threshold:</label>
              <input
                type="range"
                min={0}
                max={100}
                value={zkpThreshold}
                onChange={(e) => setZkpThreshold(Number(e.target.value))}
                className="flex-1"
              />
              <span className="text-lg font-bold text-[#F59E0B] w-12 text-right">{zkpThreshold}</span>
            </div>
            <button
              onClick={generateZKP}
              className="px-6 py-3 bg-[#F59E0B] hover:bg-[#D97706] text-black font-medium rounded-xl transition-all"
            >
              Generate ZKP Certificate
            </button>
          </div>

          {zkp && (
            <div className={`border rounded-2xl p-6 animate-slide-up ${
              zkp.verified
                ? "bg-[#10B981]/5 border-[#10B981]/30"
                : "bg-[#EF4444]/5 border-[#EF4444]/30"
            }`}>
              <div className="flex items-center gap-3 mb-4">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                  zkp.verified ? "bg-[#10B981]/20" : "bg-[#EF4444]/20"
                }`}>
                  {zkp.verified ? (
                    <svg className="w-5 h-5 text-[#10B981]" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                    </svg>
                  ) : (
                    <svg className="w-5 h-5 text-[#EF4444]" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  )}
                </div>
                <div>
                  <p className={`font-semibold ${zkp.verified ? "text-[#10B981]" : "text-[#EF4444]"}`}>
                    {zkp.verified ? "VERIFIED" : "NOT MET"}
                  </p>
                  <p className="text-sm text-[#94A3B8]">{zkp.claim}</p>
                </div>
              </div>
              <div className="space-y-2 bg-[#0F172A] rounded-xl p-4">
                <p className="text-xs text-[#64748B]">Cryptographic Proof:</p>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <span className="text-[10px] text-[#64748B]">Commitment</span>
                    <code className="block text-[10px] text-[#8B5CF6] font-mono truncate">{zkp.proof.commitment}</code>
                  </div>
                  <div>
                    <span className="text-[10px] text-[#64748B]">Challenge</span>
                    <code className="block text-[10px] text-[#06B6D4] font-mono">{zkp.proof.challenge}</code>
                  </div>
                  <div>
                    <span className="text-[10px] text-[#64748B]">Response</span>
                    <code className="block text-[10px] text-[#10B981] font-mono">{zkp.proof.response}</code>
                  </div>
                  <div>
                    <span className="text-[10px] text-[#64748B]">Proof Hash</span>
                    <code className="block text-[10px] text-[#F59E0B] font-mono truncate">{zkp.proof.proof_hash}</code>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
