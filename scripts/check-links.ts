import fs from "fs";
import path from "path";
import https from "https";
import http from "http";

interface ServiceEntry {
  id: string;
  name: string;
  domains: string[];
  category: string;
  securityUrl: string;
  twoFAUrl: string;
  passwordUrl: string;
  deleteUrl: string;
  passkeySupport: boolean;
  verifiedAt: string;
}

const catalogPath = path.resolve(__dirname, "../frontend/src/data/services.json");
if (!fs.existsSync(catalogPath)) {
  console.error(`Catalog not found at ${catalogPath}`);
  process.exit(1);
}

const catalog: ServiceEntry[] = JSON.parse(fs.readFileSync(catalogPath, "utf-8"));
console.log(`Verifying ${catalog.length} services...`);

let failed = 0;

for (const entry of catalog) {
  if (!entry.id || !entry.name || !entry.domains || !entry.domains.length) {
    console.error(`[INVALID] Missing identifier or domains for ${entry.name}`);
    failed++;
  }
  for (const field of ["securityUrl", "twoFAUrl", "passwordUrl", "deleteUrl"] as const) {
    const url = entry[field];
    if (!url || !url.startsWith("http")) {
      console.error(`[INVALID] ${entry.name} has invalid ${field}: ${url}`);
      failed++;
    }
  }
}

if (failed > 0) {
  console.error(`Found ${failed} catalog defects.`);
  process.exit(1);
} else {
  console.log(`All ${catalog.length} catalog entries validated successfully!`);
}
