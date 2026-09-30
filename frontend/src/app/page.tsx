"use client";

import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-[#0F172A] -ml-64 px-6">
      <div className="text-center max-w-3xl animate-slide-up">
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-[#3B82F6]/10 border border-[#3B82F6]/20 text-[#3B82F6] text-sm mb-8">
          <span className="w-2 h-2 rounded-full bg-[#3B82F6] animate-pulse" />
          AI-Powered &middot; Blockchain-Verified
        </div>

        <h1 className="text-5xl md:text-7xl font-bold mb-6">
          <span className="bg-gradient-to-r from-[#3B82F6] via-[#8B5CF6] to-[#EC4899] bg-clip-text text-transparent">
            PrivacyShield
          </span>
        </h1>

        <p className="text-xl text-[#94A3B8] mb-4">
          Digital Footprint &amp; Privacy Risk Auditor
        </p>

        <p className="text-[#64748B] max-w-xl mx-auto mb-10 leading-relaxed">
          Map your entire digital identity. See how accounts connect.
          Discover which breach could unlock everything.
          AI finds the risks. You fix them. Blockchain proves it.
        </p>

        <div className="flex gap-4 justify-center">
          <Link
            href="/register"
            className="px-8 py-3 bg-[#3B82F6] hover:bg-[#2563EB] text-white rounded-xl font-medium transition-all hover:shadow-lg hover:shadow-[#3B82F6]/25"
          >
            Get Started
          </Link>
          <Link
            href="/login"
            className="px-8 py-3 border border-[#334155] hover:border-[#3B82F6] text-[#94A3B8] hover:text-white rounded-xl font-medium transition-all"
          >
            Sign In
          </Link>
        </div>

        <div className="mt-20 grid grid-cols-1 md:grid-cols-3 gap-6">
          {[
            { title: "Account Graph", desc: "Visualize how all your accounts interconnect through SSO, recovery emails, and shared passwords", color: "#3B82F6" },
            { title: "AI Risk Engine", desc: "Graph Neural Networks model cascading risk — one weak account can expose your entire network", color: "#8B5CF6" },
            { title: "Blockchain Proof", desc: "Every audit and fix is hashed on-chain. Prove your security posture with zero-knowledge proofs", color: "#10B981" },
          ].map((f) => (
            <div key={f.title} className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6 text-left hover:border-[#475569] transition-all">
              <div className="w-10 h-10 rounded-xl mb-4 flex items-center justify-center" style={{ backgroundColor: `${f.color}20` }}>
                <div className="w-3 h-3 rounded-full" style={{ backgroundColor: f.color }} />
              </div>
              <h3 className="font-semibold mb-2">{f.title}</h3>
              <p className="text-sm text-[#94A3B8] leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
