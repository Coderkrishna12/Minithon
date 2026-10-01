"""Start the PrivacyShield API so a phone can reach it.

    python run.py            # same Wi-Fi or USB
    python run.py --public   # any network: opens a free Cloudflare tunnel with an https URL

Installs missing requirements, opens the port in Windows Firewall when it can, sets up
`adb reverse` for a USB-connected phone, prints the URLs to use, then serves on 0.0.0.0.
"""
import atexit
import importlib.util
import os
import platform
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
PORT = int(os.environ.get("PORT", "8000"))
RULE_NAME = "PrivacyShield API"
TOOLS = HERE / ".tools"
CLOUDFLARED_RELEASE = "https://github.com/cloudflare/cloudflared/releases/latest/download/"
CLOUDFLARED_ASSETS = {
    ("windows", "amd64"): "cloudflared-windows-amd64.exe",
    ("windows", "x86_64"): "cloudflared-windows-amd64.exe",
    ("linux", "x86_64"): "cloudflared-linux-amd64",
    ("linux", "aarch64"): "cloudflared-linux-arm64",
}
TUNNEL_URL = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")

# import name -> pip requirement that provides it
REQUIRED = {
    "fastapi": "fastapi",
    "uvicorn": "uvicorn",
    "sqlalchemy": "sqlalchemy",
    "aiosqlite": "aiosqlite",
    "pydantic_settings": "pydantic-settings",
    "email_validator": "pydantic[email]",
    "jose": "python-jose",
    "passlib": "passlib",
    "multipart": "python-multipart",
    "httpx": "httpx",
    "cryptography": "cryptography",
    "anthropic": "anthropic",
    "web3": "web3",
}


def _import_error() -> str | None:
    """Import the whole app in a fresh interpreter; catches missing packages and mismatched versions."""
    result = subprocess.run([sys.executable, "-c", "import app.main"], cwd=HERE, capture_output=True, text=True)
    if result.returncode == 0:
        return None
    lines = [line for line in result.stderr.strip().splitlines() if line.strip()]
    return lines[-1] if lines else "unknown import error"


def ensure_requirements() -> None:
    missing = [pkg for module, pkg in REQUIRED.items() if importlib.util.find_spec(module) is None]
    problem = f"missing {', '.join(missing)}" if missing else _import_error()
    if not problem:
        return
    print(f"Backend can't start ({problem}).")
    print("Reinstalling the pinned versions from requirements.txt ...")
    subprocess.call([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", str(HERE / "requirements.txt")])
    still = _import_error()
    if still:
        print(f"\nStill failing: {still}")
        print("Your global Python has conflicting packages. Use a clean virtual environment:")
        print("    python -m venv .venv")
        print("    .venv\\Scripts\\activate      (macOS/Linux: source .venv/bin/activate)")
        print("    python run.py")
        sys.exit(1)


def lan_addresses() -> list[str]:
    found = set()
    try:
        # A UDP "connect" sends nothing; it only asks the OS which interface routes outward.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            found.add(s.getsockname()[0])
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            found.add(info[4][0])
    except OSError:
        pass
    return sorted(a for a in found if not a.startswith(("127.", "169.254.")))


def open_windows_firewall() -> str:
    if os.name != "nt":
        return "not needed"
    shown = subprocess.run(["netsh", "advfirewall", "firewall", "show", "rule", f"name={RULE_NAME}"], capture_output=True, text=True)
    if shown.returncode == 0:
        return "already open"
    added = subprocess.run(
        ["netsh", "advfirewall", "firewall", "add", "rule", f"name={RULE_NAME}",
         "dir=in", "action=allow", "protocol=TCP", f"localport={PORT}"],
        capture_output=True, text=True,
    )
    if added.returncode == 0:
        return "opened"
    return (
        "could not open (needs Administrator). Run once in an Administrator terminal:\n"
        f'      netsh advfirewall firewall add rule name="{RULE_NAME}" dir=in action=allow protocol=TCP localport={PORT}'
    )


def adb_reverse() -> str:
    adb = shutil.which("adb")
    if not adb:
        return "adb not found (only needed for USB)"
    result = subprocess.run([adb, "reverse", f"tcp:{PORT}", f"tcp:{PORT}"], capture_output=True, text=True)
    return "active: a USB phone can use http://localhost:%d/api" % PORT if result.returncode == 0 else "no USB phone connected"


def cloudflared_binary() -> str | None:
    found = shutil.which("cloudflared")
    if found:
        return found
    asset = CLOUDFLARED_ASSETS.get((platform.system().lower(), platform.machine().lower()))
    if not asset:
        return None  # e.g. macOS: brew install cloudflared
    target = TOOLS / asset
    if not target.exists():
        TOOLS.mkdir(exist_ok=True)
        print(f"  Downloading cloudflared ({asset}) ...")
        urllib.request.urlretrieve(CLOUDFLARED_RELEASE + asset, target)
        target.chmod(0o755)
    return str(target)


def find_tunnel_url(lines) -> str | None:
    for line in lines:
        match = TUNNEL_URL.search(line)
        if match:
            return match.group(0)
    return None


def start_tunnel(timeout: float = 60) -> str | None:
    """Expose localhost:PORT at a public https URL (no account needed) and keep it open while we run."""
    try:
        binary = cloudflared_binary()
    except OSError as e:
        print(f"  Could not download cloudflared: {e}")
        return None
    if not binary:
        print("  Install cloudflared first (macOS: brew install cloudflared).")
        return None
    proc = subprocess.Popen(
        [binary, "tunnel", "--url", f"http://localhost:{PORT}", "--no-autoupdate"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
    )
    atexit.register(proc.terminate)
    found: list[str] = []

    def pump():
        for line in proc.stdout:
            if not found and (url := find_tunnel_url([line])):
                found.append(url)

    threading.Thread(target=pump, daemon=True).start()
    deadline = time.time() + timeout
    while not found and time.time() < deadline and proc.poll() is None:
        time.sleep(0.2)
    return found[0] if found else None


def main() -> None:
    os.chdir(HERE)
    sys.path.insert(0, str(HERE))
    ensure_requirements()

    print("\nPrivacyShield API")
    print(f"  Firewall : {open_windows_firewall()}")
    print(f"  USB      : {adb_reverse()}")
    addresses = lan_addresses()
    if addresses:
        print("  Phone on the same Wi-Fi: the app finds the server by itself, or enter one of")
        for address in addresses:
            print(f"      http://{address}:{PORT}/api")
        print(f"  Check from the phone's browser: http://{addresses[0]}:{PORT}/api/health")
    else:
        print("  No network address found; is this PC on Wi-Fi?")

    if "--public" in sys.argv:
        print("  Public   : opening a Cloudflare tunnel ...")
        url = start_tunnel()
        if url:
            print("\n  " + "=" * 60)
            print(f"  In the app, tap SERVER and enter:  {url}/api")
            print(f"  Test in the phone's browser:       {url}/api/health")
            print("  Anyone with this link can reach the API while this window is open.")
            print("  " + "=" * 60)
        else:
            print("  Tunnel did not start. Check this PC's internet connection.")
    else:
        print("  Phone on a different or locked-down Wi-Fi? Run: python run.py --public")
    print()

    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=PORT, reload="--no-reload" not in sys.argv)


if __name__ == "__main__":
    main()
