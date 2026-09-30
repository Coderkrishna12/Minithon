"use client";

interface StatCardProps {
  label: string;
  value: string | number;
  icon: string;
  color: string;
  subtitle?: string;
}

export default function StatCard({ label, value, icon, color, subtitle }: StatCardProps) {
  return (
    <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-5 hover:border-[#475569] transition-all">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm text-[#94A3B8]">{label}</p>
          <p className="text-3xl font-bold mt-1" style={{ color }}>{value}</p>
          {subtitle && <p className="text-xs text-[#64748B] mt-1">{subtitle}</p>}
        </div>
        <div
          className="w-10 h-10 rounded-xl flex items-center justify-center text-lg"
          style={{ backgroundColor: `${color}20`, color }}
        >
          {icon}
        </div>
      </div>
    </div>
  );
}
