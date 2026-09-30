import PasswordLeakCheck from "@/components/PasswordLeakCheck";

export default function CheckPage() {
  return (
    <div className="animate-slide-up">
      <p className="eyebrow mb-3">Audit &middot; 05</p>
      <h1 className="page-title">Password Leak Check</h1>
      <p className="text-ink-2 mt-3 mb-10 max-w-xl">See whether a password already circulates in attacker wordlists.</p>
      <div className="max-w-2xl"><PasswordLeakCheck /></div>
    </div>
  );
}
