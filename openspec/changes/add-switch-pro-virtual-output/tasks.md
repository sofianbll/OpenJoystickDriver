# Tasks

Each task is local implementation work after approval. Source-derived fixtures and fake backends establish protocol behavior, not macOS or PowerA compatibility.

Verification decision (2026-11-06): the repository requires Swift 6.4.0 exactly, while the sole installed Xcode at `/Applications/Xcode.app` provides Apple Swift 6.4.2. `Scripts/Platform/environment.sh` rejects it before compilation. Sofian approved preparing the patch and tests without installing another Xcode or changing the pin, with compilation and Swift test verification deferred to compatible CI after human review and separate publication approval. Local static checks do not replace execution evidence; a task closes only when its required checks pass. No compiler check is bypassed.

CI authorization (2026-11-06): Sofian approved a public `sofianbll/OpenJoystickDriver` fork, committing and pushing this patch, and GitHub Actions validation on a separate CI branch that may export generated snapshots and reports. The compiler pin stays unchanged. Each run is limited to 45 minutes and each problem to two repair cycles. No upstream pull request, tag, release, signing credentials, app installation or virtual-device activation is authorized. Stop if the required Swift version or access is missing.

## 1. Licensed reference and independent fixtures

- [x] 1.1 Record the pinned libvirtualhid paths, symbols, hashes, MIT assignment and retained notices in `docs/development/compatibility-sources.md` and the applicable license bundle. Verify every adapted file traces to `4847ea017f02115a02f57bd9372c0d2d8fe7c06f` and no broker code or dependency is included.
- [x] 1.2 Add source-derived Switch Pro descriptor, core input, handshake and SPI/ACK fixtures with provenance under the existing packet fixtures. Verify expected bytes are fixed independently of the Swift encoder and the fixture documentation identifies them as synthetic rather than hardware captures.

## 2. Nintendo reports and host replies

- [x] 2.1 Implement the Nintendo descriptor and core input packer under Kit `Output/HID/Nintendo/`. Verify `SwitchProReportTests` covers all face-button positions, shoulders, triggers, eight D-pad directions, stick centers/extremes, Home/Capture and neutral/release against the independent fixtures.
- [x] 2.2 Implement bounded USB initialization, device-information, report-mode and calibration handling with per-device counters and an explicit supported-command list. Verify `SwitchProHostReportTests` covers expected replies, current held controls, unsupported modes/commands, truncation, report-ID mismatch, SPI bounds and oversized requests. Document accepted no-op controls and excluded physical features with the source record.
- [x] 2.3 Extend the existing host-report boundary and ordered sender for protocol replies without a physical-output command. Verify fake-backend dispatcher tests cover reply ordering, two devices, close during a queued reply, no post-close writes and unchanged Xbox rumble/Generic rejection behavior.

## 3. Opt-in profile and all consumers

- [x] 3.1 Add `SwitchPro` / `switch-pro`, the authored and bundled virtual-device record and necessary Nintendo identity presentation. Keep automatic selection unchanged. Verify profile resolution, strict decoding, identity, representable controls, selector and persistence tests; keep all existing profile byte fixtures unchanged.
- [x] 3.2 Extend existing virtual-device, endpoint and CLI-output schemas and their constrained consumers, including BridgeCore if required by its profile vocabulary. Verify schema/Swift agreement, unknown-name rejection, endpoint profile listings, CLI selection and snapshot tests, including schema-rejection fixtures when a document fails Swift validation.
- [x] 3.3 Exercise the existing `virtual feed` with `switch-pro` through a fake publisher and make the existing app picker expose the profile. Verify service feed, CLI and presentation-model tests. Add and review any required locale keys under `LOCALIZATION.md`; do not create another picker or inline UI strings.
- [x] 3.4 Verify SDL/W3C export against the Nintendo descriptor and packed fields, reporting unmapped fields honestly rather than inventing bindings. Update mapping tests and the existing equivalence snapshot with an explicit profile addition only. Add user documentation to `wiki/Playing-Games.md` and `wiki/Command-Reference.md`, update the README profile list and changelog, and label consumer compatibility not verified.

## 4. Integration and contribution evidence

- [x] 4.1 Run the focused Nintendo, host-report, profile, mapping, CLI, endpoint, feed and presentation-model tests with no signing assets or live device activation. Verify the unchanged personas and delivery regressions pass; record exact commands, versions, failures and skipped checks.
- [ ] 4.2 Run `just check` once on the complete implementation and rerun only failed checks after bounded repairs. Verify `git diff --check`, schema/profile validation, parser compatibility and the full local check report, without bypassing hooks or installing host tools implicitly.
- [x] 4.3 Add a hardware-evidence checklist in `docs/testing/` for a maintainer-signed build: synthetic Nintendo feed, HID enumeration, GameController enumeration plus live controls, separate Steam/SDL tests, Home/Capture and teardown. Verify the checklist makes no PowerA success claim and identifies the remaining physical-admission work.

## Local verification record (2026-11-06)

