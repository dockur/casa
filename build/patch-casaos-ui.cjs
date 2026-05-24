/**
 * Patch script for the CasaOS-UI dependency issue.
 *
 * The package @icewhale/icewhale-files-openapi has been removed from npm.
 * This script redirects it to the mirror @yundera/icewhale-files-openapi
 * (published at the same version) via pnpm's npm: alias syntax, and updates
 * the pnpm-lock.yaml entries accordingly.
 *
 * Run from the CasaOS-UI working directory where package.json and
 * pnpm-lock.yaml are present.
 */

'use strict';

const fs = require('fs');

// ---------------------------------------------------------------------------
// Patch package.json
// ---------------------------------------------------------------------------
const pkgPath = 'package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

if (pkg.dependencies && pkg.dependencies['@icewhale/icewhale-files-openapi']) {
  pkg.dependencies['@icewhale/icewhale-files-openapi'] =
    'npm:@yundera/icewhale-files-openapi@1.3.0-alpha133';
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
  console.log('Patched package.json');
}

// ---------------------------------------------------------------------------
// Patch pnpm-lock.yaml
// ---------------------------------------------------------------------------
const lockPath = 'pnpm-lock.yaml';
let lock = fs.readFileSync(lockPath, 'utf8');

// 1. Importer entry: update specifier and version for the aliased package
lock = lock.replace(
  "      '@icewhale/icewhale-files-openapi':\n        specifier: latest\n        version: 1.3.0-alpha133",
  "      '@icewhale/icewhale-files-openapi':\n        specifier: npm:@yundera/icewhale-files-openapi@1.3.0-alpha133\n        version: '@yundera/icewhale-files-openapi@1.3.0-alpha133'"
);

// 2. Packages entry: rename key and update integrity hash
lock = lock.replace(
  "  '@icewhale/icewhale-files-openapi@1.3.0-alpha133':\n    resolution: {integrity: sha512-EQz1nG4HuIKyi98JfoZ03UpM7JRbwYByf7UeWa0fknNWNMQ2mF4hUHcfQ73YfkhQ51oL/yk9l9Qyvr56LAHh+w==}",
  "  '@yundera/icewhale-files-openapi@1.3.0-alpha133':\n    resolution: {integrity: sha512-V6t6eN7E2x4oPZxJLeLDO1r5T7QIRCr/TopJjcGz9RASaY3Bv2j1dYepQBtynnKnKz+MojE7ELqkH7S4ghXXeg==}"
);

// 3. Snapshots entry: rename key
lock = lock.replace(
  "  '@icewhale/icewhale-files-openapi@1.3.0-alpha133':\n    dependencies:",
  "  '@yundera/icewhale-files-openapi@1.3.0-alpha133':\n    dependencies:"
);

fs.writeFileSync(lockPath, lock);
console.log('Patched pnpm-lock.yaml');
