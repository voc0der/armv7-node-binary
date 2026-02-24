# armv7-node-binary

Automated weekly builds of Node.js for **Linux ARMv7l (32-bit hard-float)** — the architecture that Node.js dropped official support for after v18.

Releases are published automatically via GitHub Actions whenever a new Node.js v24.x drops.

---

## Why does this exist?

Node.js dropped official ARMv7l binaries starting with Node 20. If you're building Docker images or running CI for ARMv7 devices (Raspberry Pi 2/3 in 32-bit mode, older ARM SBCs, etc.) you need to compile from source — which takes ages. This repo does it once and publishes the result.

---

## Using in your own repo

### Option 1 — Shell script (easiest, works in Dockerfile too)

```bash
# In your Dockerfile or CI step:
curl -fsSL https://raw.githubusercontent.com/voc0der/armv7-node-binary/main/scripts/install-node-armv7.sh | bash
```

With a GitHub token (avoids API rate limits in CI):

```yaml
- name: Install Node.js ARMv7
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    curl -fsSL https://raw.githubusercontent.com/voc0der/armv7-node-binary/main/scripts/install-node-armv7.sh | bash
```

### Option 2 — Direct download in your workflow

```yaml
- name: Install Node.js ARMv7
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    # Get the latest v24 release tarball URL
    URL=$(gh release list --repo voc0der/armv7-node-binary --limit 10 --json tagName,assets \
      | jq -r '[.[] | select(.tagName | startswith("v24."))] | first | .assets[] | select(.name | endswith(".tar.gz")) | .url')
    curl -fsSL "$URL" -o node.tar.gz
    tar -xzf node.tar.gz --strip-components=1 -C /usr/local
```

### Option 3 — Reusable workflow (pure GitHub Actions)

```yaml
# In your consuming repo's workflow:
jobs:
  get-node:
    uses: voc0der/armv7-node-binary/.github/workflows/setup-node-armv7.yml@main
    with:
      node_major: '24'

  build:
    needs: get-node
    runs-on: ubuntu-latest   # swap for your ARMv7 runner
    steps:
      - name: Use pre-fetched node path
        run: echo "Node is at ${{ needs.get-node.outputs.tarball_url }}"
```

---

## Build details

| Property | Value |
|---|---|
| Architecture | `armv7l` (32-bit ARM hard-float) |
| Float ABI | `hard` |
| FPU | `vfpv3` |
| Cross-compiler | `arm-linux-gnueabihf-gcc` on Ubuntu |
| Static | Yes (no external dep beyond system glibc) |
| ICU/intl | Disabled (keeps binary lean; rebuild with `--with-intl=small-icu` if needed) |
| Schedule | Every Monday 02:00 UTC |

---

## Trigger a manual build

Go to **Actions → Build Node.js ARMv7 → Run workflow** and optionally specify a version. Omit version to build the latest Node 24 release.

---

## Compatibility

Tested on:
- Raspberry Pi 2 Model B (ARMv7, 32-bit Raspberry Pi OS)
- Raspberry Pi 3 running 32-bit OS
- Generic ARMv7 Debian/Ubuntu systems

Not compatible with ARMv6 (Pi Zero/Pi 1) — for those you'd need `--with-arm-fpu=vfp` and a different toolchain.

---

## Adjusting the Node major version

Edit `NODE_MAJOR` in `.github/workflows/build-node-armv7.yml` and push. The cron will then track the new major.
