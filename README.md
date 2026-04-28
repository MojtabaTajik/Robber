# Robber — DLL Hijack Scanner

Free, open source tool for finding DLL hijacking opportunities in Windows executables. No third-party dependencies.

---

## What it does

Windows loads DLLs by searching a fixed set of directories in order — the executable's own directory first, then System32, Windows, PATH entries. If a DLL isn't found in a system directory, an attacker who can write to an earlier directory in that chain can drop a malicious copy and have it loaded instead.

Robber walks a directory tree, checks each executable's import table against what's actually on disk, and tells you which ones are worth looking at and why.

---

## GUI usage

Point it at a directory, hit **Scan**. Results show up in the tree as they're found — expand any executable to see which DLLs are hijackable, what methods they export, and the full search order with writability flags for each directory.

The **Color Config** panel controls the thresholds for Best/Good/Bad ratings:
- **Best** (green) — few imported DLLs, small binary. Easy to build a proxy DLL that stubs everything out.
- **Good** (yellow) — moderate complexity
- **Bad** (red) — lots of imports or large binary, harder to proxy without crashing the app

Use the filters to narrow results by architecture, signing status, severity, or whether the executable's directory is actually writable. Hit **Export** when done to save as JSON or CSV.

Settings and the last scan path are remembered between sessions.

---

## CLI

```
Robber.exe --path <dir> [options]
```

```
--path <dir>               Directory to scan (required)
--output <file>            Write to file (.json or .csv). Default: stdout
--image-type any|x86|x64
--sign any|signed
--rate any|best|good|bad
--write-perm               Only show results in writable directories
--best-dll-count <n>       (default: 2)
--best-exe-size <n>        KB threshold (default: 10240)
--good-dll-count <n>       (default: 5)
--good-exe-size <n>        KB threshold (default: 51200)
--help
```

Progress goes to stderr, results to stdout — pipe-friendly.

```bash
Robber.exe --path "C:\Program Files" --rate best --output hits.json
Robber.exe --path "C:\Program Files" | jq '.[].exePath'
Robber.exe --path "C:\Tools" --sign signed --write-perm
```

---

## A few things worth knowing

- System DLLs (System32, SysWOW64, Windows\System) are excluded automatically — no false positives from redistributable runtimes like `msvcr120.dll`
- Both standard and delayed imports are scanned
- Executables requiring elevation (`requireAdministrator` / `highestAvailable`) are flagged — a hijack on an elevated process is a privilege escalation, not just code execution
- The search order tree shows exactly which directories Windows would check and which of those you can write to

---

## Building

Delphi XE2 or later. Open `Robber\Robber.dproj`, build. Nothing else needed.
