import json
from pathlib import Path
import urllib.parse


def test_services_catalog_has_at_least_100_services():
    catalog_file = Path(__file__).resolve().parents[1] / "app" / "data" / "services.json"
    assert catalog_file.exists(), "backend/app/data/services.json must exist"

    with open(catalog_file, "r", encoding="utf-8") as f:
        services = json.load(f)

    assert len(services) >= 100, f"Expected >= 100 services, found {len(services)}"

    required_keys = {
        "id", "name", "domains", "category",
        "securityUrl", "twoFAUrl", "passwordUrl", "deleteUrl",
        "passkeySupport", "verifiedAt"
    }

    for s in services:
        missing = required_keys - set(s.keys())
        assert not missing, f"Service {s.get('name')} missing fields: {missing}"
        assert len(s["domains"]) > 0, f"Service {s['name']} has empty domains list"

        for url_key in ["securityUrl", "twoFAUrl", "passwordUrl", "deleteUrl"]:
            url = s[url_key]
            parsed = urllib.parse.urlparse(url)
            assert parsed.scheme in ("http", "https"), f"Invalid scheme in {url_key} for {s['name']}: {url}"
            assert parsed.netloc, f"Missing netloc in {url_key} for {s['name']}: {url}"
