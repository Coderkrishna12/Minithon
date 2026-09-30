"use client";

import { useEffect, useState } from "react";

interface ScoreRingProps {
  score: number;
  size?: number;
  strokeWidth?: number;
}

export default function ScoreRing({ score, size = 180, strokeWidth = 12 }: ScoreRingProps) {
  const [offset, setOffset] = useState(283);
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;

  useEffect(() => {
    const timer = setTimeout(() => {
      setOffset(circumference - (score / 100) * circumference);
    }, 300);
    return () => clearTimeout(timer);
  }, [score, circumference]);

  const getColor = () => {
    if (score >= 80) return "#10B981";
    if (score >= 60) return "#3B82F6";
    if (score >= 40) return "#F59E0B";
    return "#EF4444";
  };

  return (
    <div className="relative flex items-center justify-center">
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="#334155"
          strokeWidth={strokeWidth}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={getColor()}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          strokeLinecap="round"
          className="transition-all duration-1000 ease-in-out"
          style={{ filter: `drop-shadow(0 0 8px ${getColor()}40)` }}
        />
      </svg>
      <div className="absolute flex flex-col items-center">
        <span className="text-4xl font-bold" style={{ color: getColor() }}>
          {score}
        </span>
        <span className="text-xs text-[#94A3B8] uppercase tracking-wider">Privacy Score</span>
      </div>
    </div>
  );
}
