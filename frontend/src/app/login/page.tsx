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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await api.post("/auth/login", { email, password });
      localStorage.setItem("token", res.data.access_token);
      router.push("/dashboard");
    } catch {
      setError("Invalid email or password");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-10 overflow-y-auto flex bg-[#0F172A] px-4 py-10">
      <div className="w-full max-w-md m-auto">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold bg-gradient-to-r from-[#3B82F6] to-[#8B5CF6] bg-clip-text text-transparent">
            PrivacyShield
          </h1>
          <p className="text-[#94A3B8] mt-2">Sign in to your account</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-[#1E293B] border border-[#334155] rounded-2xl p-8 space-y-5">
          {error && (
            <div className="bg-[#EF4444]/10 border border-[#EF4444]/20 text-[#EF4444] px-4 py-3 rounded-xl text-sm">
              {error}
            </div>
          )}

          <div>
            <label className="block text-sm text-[#94A3B8] mb-2">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 bg-[#0F172A] border border-[#334155] rounded-xl text-white placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-colors"
              placeholder="you@example.com"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-[#94A3B8] mb-2">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 bg-[#0F172A] border border-[#334155] rounded-xl text-white placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-colors"
              placeholder="Enter password"
              required
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#3B82F6] hover:bg-[#2563EB] disabled:opacity-50 text-white rounded-xl font-medium transition-all"
          >
            {loading ? "Signing in..." : "Sign In"}
          </button>

          <p className="text-center text-sm text-[#64748B]">
            Don&apos;t have an account?{" "}
            <Link href="/register" className="text-[#3B82F6] hover:underline">Register</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
