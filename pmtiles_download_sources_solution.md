# Solution & Research Report: Direct PMTiles Download Sources

**Objective:** Answer whether TrailPulse can download PMTiles country and regional maps directly from public/open sources without you needing to pay for or host files on Cloudflare, AWS, or private servers.

---

## 1. The Reality of Public PMTiles Sources Today

To understand what is possible, here is how the open-source map ecosystem currently distributes PMTiles:

### How Protomaps & OpenStreetMap Work
1. **The Source File is Global:** Protomaps publishes one massive **120 GB World Planet file** (hosted at `build.protomaps.com` and `data.source.coop`).
2. **They Do Not Host Pre-Cut Countries:** Protomaps, Geofabrik, and OpenStreetMap **do not** maintain pre-split, standalone `.pmtiles` download links for each European country and region on public servers.
3. **Why the Phone Cannot Extract Live from the 120 GB File:**
   - The CLI command `pmtiles extract` works by firing **thousands of parallel HTTP byte-range micro-requests** across the internet to piece together a country file.
   - Protomaps' public server rules **strictly prohibit mobile apps from hotlinking or hammering `build.protomaps.com` with thousands of range requests** (they will automatically rate-limit and IP-block the app).
   - If phone signal drops for even half a second during those 10,000 micro-requests, the download fails or corrupts.
4. **What Mobile Apps Require:**
   - A mobile phone needs a clean, single-URL file download (e.g. `GET .../romania.pmtiles` or `GET .../germany_bavaria.pmtiles`) that supports standard pause, resume, and high-speed streaming.

---

## 2. The Solutions: How to Get Direct Downloads Without Hosting or Paying for Servers

If you do **not** want to sign up for Cloudflare, configure AWS S3, or pay for web hosting, here are the **4 practical solutions**:

---

### Solution A (Recommended): Free GitHub Releases CDN (Zero Cost, Zero Server Maintenance)

You don't need any hosting service, credit card, or cloud infrastructure. You can use **GitHub Releases**:

* **How it works:**
  - GitHub allows uploading release assets up to **2 GB per file** completely free.
  - Downloads are distributed across GitHub's global enterprise CDN (Fastly / Azure) with high bandwidth and zero egress fees.
  - The phone app downloads directly via standard URLs:
    ```
    https://github.com/YOUR_USERNAME/trailpulse-maps/releases/download/v1.0/romania.pmtiles
    https://github.com/YOUR_USERNAME/trailpulse-maps/releases/download/v1.0/germany_bavaria.pmtiles
    ```
* **How the files are created:**
  - We can set up a simple, free **GitHub Actions** script that runs in the repository.
  - When triggered, GitHub's own cloud servers run `pmtiles extract` against the open Protomaps planet file, create the European country files, and automatically attach them to the release.
* **Cost:** **$0.00 forever.**
* **Maintenance:** **Zero servers to manage.** No Cloudflare, no AWS, no billing.

---

### Solution B: Internet Archive (archive.org) — 100% Free Public Open-Data Repository

The **Internet Archive** is a global non-profit dedicated to hosting open-access data, including OpenStreetMap archives:

* **How it works:**
  - Anyone can create a free account and upload open-source datasets (like OSM country extracts in PMTiles format).
  - It generates permanent, direct HTTP download URLs with resume support:
    ```
    https://archive.org/download/trailpulse_osm_europe/romania.pmtiles
    ```
* **Pros:** Free, no bandwidth caps, no credit card, permanently available.
* **Cons:** Download speeds can be slightly slower than GitHub's commercial CDN.

---

### Solution C: Local Device File Import / Sideloading (Works Right Now with Zero Internet Hosting)

For immediate use and testing, the app doesn't even need an online download URL:

* **How it works:**
  - You generate or download `romania.pmtiles` once on your computer.
  - Copy it to your phone (via USB cable, Google Drive, AirDrop, or WhatsApp/Telegram).
  - Inside TrailPulse's Offline Maps screen, tap an **"IMPORT LOCAL MAP FILE"** button (using the `file_picker` library already installed in TrailPulse).
  - TrailPulse instantly registers the file into `app_flutter/offline_maps/`, detects the bounding box, and immediately enables offline navigation.
* **Pros:** 100% independent of any server or internet.

---

### Solution D: Direct User-Configurable Custom Endpoint

In TrailPulse's settings or Offline Maps screen:
* Provide a default URL pointing to the GitHub / public repository.
* Allow advanced users to enter their own custom URL base (e.g. `https://my-server.com/maps/{region}.pmtiles`).

---

## 3. Comparison Summary

| Approach | Server Required? | Cost | Bandwidth Limit | Effort |
|---|---|---|---|---|
| **Direct from Protomaps build server** | None | Free | ❌ **Forbidden by TOS** (will get IP blocked) | Unusable for mobile |
| **A. GitHub Releases CDN** | **None** | **$0.00** | Generous (Fastly global CDN) | **Easiest & most reliable** |
| **B. Internet Archive (archive.org)** | **None** | **$0.00** | Unlimited (public archive) | Very easy |
| **C. Local Import / USB** | **None** | **$0.00** | Offline (cable / file transfer) | Instant |
| **Private Cloudflare / AWS** | Yes (account setup) | Free tier / cheap | High | More setup |

---

## 4. Recommended Path Forward for TrailPulse

1. **In the App:**
   - Configure the download manager to download country & regional packs from a designated **GitHub Releases CDN** (or Archive.org) where pre-cut `.pmtiles` packages reside.
   - Include an **"Import Map File"** button so you can test any `.pmtiles` file directly on your device right away without waiting for any upload.
   - Build a **Simulation / Demo Mode** in the download manager so the UI, progress bars, cancellation, deletion, and storage calculation can be thoroughly verified even before live remote files are published.

2. **No Code Changed Yet:**  
   As requested, no code has been modified. Please review these options and confirm if **Solution A (GitHub Releases CDN) + Solution C (Local File Import)** matches your vision!
