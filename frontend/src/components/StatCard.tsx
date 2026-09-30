"use client";

interface StatCardProps {
  label: string;
  value: string | number;
  icon?: string;
  color: string;
  subtitle?: string;
}

export default function StatCard({ label, value, color, subtitle }: StatCardProps) {
  return (
    <div className="bg-card border border-rule rounded-sm px-5 pt-4 pb-5">
      <div className="flex items-center gap-2">
        <span className="w-2 h-2" style={{ backgroundColor: color }} />
        <p className="eyebrow">{label}</p>
      </div>
      <p className="num text-[2.8rem] leading-none mt-4">{value}</p>
      {subtitle && <p className="text-xs text-ink-3 mt-2">{subtitle}</p>}
    </div>
  );
}
