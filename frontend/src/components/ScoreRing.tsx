"use client";

import { useEffect, useState } from "react";

interface ScoreRingProps {
  score: number;
  size?: number;
  strokeWidth?: number;
}

export default function ScoreRing({ score, size = 190, strokeWidth = 8 }: ScoreRingProps) {
  const [animatedScore, setAnimatedScore] = useState(0);
  const radius = (size - strokeWidth * 2) / 2;
  const circumference = 2 * Math.PI * radius;

  useEffect(() => {
    const timer = setTimeout(() => {
      setAnimatedScore(score);
    }, 200);
    return () => clearTimeout(timer);
  }, [score]);

  const offset = circumference - (animatedScore / 100) * circumference;

  const getStatus = () => {
    if (score >= 80) return { label: "HARDENED", color: "#3E9B66", bg: "rgba(62,155,102,0.12)" };
    if (score >= 60) return { label: "MONITORED", color: "#D4D6DC", bg: "rgba(212,214,220,0.12)" };
    if (score >= 40) return { label: "ELEVATED RISK", color: "#D97706", bg: "rgba(217,119,6,0.12)" };
    return { label: "CRITICAL EXPOSURE", color: "#E54D2E", bg: "rgba(229,77,46,0.12)" };
  };

  const status = getStatus();
  const ticksCount = 40;

  return (
    <div className="relative flex flex-col items-center justify-center p-3">
      {/* Precision Circular Gauge */}
      <div className="relative flex items-center justify-center">
        <svg width={size} height={size} className="-rotate-90">
          {/* Outer subtle calibrated tick ring */}
          {Array.from({ length: ticksCount }).map((_, i) => {
            const angle = (i * 360) / ticksCount;
            const rad = (angle * Math.PI) / 180;
            const r1 = size / 2 - 2;
            const r2 = size / 2 - (i % 5 === 0 ? 8 : 5);
            const x1 = size / 2 + r1 * Math.cos(rad);
            const y1 = size / 2 + r1 * Math.sin(rad);
            const x2 = size / 2 + r2 * Math.cos(rad);
            const y2 = size / 2 + r2 * Math.sin(rad);
            const isActive = (i / ticksCount) * 100 <= animatedScore;

            return (
              <line
                key={i}
                x1={x1}
                y1={y1}
                x2={x2}
                y2={y2}
                stroke={isActive ? status.color : "#222429"}
                strokeWidth={i % 5 === 0 ? 1.5 : 1}
                strokeLinecap="round"
                className="transition-colors duration-700"
              />
            );
          })}

          {/* Background track circle */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius - 8}
            fill="none"
            stroke="#1B1C21"
            strokeWidth={strokeWidth}
          />

          {/* Active Progress Arc */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius - 8}
            fill="none"
            stroke={status.color}
            strokeWidth={strokeWidth}
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            strokeLinecap="butt"
            className="transition-all duration-1000 ease-out"
          />
        </svg>

        {/* Center Readout */}
        <div className="absolute flex flex-col items-center text-center">
          <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase mb-0.5">
            SECURITY INDEX
          </span>
          <span className="text-4xl font-black font-display tracking-tight text-[#F4F4F6]">
            {score}
          </span>
          <span className="text-[10px] font-mono text-[#A1A3AA]">
            / 100 PTS
          </span>
        </div>
      </div>

      {/* Status Pill */}
      <div
        className="mt-3 px-2.5 py-1 rounded border flex items-center gap-1.5"
        style={{ backgroundColor: status.bg, borderColor: `${status.color}30` }}
      >
        <span
          className="w-1.5 h-1.5 rounded-full"
          style={{ backgroundColor: status.color }}
        />
        <span
          className="text-[10px] font-bold tracking-wider font-display"
          style={{ color: status.color }}
        >
          {status.label}
        </span>
      </div>
    </div>
  );
}
