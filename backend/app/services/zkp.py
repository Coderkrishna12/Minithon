"""Zero-knowledge proof that a committed privacy score meets a threshold.

Construction
------------
* Group: the 2048-bit MODP group from RFC 3526 (group 14), a safe prime p = 2q + 1.
  We work in the subgroup of quadratic residues, of prime order q.
* Pedersen commitment: C = g^v * h^r (mod p). It hides v perfectly and binds the
  committer to v, provided nobody knows log_g(h). h is derived by hashing a fixed
  string into the group, so no one (including us) knows that logarithm.
* Range proof: to show v >= t, prove that d = v - t lies in [0, 2^n) for n = 7
  (scores are 0..100, so d <= 100 < 128). d is split into bits b_i, each bit gets its
  own commitment C_i = g^b_i * h^r_i with sum(r_i * 2^i) = r, and each C_i carries a
  Chaum–Damgård–Schoenmakers OR-proof that it commits to 0 or to 1, without saying which.
  The verifier checks prod(C_i^(2^i)) == C * g^(-t), which ties the bits to the score.
* Fiat–Shamir: every challenge is a hash of the full statement and all commitments,
  so the proof is non-interactive and cannot be replayed for a different statement.

A verifier learns only that the committed score is >= t. A prover whose score is
below t cannot produce a proof that verifies: it would need a negative d to have a
valid 7-bit decomposition.
"""
from __future__ import annotations

import hashlib
import json
import secrets

# RFC 3526, 2048-bit MODP Group (group 14).
P = int(
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DD"
    "EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
    "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F"
    "83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B"
    "E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA0510"
    "15728E5A8AACAA68FFFFFFFFFFFFFFFF",
    16,
)
Q = (P - 1) // 2
G = 4  # 2^2: a quadratic residue, so it generates the order-q subgroup
BITS = 7
DOMAIN = b"PrivacyShield/zkp/v1"


def _hash_to_group(label: bytes) -> int:
    """Map a label into the order-q subgroup with no known discrete log relative to G."""
    out, counter = b"", 0
    while len(out) < 512:
        out += hashlib.sha512(DOMAIN + label + counter.to_bytes(4, "big")).digest()
        counter += 1
    x = int.from_bytes(out, "big") % P
    return pow(x, 2, P)  # squaring lands in the quadratic-residue subgroup


H = _hash_to_group(b"pedersen-h")


def _challenge(*parts) -> int:
    data = json.dumps([str(p) for p in parts], separators=(",", ":")).encode()
    return int.from_bytes(hashlib.sha512(DOMAIN + data).digest(), "big") % Q


def _rand() -> int:
    return secrets.randbelow(Q - 1) + 1


def _inv(x: int) -> int:
    return pow(x, P - 2, P)


def commit(value: int, randomness: int) -> int:
    return pow(G, value, P) * pow(H, randomness, P) % P


def new_commitment(value: int) -> tuple[int, int]:
    r = _rand()
    return commit(value, r), r


def _prove_bit(bit: int, r: int, c: int, context: str) -> dict:
    """CDS OR-proof that c = h^r (bit 0) or c / g = h^r (bit 1)."""
    targets = [c, c * _inv(G) % P]  # statement for branch 0 and branch 1
    sim = 1 - bit
    e_sim, z_sim = _rand(), _rand()
    a = [0, 0]
    a[sim] = pow(H, z_sim, P) * _inv(pow(targets[sim], e_sim, P)) % P
    k = _rand()
    a[bit] = pow(H, k, P)
    e = _challenge(context, c, a[0], a[1])
    e_real = (e - e_sim) % Q
    z_real = (k + e_real * r) % Q
    es, zs = [0, 0], [0, 0]
    es[bit], zs[bit] = e_real, z_real
    es[sim], zs[sim] = e_sim, z_sim
    return {"a0": hex(a[0]), "a1": hex(a[1]), "e0": hex(es[0]), "e1": hex(es[1]), "z0": hex(zs[0]), "z1": hex(zs[1])}


def _verify_bit(c: int, proof: dict, context: str) -> bool:
    a0, a1 = int(proof["a0"], 16), int(proof["a1"], 16)
    e0, e1 = int(proof["e0"], 16), int(proof["e1"], 16)
    z0, z1 = int(proof["z0"], 16), int(proof["z1"], 16)
    if not all(0 < x < P for x in (a0, a1)) or not all(0 <= x < Q for x in (e0, e1, z0, z1)):
        return False
    if (e0 + e1) % Q != _challenge(context, c, a0, a1):
        return False
    return (
        pow(H, z0, P) == a0 * pow(c, e0, P) % P
        and pow(H, z1, P) == a1 * pow(c * _inv(G) % P, e1, P) % P
    )


def prove_at_least(value: int, randomness: int, commitment: int, threshold: int, context: str) -> dict:
    """Prove that `commitment` hides a value >= threshold. Raises if that's false."""
    d = value - threshold
    if not 0 <= d < 2 ** BITS:
        raise ValueError("The committed score does not meet this threshold, so no valid proof exists.")
    bits = [(d >> i) & 1 for i in range(BITS)]
    rs = [_rand() for _ in range(BITS - 1)]
    partial = sum(r_i * (1 << i) for i, r_i in enumerate(rs)) % Q
    rs.append((randomness - partial) * pow(1 << (BITS - 1), -1, Q) % Q)
    bit_commitments = [commit(b, r_i) for b, r_i in zip(bits, rs)]
    ctx = f"{context}|{commitment:x}|{threshold}|" + ",".join(f"{c:x}" for c in bit_commitments)
    return {
        "scheme": "pedersen-cds-range/v1",
        "group": "rfc3526-modp-2048",
        "bits": BITS,
        "bit_commitments": [hex(c) for c in bit_commitments],
        "bit_proofs": [_prove_bit(b, r_i, c, f"{ctx}|{i}") for i, (b, r_i, c) in enumerate(zip(bits, rs, bit_commitments))],
    }


def verify_at_least(commitment: int, threshold: int, proof: dict, context: str) -> tuple[bool, str]:
    try:
        if proof.get("scheme") != "pedersen-cds-range/v1" or proof.get("bits") != BITS:
            return False, "Unknown proof scheme"
        cs = [int(c, 16) for c in proof["bit_commitments"]]
        if len(cs) != BITS or len(proof["bit_proofs"]) != BITS:
            return False, "Wrong number of bit commitments"
        if not all(0 < c < P and pow(c, Q, P) == 1 for c in cs + [commitment]):
            return False, "A commitment is not a valid group element"
        # The bits must recombine into the committed score minus the threshold.
        combined = 1
        for i, c in enumerate(cs):
            combined = combined * pow(c, 1 << i, P) % P
        if combined != commitment * _inv(pow(G, threshold, P)) % P:
            return False, "Bit commitments don't add up to the committed score minus the threshold"
        ctx = f"{context}|{commitment:x}|{threshold}|" + ",".join(f"{c:x}" for c in cs)
        for i, (c, bp) in enumerate(zip(cs, proof["bit_proofs"])):
            if not _verify_bit(c, bp, f"{ctx}|{i}"):
                return False, f"Bit proof {i} failed"
        return True, "Valid: the committed score meets the threshold"
    except (KeyError, ValueError, TypeError) as e:
        return False, f"Malformed proof ({e.__class__.__name__})"