- Written: Nintendo input/replies, per-entry timing and bounded native input, the opt-in profile and records, CLI/feed/endpoint/schema integration, Nintendo presentation, focused tests and user/source documentation. Local checks do not verify Swift execution; the CI record below names the executed checks.
- Provenance inspection passed: five freshly fetched pinned source/license SHA-256 hashes match the source record; the bundled MIT notice is byte-identical; the Swift descriptor and fixture equal the pinned 203-byte descriptor; all nine literal golden packets have 64 bytes. Calibration fixtures explicitly encode center 2048, positive extent 2047 and negative extent 2048.
- `./Scripts/ojd check schemas`: blocked while preparing `OJDRepositoryTool` by the exact Swift pin (installed 6.4.2, required 6.4.0); no Swift compilation occurred. Its repository-local schema-validator environment was prepared by the standard command.
- Direct Draft 2020-12 checks passed for all 15 schema documents, both equal Nintendo persona records, the endpoint `FeedRequest` and rejected alternate persona spellings. This is schema-only evidence, not Swift/schema agreement.
- `python3 Scripts/Quality/check_localization_keys.py`: passed, with its reported dynamic-key scan limits. No locale values or keys were added or changed; Nintendo control names reuse the existing localized semantic and face-button keys.
- `python3 Scripts/Quality/check_neutral_core_imports.py`: passed.
- Xcode's `swift-format lint --strict`: passed for all 32 changed/added Swift files. Pinned Biome `ci`: passed for all five changed/added JSON files. These do not type-check or execute Swift.
- `git diff --check` and strict OpenSpec validation of `add-switch-pro-virtual-output`: passed. Task checkboxes retain their required execution/snapshot gates.
- `/usr/bin/env just check`: failed with exit 127 because `just` is not installed/on PATH. No host tool was installed, and no replacement full-suite success is claimed.
- Locally, Swift build, focused Swift tests, parser compatibility, SwiftLint, app launch, visual UI inspection and signed/hardware checks were not run. Xcode, compiler pins, permissions, entitlements and physical admission are unchanged. CI execution is recorded separately below.
- `Tests/EquivalenceSnapshots/sdl-mappings.txt` and `output-mapping.txt` use the exact Swift-generated artifacts from CI run 42134512814. Each adds its Nintendo section only, preserving all existing persona sections byte-for-byte. Full-suite validation remains required before presenting this as fully checked.

## CI verification record (2026-11-06)

- First run: [42133432461](https://github.com/sofianbll/OpenJoystickDriver/actions/runs/42133432461), CI commit `c9e1d89ad9ca764ae94ca352f7af6cb6b40e99be`, source commit `e390544a60d07c94aaf006845b9adfce2e86f4c2`. macOS 27.0.1 (`26A434`), Xcode 27.0 (`27A266a`), Apple Swift 6.4 (`swiftlang-6.4.0.34.1`). The version gate and warning-free package/test build passed.
- Focused results: 214 of 215 reported tests passed. `SwitchProReportTests`, `SwitchProHostReportTests`, `ReportSenderTests`, `VirtualHostReportTests`, profile/selector/persistence, mapping, feed, presentation and publisher-property suites passed. The only reported failure is the CLI export's literal three-entry hint expectation; the four-profile contract requires a fourth `true`, fixed in `072c4bcad` without weakening its assertions. CLI hint expectation repair cycle: 1/2.
- Second run: [42134512814](https://github.com/sofianbll/OpenJoystickDriver/actions/runs/42134512814), CI commit `8f484c1f612d57ab5226fcd7d23fd84ccd9145cc`. The warning-free build, all 215 focused tests, all 12 equivalence tests and the Nintendo-only snapshot guard passed. The schema gate validated all 15 schemas and all four virtual devices against Swift, plus the existing record and report fixtures.
- `just check` stopped in SwiftLint on three trailing-closure style violations in `ReportSenderTests.swift` and `VirtualHostReportTests.swift`. The three call sites use trailing closures without changing assertions or behavior. Style repair cycle: 1/2. The remaining full-suite stages have not yet passed.
- The two downloaded snapshot artifacts were checked byte-for-byte against the local import; headers and the three existing persona sections are unchanged. The notice is retained in both Kit's license resource and `THIRD_PARTY_NOTICES.md`. No signing assets or live HID device were used.
- Third run: [42136855445](https://github.com/sofianbll/OpenJoystickDriver/actions/runs/42136855445), CI commit `dde2302f10f4a8671b17a78e723e277ba25cecef`, source commit `48551d03a`. The warning-free build, focused tests, equivalence generation and snapshot guard passed. SwiftLint rejected the same three call sites under `multiple_closures_with_trailing_closure`. Each uses a named `@Sendable` predicate, matching the existing host-handler tests and leaving one literal trailing closure. Style repair cycle: 2/2; stop if this check still fails. The CI continuation starts with SwiftLint and runs the remaining `check-fast` and `check` recipe bodies with `just --no-deps check-fast check`, retaining the preceding run's successful prerequisite evidence.
- Fourth run: [42138391335](https://github.com/sofianbll/OpenJoystickDriver/actions/runs/42138391335), CI commit `bee3ad5519e70a3c4e2691b5ffda5029896b3dbc`, source commit `a0ee7a13b`. SwiftLint passed. Catalog/error/vocabulary reproducibility, profile validation, localization and core-import checks passed. Repository-script tests passed 543/544; `test_ci_runs_the_canonical_list` rejected the CI-only wrapper's altered workflow. The contribution's unchanged workflow passes all three `test_check_list.py` tests locally. CI harness repair cycle: 1/2; checkout pins the contribution commit, keeping its canonical workflow intact, then reruns the failed check-list tests and the remaining `check` recipe body. No test exemption or production-source change is needed.

## Workflow follow-up

- Show the exact diff and proposed external text to Sofian before creating an issue, comment, fork or pull request.
- Ask the maintainer to accept the fourth persona and reconcile the in-flight `platform-neutral-redesign` persona contract before upstream integration.
- Request a maintainer-signed tester build when appropriate. Installation, permissions, real virtual-device activation and physical controller tests require separate consent.
- Investigate the PowerA `0000:0000` admission path separately with precise matching and regression tests, never a global vendor-zero override.
- Archive only after the implementation and its offline checks are complete, retaining unverified consumer/hardware status explicitly.
