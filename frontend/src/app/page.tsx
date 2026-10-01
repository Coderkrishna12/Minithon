"use client";

import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen w-full flex flex-col items-center justify-center bg-[#0B0C0E] px-6 py-20 text-[#F4F4F6]">
      <div className="text-center max-w-4xl animate-fade-in">
        {/* Enclave Status Badge */}
        <div className="inline-flex items-center gap-2.5 px-3.5 py-1.5 rounded bg-[#131417] border border-[#222429] mb-8">
          <span className="w-2 h-2 rounded-full bg-[#3E9B66]" />
          <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
            NORDIC SECURITY ENCLAVE // MULTI-LAYER TELEMETRY
          </span>
        </div>

        {/* Primary Monolith Title */}
        <h1 className="text-5xl md:text-7xl font-black font-display tracking-tight text-[#F4F4F6] mb-6 leading-[1.05]">
          PRIVACYSHIELD
        </h1>

        <p className="text-lg md:text-xl font-display text-[#D4D6DC] mb-3 max-w-2xl mx-auto">
          Cryptographic Identity Defense, Attack Cascade Simulator &amp; Physical Airspace Radar
        </p>

        <p className="text-xs md:text-sm font-mono text-[#6B6E78] max-w-xl mx-auto mb-10 leading-relaxed">
          Map interconnected attack surfaces. Calculate blast radiuses before credential stuffing cascades. Audit Android system permissions, anti-theft sentry, and rogue RF airspace.
        </p>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
          <Link
            href="/register"
            className="monolith-btn-primary px-8 py-3 w-full sm:w-auto text-xs"
          >
            INITIALIZE ENCLAVE AUDIT
          </Link>
          <Link
            href="/login"
            className="monolith-btn-outline px-8 py-3 w-full sm:w-auto text-xs flex items-center justify-center gap-2"
          >
            <svg className="w-4 h-4 text-[#F4F4F6]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
            </svg>
            AUTHENTICATE PASSKEY
          </Link>
        </div>

        {/* Feature Matrix Cards */}
        <div className="mt-20 grid grid-cols-1 md:grid-cols-4 gap-4 text-left">
          {[
            {
              code: "01",
              title: "Domino Threat Simulator",
              desc: "Calculates the collateral blast radius across SSO, secondary emails, and reused password clusters.",
              tag: "CASCADE ENGINE",
            },
            {
              code: "02",
              title: "Android Sentry & Theft Guard",
              desc: "Audits accessibility banking trojans, overlay tapjacking, and arms motion pickpocket sensors.",
              tag: "ENDPOINT SHIELD",
            },
            {
              code: "03",
              title: "Airspace RF Radar",
              desc: "Detects evil-twin WiFi access points, rogue Bluetooth tracking tags, and acoustic beacons in physical space.",
              tag: "PHYSICAL SENSORS",
            },
            {
              code: "04",
              title: "Hardware Passkey Enclave",
              desc: "Zero-knowledge cryptographic audit proofs anchored on-chain with hardware biometric authentication.",
              tag: "CRYPTO PROOFS",
            },
          ].map((f) => (
            <div
              key={f.code}
              className="bg-[#131417] border border-[#222429] rounded-lg p-5 hover:border-[#383B43] transition-all flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <span className="text-[10px] font-mono text-[#6B6E78] font-bold">{f.code} //</span>
                  <span className="text-[9px] font-mono text-[#D4D6DC] px-1.5 py-0.5 rounded bg-[#0B0C0E] border border-[#222429]">
                    {f.tag}
                  </span>
                </div>
                <h3 className="text-sm font-bold font-display text-[#F4F4F6] mb-2">{f.title}</h3>
                <p className="text-xs text-[#A1A3AA] leading-relaxed">{f.desc}</p>
              </div>
              <div className="mt-4 pt-3 border-t border-[#1C1E24] text-[10px] font-mono text-[#3E9B66]">
                STATUS: VERIFIED
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
