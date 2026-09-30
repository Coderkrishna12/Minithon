"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import ScoreRing from "@/components/ScoreRing";
import StatCard from "@/components/StatCard";

interface DashboardData {
  privacy_score: number;
  total_accounts: number;
  accounts_at_risk: number;
  breaches_found: number;
  fixes_completed: number;
  fixes_pending: number;
  risk_distribution: Record<string, number>;
  category_breakdown: Record<string, number>;
  single_points_of_failure: Array<{ id: number; service_name: string; risk_score: number; category: string }>;
}

interface FixAction {
  id: number;
  action_type: string;
  description: string;
  priority: number;
  risk_reduction: number;
  status: string;
}

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [fixes, setFixes] = useState<FixAction[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      api.get("/dashboard/"),
      api.get("/dashboard/fixes"),
    ]).then(([dashRes, fixRes]) => {
      setData(dashRes.data);
      setFixes(fixRes.data);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const completeFix = async (fixId: number) => {
    await api.patch(`/dashboard/fixes/${fixId}/complete`);
    setFixes((prev) => prev.map((f) => (f.id === fixId ? { ...f, status: "completed" } : f)));
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#17150F] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!data) {
    return (
      <div className="text-center py-20">
        <p className="text-[#5B544A]">No data yet. Add some accounts to get started.</p>
      </div>
    );
  }

  const riskColors: Record<string, string> = {
    critical: "#C8321A",
    high: "#A8660F",
    medium: "#23408E",
    low: "#2E6B4E",
  };

  return (
    <div className="space-y-8">
      <div>
        <p className="eyebrow mb-3">Audit &middot; 01</p>
        <h1 className="page-title">Privacy Dashboard</h1>
        <p className="text-[#5B544A] text-sm mt-1">Your digital footprint at a glance</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <div className="lg:col-span-1 bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6 flex flex-col items-center justify-center">
          <p className="eyebrow self-start mb-4">Privacy score</p>
          <ScoreRing score={data.privacy_score} />
        </div>
        <div className="lg:col-span-3 grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard label="Total Accounts" value={data.total_accounts} icon="@" color="#23408E" />
          <StatCard label="At Risk" value={data.accounts_at_risk} icon="!" color="#C8321A" subtitle="Score >= 50" />
          <StatCard label="Breaches Found" value={data.breaches_found} icon="B" color="#A8660F" />
          <StatCard label="Fixes Done" value={data.fixes_completed} icon="Y" color="#2E6B4E" />
          <StatCard label="Fixes Pending" value={data.fixes_pending} icon="?" color="#6B3A6E" />
          <StatCard
            label="Risk Breakdown"
            value={`${data.risk_distribution.critical || 0}C / ${data.risk_distribution.high || 0}H`}
            icon="#"
            color="#A8436A"
            subtitle={`${data.risk_distribution.medium || 0} Medium, ${data.risk_distribution.low || 0} Low`}
          />
        </div>
      </div>

      {data.single_points_of_failure.length > 0 && (
        <div className="bg-[#FBF9F4] border border-[#C8321A]/30 rounded-sm p-6">
          <h2 className="section-title text-[#C8321A] mb-4">Single Points of Failure</h2>
          <p className="text-sm text-[#5B544A] mb-4">
            These accounts connect to 3+ others. If compromised, they could unlock your entire network.
          </p>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            {data.single_points_of_failure.map((a) => (
              <div key={a.id} className="bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm p-4">
                <div className="flex items-center justify-between">
                  <span className="font-medium">{a.service_name}</span>
                  <span
                    className="text-xs px-2 py-1 rounded-full"
                    style={{
                      backgroundColor: `${a.risk_score >= 75 ? "#C8321A" : "#A8660F"}20`,
                      color: a.risk_score >= 75 ? "#C8321A" : "#A8660F",
                    }}
                  >
                    {a.risk_score.toFixed(0)} risk
                  </span>
                </div>
                <p className="text-xs text-[#8A8274] mt-1">{a.category}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6">
          <h2 className="section-title mb-4">Risk Distribution</h2>
          <div className="space-y-3">
            {Object.entries(data.risk_distribution).map(([level, count]) => (
              <div key={level} className="flex items-center gap-3">
                <div className="w-3 h-3 rounded-full" style={{ backgroundColor: riskColors[level] }} />
                <span className="text-sm text-[#5B544A] capitalize w-20">{level}</span>
                <div className="flex-1 bg-[#F2EEE5] rounded-full h-3">
                  <div
                    className="h-3 rounded-full transition-all duration-500"
                    style={{
                      width: `${data.total_accounts ? (count / data.total_accounts) * 100 : 0}%`,
                      backgroundColor: riskColors[level],
                    }}
                  />
                </div>
                <span className="text-sm font-medium w-8 text-right">{count}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6">
          <h2 className="section-title mb-4">Categories</h2>
          <div className="space-y-3">
            {Object.entries(data.category_breakdown).map(([cat, count]) => (
              <div key={cat} className="flex items-center justify-between">
                <span className="text-sm text-[#5B544A] capitalize">{cat}</span>
                <span className="text-sm font-medium bg-[#F2EEE5] px-3 py-1 rounded-sm">{count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6">
        <h2 className="section-title mb-4">Fix Checklist</h2>
        <p className="text-sm text-[#5B544A] mb-4">Ranked by how much overall risk each fix removes</p>
        <div className="space-y-3">
          {fixes.slice(0, 10).map((fix) => (
            <div
              key={fix.id}
              className={`flex items-center gap-4 p-4 rounded-sm border transition-all ${
                fix.status === "completed"
                  ? "bg-[#2E6B4E]/5 border-[#2E6B4E]/20"
                  : "bg-[#F2EEE5] border-[#DCD4C4] hover:border-[#B8AE9A]"
              }`}
            >
              <button
                onClick={() => fix.status !== "completed" && completeFix(fix.id)}
                className={`w-6 h-6 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${
                  fix.status === "completed"
                    ? "bg-[#2E6B4E] border-[#2E6B4E]"
                    : "border-[#B8AE9A] hover:border-[#23408E]"
                }`}
              >
                {fix.status === "completed" && (
                  <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" strokeWidth={3} stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                  </svg>
                )}
              </button>
              <div className="flex-1 min-w-0">
                <p className={`text-sm ${fix.status === "completed" ? "line-through text-[#8A8274]" : ""}`}>
                  {fix.description}
                </p>
                <div className="flex gap-3 mt-1">
                  <span className="text-xs text-[#6B3A6E]">-{fix.risk_reduction.toFixed(0)} risk</span>
                  <span className="text-xs text-[#8A8274]">{fix.action_type.replace(/_/g, " ")}</span>
                </div>
              </div>
              <span
                className="text-xs px-2 py-1 rounded-full"
                style={{
                  backgroundColor: fix.priority >= 80 ? "#C8321A20" : fix.priority >= 50 ? "#A8660F20" : "#23408E20",
                  color: fix.priority >= 80 ? "#C8321A" : fix.priority >= 50 ? "#A8660F" : "#23408E",
                }}
              >
                P{fix.priority}
              </span>
            </div>
          ))}
          {fixes.length === 0 && (
            <p className="text-center text-[#8A8274] py-8">No fixes needed yet. Add accounts to generate recommendations.</p>
          )}
        </div>
      </div>
    </div>
  );
}
