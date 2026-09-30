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
      setError("Registration failed. Email or username may already exist.");
    } finally {
      setLoading(false);
    }
  };

  const update = (field: string, value: string) => setForm((f) => ({ ...f, [field]: value }));

  return (
    <div className="fixed inset-0 z-10 overflow-y-auto flex bg-[#0F172A] px-4 py-10">
      <div className="w-full max-w-md m-auto">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold bg-gradient-to-r from-[#3B82F6] to-[#8B5CF6] bg-clip-text text-transparent">
            PrivacyShield
          </h1>
          <p className="text-[#94A3B8] mt-2">Create your account</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-[#1E293B] border border-[#334155] rounded-2xl p-8 space-y-5">
          {error && (
            <div className="bg-[#EF4444]/10 border border-[#EF4444]/20 text-[#EF4444] px-4 py-3 rounded-xl text-sm">
              {error}
            </div>
          )}

          <div>
            <label className="block text-sm text-[#94A3B8] mb-2">Full Name</label>
            <input
              type="text"
              value={form.full_name}
              onChange={(e) => update("full_name", e.target.value)}
              className="w-full px-4 py-3 bg-[#0F172A] border border-[#334155] rounded-xl text-white placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-colors"
              placeholder="John Doe"
            />
          </div>

          <div>
            <label className="block text-sm text-[#94A3B8] mb-2">Username</label>
            <input
              type="text"
              value={form.username}
              onChange={(e) => update("username", e.target.value)}
              className="w-full px-4 py-3 bg-[#0F172A] border border-[#334155] rounded-xl text-white placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-colors"
              placeholder="johndoe"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-[#94A3B8] mb-2">Email</label>
            <input
              type="email"
              value={form.email}
              onChange={(e) => update("email", e.target.value)}
              className="w-full px-4 py-3 bg-[#0F172A] border border-[#334155] rounded-xl text-white placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-colors"
              placeholder="you@example.com"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-[#94A3B8] mb-2">Password</label>
            <input
              type="password"
              value={form.password}
              onChange={(e) => update("password", e.target.value)}
              className="w-full px-4 py-3 bg-[#0F172A] border border-[#334155] rounded-xl text-white placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6] transition-colors"
              placeholder="Min 8 characters"
              required
              minLength={8}
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#3B82F6] hover:bg-[#2563EB] disabled:opacity-50 text-white rounded-xl font-medium transition-all"
          >
            {loading ? "Creating account..." : "Create Account"}
          </button>

          <p className="text-center text-sm text-[#64748B]">
            Already have an account?{" "}
            <Link href="/login" className="text-[#3B82F6] hover:underline">Sign In</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
