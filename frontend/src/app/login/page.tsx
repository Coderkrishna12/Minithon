"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import api from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [isScanningPasskey, setIsScanningPasskey] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await api.post("/auth/login", { email, password });
      localStorage.setItem("token", res.data.access_token);
      router.push("/dashboard");
    } catch {
      setError("Invalid credential handshake. Please verify your email and passphrase.");
    } finally {
      setLoading(false);
    }
  };

  const handleBiometricPasskey = async () => {
    setIsScanningPasskey(true);
    setError("");
    try {
      // Simulate hardware-isolated WebAuthn / Secure Enclave attestation
      await new Promise((r) => setTimeout(r, 700));
      // Auto fill or authenticate demo session
      setEmail("demo@privacyshield.io");
      setPassword("password123");
      const res = await api.post("/auth/login", {
        email: email || "demo@privacyshield.io",
        password: password || "password123",
      });
      localStorage.setItem("token", res.data.access_token);
      router.push("/dashboard");
    } catch {
      setError("Biometric key attestation verified. Please authenticate with your credentials.");
    } finally {
      setIsScanningPasskey(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-[#0B0C0E] px-4 py-12">
      <div className="w-full max-w-md animate-fade-in">
        {/* Monolith Vault Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded bg-[#131417] border border-[#222429] mb-4">
            <span className="w-2 h-2 rounded-full bg-[#3E9B66]" />
            <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
              HARDWARE ENCLAVE // ACCESS GATE
            </span>
          </div>
          <h1 className="text-2xl font-bold font-display tracking-tight text-[#F4F4F6]">
            PRIVACYSHIELD
          </h1>
          <p className="text-xs text-[#A1A3AA] mt-1 font-display">
            Nordic Monolith Security & Threat Auditor
          </p>
        </div>

        {/* Auth Form Card */}
        <form
          onSubmit={handleSubmit}
          className="bg-[#131417] border border-[#222429] rounded-lg p-8 space-y-5"
        >
          {error && (
            <div className="bg-[#E54D2E]/10 border border-[#E54D2E]/30 text-[#E54D2E] px-4 py-3 rounded text-xs font-mono">
              {error}
            </div>
          )}

          <div>
            <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-2 font-display">
              IDENTIFIER / EMAIL
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 bg-[#0B0C0E] border border-[#222429] rounded text-[#F4F4F6] placeholder-[#6B6E78] text-sm focus:border-[#D4D6DC]"
              placeholder="operator@privacyshield.io"
              required
            />
          </div>

          <div>
            <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-2 font-display">
              SECURITY PASSPHRASE
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 bg-[#0B0C0E] border border-[#222429] rounded text-[#F4F4F6] placeholder-[#6B6E78] text-sm focus:border-[#D4D6DC]"
              placeholder="••••••••••••"
              required
            />
          </div>

          <button
            type="submit"
            disabled={loading || isScanningPasskey}
            className="w-full monolith-btn-primary py-3 disabled:opacity-50"
          >
            {loading ? "AUTHENTICATING ENCLAVE..." : "AUTHENTICATE"}
          </button>

          <button
            type="button"
            onClick={handleBiometricPasskey}
            disabled={loading || isScanningPasskey}
            className="w-full monolith-btn-outline py-2.5 flex items-center justify-center gap-2 text-xs"
          >
            <svg className="w-4 h-4 text-[#F4F4F6]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M7.864 4.243A7.5 7.5 0 0119.5 10.5c0 2.92-.556 5.709-1.568 8.268M5.742 6.364A7.465 7.465 0 004.5 10.5a7.464 7.464 0 01-1.15 3.993m1.989 3.559A11.209 11.209 0 008.25 10.5a3.75 3.75 0 117.5 0c0 .527-.021 1.049-.064 1.565M12 10.5a14.94 14.94 0 01-3.6 9.75m6.6-3.3A17.95 17.95 0 0112 21" />
            </svg>
            {isScanningPasskey ? "VERIFYING PASSKEY SENSOR..." : "BIOMETRIC PASSKEY (DEMO)"}
          </button>

          <div className="pt-2 border-t border-[#1C1E24] text-center text-xs font-mono text-[#6B6E78]">
            Need a secure enclave account?{" "}
            <Link href="/register" className="text-[#F4F4F6] underline hover:text-white">
              Enroll Here
            </Link>
          </div>
        </form>
      </div>
    </div>
  );
}
