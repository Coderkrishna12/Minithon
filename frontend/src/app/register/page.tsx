"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import api from "@/lib/api";

export default function RegisterPage() {
  const router = useRouter();
  const [form, setForm] = useState({ email: "", username: "", password: "", full_name: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await api.post("/auth/register", form);
      localStorage.setItem("token", res.data.access_token);
      router.push("/dashboard");
    } catch {
      setError("Registration rejected. Email or username already exists within enclave index.");
    } finally {
      setLoading(false);
    }
  };

  const update = (field: string, value: string) => setForm((f) => ({ ...f, [field]: value }));

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-[#0B0C0E] px-4 py-12">
      <div className="w-full max-w-md animate-fade-in">
        <div className="text-center mb-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded bg-[#131417] border border-[#222429] mb-4">
            <span className="w-2 h-2 rounded-full bg-[#3E9B66]" />
            <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
              ENROLL NEW OPERATOR
            </span>
          </div>
          <h1 className="text-2xl font-bold font-display tracking-tight text-[#F4F4F6]">
            PRIVACYSHIELD ENCLAVE
          </h1>
          <p className="text-xs text-[#A1A3AA] mt-1 font-display">
            Initialize cryptographic identity & permission auditor
          </p>
        </div>

        <form
          onSubmit={handleSubmit}
          className="bg-[#131417] border border-[#222429] rounded-lg p-8 space-y-4"
        >
          {error && (
            <div className="bg-[#E54D2E]/10 border border-[#E54D2E]/30 text-[#E54D2E] px-4 py-3 rounded text-xs font-mono">
              {error}
            </div>
          )}

          <div>
            <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
              OPERATOR FULL NAME
            </label>
            <input
              type="text"
              value={form.full_name}
              onChange={(e) => update("full_name", e.target.value)}
              className="w-full px-4 py-2.5 bg-[#0B0C0E] border border-[#222429] rounded text-[#F4F4F6] placeholder-[#6B6E78] text-sm focus:border-[#D4D6DC]"
              placeholder="e.g. Alex Vance"
            />
          </div>

          <div>
            <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
              CODENAME / USERNAME *
            </label>
            <input
              type="text"
              value={form.username}
              onChange={(e) => update("username", e.target.value)}
              className="w-full px-4 py-2.5 bg-[#0B0C0E] border border-[#222429] rounded text-[#F4F4F6] placeholder-[#6B6E78] text-sm focus:border-[#D4D6DC]"
              placeholder="alexv"
              required
            />
          </div>

          <div>
            <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
              PRIMARY EMAIL *
            </label>
            <input
              type="email"
              value={form.email}
              onChange={(e) => update("email", e.target.value)}
              className="w-full px-4 py-2.5 bg-[#0B0C0E] border border-[#222429] rounded text-[#F4F4F6] placeholder-[#6B6E78] text-sm focus:border-[#D4D6DC]"
              placeholder="alex@example.com"
              required
            />
          </div>

          <div>
            <label className="block text-[11px] font-mono tracking-wider uppercase text-[#A1A3AA] mb-1.5 font-display">
              MASTER PASSPHRASE *
            </label>
            <input
              type="password"
              value={form.password}
              onChange={(e) => update("password", e.target.value)}
              className="w-full px-4 py-2.5 bg-[#0B0C0E] border border-[#222429] rounded text-[#F4F4F6] placeholder-[#6B6E78] text-sm focus:border-[#D4D6DC]"
              placeholder="Min 8 characters"
              required
              minLength={8}
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full monolith-btn-primary py-3 disabled:opacity-50 mt-2"
          >
            {loading ? "INITIALIZING SECURE ENCLAVE..." : "GENERATE ENCLAVE IDENTITY"}
          </button>

          <div className="pt-3 border-t border-[#1C1E24] text-center text-xs font-mono text-[#6B6E78]">
            Already holding verified credentials?{" "}
            <Link href="/login" className="text-[#F4F4F6] underline hover:text-white">
              Sign In
            </Link>
          </div>
        </form>
      </div>
    </div>
  );
}
