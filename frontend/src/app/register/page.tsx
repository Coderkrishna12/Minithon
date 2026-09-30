"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import api from "@/lib/api";
import Wordmark from "@/components/Wordmark";

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
    <div className="fixed inset-0 z-10 overflow-y-auto flex bg-[#F2EEE5] px-4 py-10">
      <div className="w-full max-w-md m-auto">
        <div className="mb-8">
          <Wordmark />
          <h1 className="page-title mt-10">Open your file.</h1>
          <p className="text-[#5B544A] mt-3">Create your account</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-8 space-y-5">
          {error && (
            <div className="bg-[#C8321A]/10 border border-[#C8321A]/20 text-[#C8321A] px-4 py-3 rounded-sm text-sm">
              {error}
            </div>
          )}

          <div>
            <label className="block text-sm text-[#5B544A] mb-2">Full Name</label>
            <input
              type="text"
              value={form.full_name}
              onChange={(e) => update("full_name", e.target.value)}
              className="w-full px-4 py-3 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-colors"
              placeholder="John Doe"
            />
          </div>

          <div>
            <label className="block text-sm text-[#5B544A] mb-2">Username</label>
            <input
              type="text"
              value={form.username}
              onChange={(e) => update("username", e.target.value)}
              className="w-full px-4 py-3 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-colors"
              placeholder="johndoe"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-[#5B544A] mb-2">Email</label>
            <input
              type="email"
              value={form.email}
              onChange={(e) => update("email", e.target.value)}
              className="w-full px-4 py-3 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-colors"
              placeholder="you@example.com"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-[#5B544A] mb-2">Password</label>
            <input
              type="password"
              value={form.password}
              onChange={(e) => update("password", e.target.value)}
              className="w-full px-4 py-3 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-colors"
              placeholder="Min 8 characters"
              required
              minLength={8}
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#17150F] hover:bg-[#C8321A] disabled:opacity-50 text-white rounded-sm font-medium transition-all"
          >
            {loading ? "Creating account..." : "Create Account"}
          </button>

          <p className="text-center text-sm text-[#8A8274]">
            Already have an account?{" "}
            <Link href="/login" className="text-[#23408E] hover:underline">Sign In</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
