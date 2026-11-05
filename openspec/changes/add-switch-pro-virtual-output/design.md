# Design

## Context

See [proposal.md](proposal.md) for motivation and [the capability delta](specs/switch-pro-virtual-output/spec.md) for the behavior contract.

The inspected development base is `dcae3ceb555326bb38da979de0a2dd249c48ef8d`. `VirtualHIDProfileID.makeProfile()` resolves three personas from bundled JSON. `VirtualGamepadReportFormat` builds input bytes, while `ConsumerOutputCodec` only decodes Xbox rumble. `UserSpaceHostReportHandler.setReport()` expects a physical-output command and publishes no response bytes. Nintendo initialization therefore needs a response path, not an identity substitution.

The existing app picker enumerates `VirtualHIDProfileID.allCases`. The CLI, virtual feed and endpoint already share the profile vocabulary. `VirtualHIDProfileSelector.automaticOrder` is explicitly SDL then Generic. Physical ownership is a separate policy and is not changed by choosing an output profile.

## Goals / Non-Goals

**Goals:** reuse OJD's publisher, queue and selector, port only the Nintendo codec and bounded protocol replies, and preserve existing personas byte-for-byte.

**Non-Goals:** a second runtime service, a C++ dependency, an app redesign, changing automatic selection or treating this output as a PowerA admission fix. Physical motion and feedback need separate source-to-output work and must not be advertised by this slice.

## Decisions

### 1. Port the licensed codec, not the broker

Pin libvirtualhid to `4847ea017f02115a02f57bd9372c0d2d8fe7c06f` (`v2026.1104.2126.25`). Its [license map](https://github.com/LizardByte/libvirtualhid/blob/4847ea017f02115a02f57bd9372c0d2d8fe7c06f/LICENSES/license-map.md) assigns the cross-platform library and shared protocol code to MIT, while `src/platform/macos/broker/` is LB-SAL. The [MIT text](https://github.com/LizardByte/libvirtualhid/blob/4847ea017f02115a02f57bd9372c0d2d8fe7c06f/LICENSES/MIT.md) credits LizardByte, 2026. OJD itself is MIT.

Adapt the descriptor and core packer from `src/core/profiles.cpp` and the bounded initialization/calibration methods from `src/shared/switch_pro_protocol.hpp`. Preserve applicable notices with substantial adapted code and in OJD's license bundle. Record exact symbols, hashes and source-derived fixture provenance in `docs/development/compatibility-sources.md` during implementation. Do not copy broker implementation, licensing, entitlement or installation code.

Alternative rejected: link libvirtualhid and its broker. It adds a second signed service and a paid machine license for functionality OJD's publisher already supplies.

### 2. Add one explicit persona

Use `SwitchPro` / `switch-pro`, a Nintendo layout and USB `057E:2009` with version `0210`. Put operational identity in `Resources/VirtualDevices/virtual-device.switch-pro.json` and its bundle copy, consistent with existing personas. Keep `automaticOrder` unchanged. Reuse the picker and override persistence. Use position-based controls, with Nintendo B/A/Y/X at South/East/West/North. Preserve Home and Capture as distinct controls.

Add Nintendo identity presentation only where needed by the existing presentation model, with the existing gamecontroller symbol as a fallback. Any added UI wording follows all shipped locale catalogs. Extend existing virtual-device, endpoint and CLI-output contracts together, including the BridgeCore client vocabulary where it constrains profile names. Unknown names must still fail.

The active `platform-neutral-redesign` delta and `VirtualHIDProfileTests` deliberately restrict the profile count. This proposal requests a fourth persona rather than assuming approval. Do not edit that change's decision history or claim the maintainer accepted it. Reconcile its persona contract as part of an approved upstream integration.

### 3. Separate deterministic bytes from a per-device protocol session

Put Nintendo packing and response logic under Kit `Output/HID/Nintendo/`. The packer takes explicit state and counter values so fixture and mapping probes are deterministic. Runtime counters and negotiated input state belong to the entry created by `UserSpaceOutputDispatcher.createEntry`, not a global static or a shared format instance.

Adapt the existing host-report boundary to return an optional physical-output command plus zero or more protocol reply reports. Route replies through the same `UserSpaceReportSender` as normal input. Xbox requests retain their command-only result and existing errors. Generic remains input-only. Do not create a separate callback queue or write directly to IOKit from the Nintendo codec.

Use the latest entry input state in `0x21` responses. Reusing libvirtualhid's neutral-state helper verbatim would spuriously release held controls, so retain the protocol framing and calibration but build the control-state prefix from the actual state. Clock/counter advancement must not break report deduplication or deterministic mapping generation. A separately required steady reporting cadence needs an explicit bounded lifecycle, not an unowned timer.

### 4. Name and validate the supported dialogue

Support the USB handshake (`0x80` / `0x81`), device information and SPI calibration (`0x01` / `0x21`), and the report-mode and initialization controls needed by the pinned contract. Document the accepted subcommands. Bound each command's input and response length before reading bytes or allocating data. SPI addresses select only fixed emulated calibration regions and cannot read host memory or files.

Do not port the reference's catch-all acknowledgement as permission to accept arbitrary commands. Unsupported requests return the existing unsupported error, malformed requests retain their named failure, and oversize requests fail rather than truncate silently. Explicitly accepted no-op initialization controls must not advertise motion, physical rumble or LEDs as working. The initial input scope is the core `0x30` layout, with correct handling or rejection of other requested modes.

### 5. Test the protocol independently of device creation

Use source-derived golden packets with an origin record, not expected bytes built by the Swift implementation under test. Cover every button, hat, axis extreme, neutral/release, Home/Capture, handshake, ACK/SPI data, short/oversize/unknown requests, held controls during replies, separate controller sessions and closure with queued work. Keep existing Xbox/Generic packets and automatic selection unchanged.

Exercise `switch-pro` in the existing virtual-feed tests through fake publishers, plus profile persistence, schemas, endpoint profiles, mapping export and snapshot coverage. The generic mapping generator reads HID usages; Nintendo vendor-packed fields may need to be reported as unmapped rather than given invented SDL/W3C bindings. Consumer-specific HIDAPI parsing is a separate observation.

Run focused checks, then `just check` once before a publishable contribution. Do not start the service or tests that create real virtual devices as part of offline verification. Installing or launching a signed build and interacting with controllers needs a separate user agreement.

## Risks / Trade-offs

- The maintainer rejects a fourth persona → keep this an explicit proposal and show the local diff before any external publication.
- GameController does not bind or decode the Nintendo output → mark compatibility not verified and test enumeration and live inputs separately on a signed build. `GCIOMatchVirtual` and `supportsHIDDevice` are not acceptance evidence.
- Nintendo protocol state adds races to shared delivery → one per-entry session, shared sender and regression tests for closure, held buttons and multiple devices.
- Reference behavior includes assumptions → record fixture origin and improve bounds/state handling instead of blindly translating the C++.
- PowerA remains unreadable by OJD's physical admission path → keep a separate, narrowly matched admission investigation. Do not relax vendor-zero rules globally.

## Migration Plan

No migration or default change. Add an opt-in profile while preserving existing stored choices and strict rejection of unknown document values. Do not add compatibility aliases. Users of an authorized future build can return to Automatic through the existing reset action. No installation, signing or publication is part of this planning change.

## Open Questions

- A maintainer-signed build must establish which consumers accept the profile and whether Home/Capture reach a focused app. These are evidence gates, not assumptions that prevent preparing the codec.
- The actual PowerA descriptor, exact matching strategy and physical output behavior require their own separately scoped work before end-to-end support can be claimed.
