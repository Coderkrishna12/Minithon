"use client";

import { useEffect, useState } from "react";

interface ScoreRingProps {
  score: number;
  size?: number;
  strokeWidth?: number;
}

function verdict(score: number) {
  if (score >= 80) return { color: "#2E6B4E", word: "Well kept" };
  if (score >= 60) return { color: "#23408E", word: "Fair" };
  if (score >= 40) return { color: "#A8660F", word: "Exposed" };
  return { color: "#C8321A", word: "At risk" };
}

export default function ScoreRing({ score, size = 190, strokeWidth = 5 }: ScoreRingProps) {
  const radius = (size - strokeWidth) / 2 - 8;
  const circumference = 2 * Math.PI * radius;
  const [offset, setOffset] = useState(circumference);
  const { color, word } = verdict(score);

  useEffect(() => {
    const timer = setTimeout(() => setOffset(circumference - (score / 100) * circumference), 300);
    return () => clearTimeout(timer);
  }, [score, circumference]);

  const ticks = Array.from({ length: 40 }, (_, i) => i);

  return (
    <div className="relative flex items-center justify-center">
      <svg width={size} height={size} className="-rotate-90">
        {ticks.map((i) => {
          const a = (i / ticks.length) * 2 * Math.PI;
          const r1 = size / 2 - 2;
          const r2 = size / 2 - (i % 5 === 0 ? 8 : 5);
          return (
            <line
              key={i}
              x1={size / 2 + r1 * Math.cos(a)}
              y1={size / 2 + r1 * Math.sin(a)}
              x2={size / 2 + r2 * Math.cos(a)}
              y2={size / 2 + r2 * Math.sin(a)}
              stroke="#B8AE9A"
              strokeWidth={1}
            />
          );
        })}
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="#DCD4C4" strokeWidth={strokeWidth} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          className="transition-[stroke-dashoffset] duration-1000 ease-out"
        />
      </svg>
      <div className="absolute flex flex-col items-center">
        <span className="num text-[3.6rem] leading-none" style={{ color }}>
          {score}
        </span>
        <span className="eyebrow mt-2">{word}</span>
      </div>
    </div>
  );
}
