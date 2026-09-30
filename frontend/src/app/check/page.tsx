import PasswordLeakCheck from "@/components/PasswordLeakCheck";

export default function CheckPage() {
  return (
    <div className="animate-slide-up">
      <h1 className="text-2xl font-bold mb-1">Password Leak Check</h1>
      <p className="text-[#94A3B8] mb-8">See whether a password already circulates in attacker wordlists.</p>
      <PasswordLeakCheck />
    </div>
  );
}
