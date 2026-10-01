"use client";

interface StatCardProps {
  label: string;
  value: string | number;
  icon: string | React.ReactNode;
  color?: string;
  subtitle?: string;
}

export default function StatCard({
  label,
  value,
  icon,
  color = "#D4D6DC",
  subtitle,
}: StatCardProps) {
  return (
    <div className="bg-[#131417] border border-[#222429] rounded-lg p-5 hover:border-[#383B43] transition-all flex flex-col justify-between group">
      <div className="flex items-start justify-between">
        <div>
          <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
            {label}
          </span>
          <div className="text-2xl font-bold font-display tracking-tight text-[#F4F4F6] mt-1 group-hover:text-white transition-colors">
            {value}
          </div>
        </div>
        <div
          className="w-8 h-8 rounded border flex items-center justify-center text-xs font-mono"
          style={{
            backgroundColor: `${color}10`,
            borderColor: `${color}25`,
            color: color,
          }}
        >
          {icon}
        </div>
      </div>
      {subtitle && (
        <div className="mt-3 pt-2.5 border-t border-[#1C1E24] text-[11px] font-mono text-[#6B6E78] flex items-center gap-1.5">
          <span className="w-1 h-1 rounded-full" style={{ backgroundColor: color }} />
          <span>{subtitle}</span>
        </div>
      )}
    </div>
  );
}
