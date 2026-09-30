import Link from "next/link";

export default function Wordmark({ size = "text-2xl", href = "/" }: { size?: string; href?: string }) {
  return (
    <Link href={href} className={`inline-flex items-baseline gap-2 font-serif text-ink ${size} leading-none`}>
      <span className="inline-block w-[0.55em] h-[0.55em] bg-signal translate-y-[-0.05em]" aria-hidden />
      <span>
        Privacy<span className="italic">Shield</span>
      </span>
    </Link>
  );
}
