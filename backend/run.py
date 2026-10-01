"""Start the PrivacyShield API so a phone on the same network (or USB) can reach it.

    python run.py

Installs missing requirements, opens the port in Windows Firewall when it can, sets up
`adb reverse` for a USB-connected phone, prints the URLs to use, then serves on 0.0.0.0.
"""
import importlib.util
import os
import shutil
import socket
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PORT = int(os.environ.get("PORT", "8000"))
RULE_NAME = "PrivacyShield API"

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


def ensure_requirements() -> None:
    missing = [pkg for module, pkg in REQUIRED.items() if importlib.util.find_spec(module) is None]
    if not missing:
        return
    print(f"Installing missing packages ({', '.join(missing)}) from requirements.txt ...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", str(HERE / "requirements.txt")])


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
    print()

    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=PORT, reload="--no-reload" not in sys.argv)


if __name__ == "__main__":
    main()
