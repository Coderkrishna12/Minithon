import base64
import json
from functools import lru_cache

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

from app.core.config import get_settings

_B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
_ED25519_MULTICODEC = b"\xed\x01"


def _b58encode(data: bytes) -> str:
    n = int.from_bytes(data, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = _B58[r] + out
    return "1" * (len(data) - len(data.lstrip(b"\0"))) + out


def _b58decode(text: str) -> bytes:
    n = 0
    for ch in text:
        n = n * 58 + _B58.index(ch)
    body = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    return b"\0" * (len(text) - len(text.lstrip("1"))) + body


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _b64url_decode(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def raw_public(key: Ed25519PublicKey) -> bytes:
    return key.public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def did_key(public_key: Ed25519PublicKey) -> str:
    """W3C did:key identifier for an Ed25519 public key."""
    return "did:key:z" + _b58encode(_ED25519_MULTICODEC + raw_public(public_key))


def public_key_from_did(did: str) -> Ed25519PublicKey:
    if not did.startswith("did:key:z"):
        raise ValueError("Only did:key identifiers are supported")
    decoded = _b58decode(did.removeprefix("did:key:z"))
    if not decoded.startswith(_ED25519_MULTICODEC):
        raise ValueError("Not an Ed25519 did:key")
    return Ed25519PublicKey.from_public_bytes(decoded[len(_ED25519_MULTICODEC):])


def new_keypair() -> tuple[Ed25519PrivateKey, str]:
    key = Ed25519PrivateKey.generate()
    return key, did_key(key.public_key())


def private_key_b64(key: Ed25519PrivateKey) -> str:
    return _b64url(key.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption()))


@lru_cache
def issuer_key() -> Ed25519PrivateKey:
    """Platform signing key, derived from SECRET_KEY so it is stable for as long as SECRET_KEY is."""
    seed = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"privacyshield-issuer-v1").derive(
        get_settings().secret_key.encode()
    )
    return Ed25519PrivateKey.from_private_bytes(seed)


def issuer_did() -> str:
    return did_key(issuer_key().public_key())


def _canonical(payload: dict) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str).encode()


def sign_payload(payload: dict) -> dict:
    """Ed25519 proof over the canonical JSON of payload, verifiable with the issuer's did:key."""
    did = issuer_did()
    return {
        "type": "Ed25519Signature2020",
        "verificationMethod": f"{did}#{did.removeprefix('did:key:')}",
        "proofValue": _b64url(issuer_key().sign(_canonical(payload))),
    }


def verify_payload(payload: dict, proof: dict) -> bool:
    try:
        did = proof["verificationMethod"].split("#")[0]
        public_key_from_did(did).verify(_b64url_decode(proof["proofValue"]), _canonical(payload))
        return True
    except (InvalidSignature, KeyError, ValueError, TypeError):
        return False
