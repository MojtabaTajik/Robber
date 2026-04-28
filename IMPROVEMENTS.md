# Robber — Improvements & Feature Roadmap

## What's Good (Don't Touch)

- The PE parser library is solid and comprehensive — handles 32/64-bit, delayed imports, exports, resources, relocations.
- Zero-dependency approach is a genuine strength for a security tool.
- `GetHijackRate()` severity classification (Best/Good/Bad) is a smart, practical UX decision.
- Write-permission check filters out theoretical-only vulnerabilities — good threat modeling.

---

## Completed

### ✅ 1. Delayed imports scanned (`feature/delayed-import-scanning`)
`DLLHijack.pas` now iterates `Img.ImportsDelayed.Libs` in both `GetImportedDLL` and `GetDLLMethods`. Case-insensitive deduplication via `DLLListContains`. Fixed `SameText` comparison for DLL names (was raw `<>`). Removed dead `rva` bookkeeping.

### ✅ 2. Multi-threaded scanning (`feature/threaded-scanning`)
New `ScanThread.pas` — all PE parsing, signature checks, and method collection runs off the main thread. Results posted back via `TThread.Synchronize` so the TreeView updates progressively. Scan button toggles to Cancel. `FormClose` terminates any running thread. Two-pass scan design eliminated — methods collected in same pass as hijack detection.

### ✅ 3. Settings persisted to INI (`feature/persist-settings`)
All filter radio groups, spin edit thresholds, and last scan path saved to `Robber.ini` (next to exe) on close, restored on startup. Scan button re-enabled automatically if a path was remembered.

### ✅ 4. CSV / JSON export (`feature/export-results`)
Export button (disabled until scan completes) opens a save dialog. JSON: nested exe → dlls → methods. CSV: flattened, one row per method. Both UTF-8. Results accumulated in `FResults: TList<TScanResult>` as they arrive from the thread.

### ✅ 5. System32 allowlist — false positive filter (`feature/system32-allowlist`)
`StripSystemDLLs` removes any hijackable DLL that also exists in `System32`, `SysWOW64`, or `System\`. System dirs computed once before the scan loop. Eliminates redistributable DLLs (e.g. `msvcr120.dll`) that were producing false positives.

### ✅ 6. Signer company name in results
Already present in the original codebase and preserved through the threading rewrite. TreeView shows `Sign by: <Company>`, CSV has a `Signer` column, JSON has a `"signer"` field.

### ✅ 7. CLI mode (`feature/cli-mode`)
`CLIRunner.pas` — when `--path` or `--help` is detected at startup, the GUI is skipped entirely and a synchronous headless scan runs. `AttachConsole(ATTACH_PARENT_PROCESS)` inherits the caller's console without spawning a new window. Progress to stderr, results to stdout (clean for piping). All GUI filters and the System32 allowlist apply equally.

```
Robber.exe --path "C:\Program Files" --rate best --output hits.json
Robber.exe --path "C:\Program Files" | jq '.[].path'
Robber.exe --help
```

---

## Remaining / Future

### Per-file status during scan (was gap #5)
Now done as part of threading — status bar shows `Scanning [n/total]: filename` per file.

### UAC / privilege level check
Show whether the executable runs elevated (requires UAC). An elevated process being hijackable is much higher severity. Manifest is embedded in PE resources — the parser already reads resources.

### Side-by-side (SxS) manifest awareness
Executables with `<dependentAssembly>` in their manifest use WinSxS, bypassing the standard DLL search order. Currently treated identically to everything else — produces false positives.

### Before/after install diff
Run a scan, install software, run again, diff. Shows exactly what new hijack surface an installer introduced. Would make Robber genuinely unique among similar tools.

### Full Windows DLL search order per result
For each vulnerable DLL, show exactly which directories Windows would search in order and mark which are writable. Makes output actionable for pentesters writing reports.

### 64-bit build
Project is Win32 only. The PE parser handles 64-bit PE files fine but Robber itself is a 32-bit process.

### Tests for PE parser
The 63-file PE parser library has zero automated tests. A handful of known-good PE file fixtures would catch regressions.

---

## Branch history

| Branch | What |
|--------|------|
| `master` | Original codebase |
| `feature/delayed-import-scanning` | Fix #1 |
| `feature/threaded-scanning` | Fix #2 + gap #5 |
| `feature/persist-settings` | Fix #3 |
| `feature/export-results` | Fix #4 |
| `feature/system32-allowlist` | Fix #5 |
| `feature/cli-mode` | Fix #7 |
