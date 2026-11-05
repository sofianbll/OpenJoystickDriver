# Proposal

## Why

OJD can publish Xbox and generic virtual controllers, but cannot publish Nintendo Switch Pro reports. A selectable Switch Pro output would preserve the Nintendo-facing identity without a separate paid broker, using the permissively licensed protocol implementation in libvirtualhid as a reference.

## What Changes

- Add the explicit `SwitchPro` persona (`switch-pro` on the CLI), publishing USB `057E:2009` through OJD's existing user-space HID publisher.
- Adapt the MIT-licensed Switch Pro descriptor, core input packing and initialization replies from a pinned libvirtualhid revision, with copyright and license notices retained. Do not copy its differently licensed macOS broker or add libvirtualhid as a dependency.
- Carry buttons, sticks, D-pad, digital triggers, Home and Capture. Answer the host's bounded initialization and calibration requests through the existing ordered report sender.
- Make the persona available to the existing app picker, CLI, virtual feed and endpoint. Keep automatic selection and all existing personas unchanged.
- Add byte-level fixtures, negative request tests, delivery regressions, schema coverage and an explicit signed-build hardware checklist.

Out of scope: physical PowerA admission at `0000:0000`, motion forwarding, physical haptics/LED forwarding, a new driver, signing assets, permission changes, installation and publication. A named response to an initialization command is not a claim that its physical feature is implemented.

## Capabilities

### New Capabilities

- `switch-pro-virtual-output`: Nintendo Switch Pro virtual identity, core reports, host initialization, explicit selection and evidence boundaries.

### Modified Capabilities

None in the synchronized specs. Delivery and ownership requirements are preserved. The in-flight `platform-neutral-redesign` change limits personas to three, so a maintainer must approve expanding that contract before upstream integration. Its artifacts are not silently rewritten here.

## Impact

- Base: `feat/0.6.0-alpha.2`, inspected at `dcae3ceb555326bb38da979de0a2dd249c48ef8d`.
- Kit output profiles, Nintendo report format/session handling, shared host-report callbacks and identity presentation.
- Authored and bundled virtual-device data, existing virtual-device/CLI/endpoint schemas, affected tests and snapshots.
- README, user documentation and a source/license record. Reuse the existing picker rather than add another UI.
- No change to `Host.entitlements`, the Xbox USB DEXT, controller catalog or source-admission rules.
- Source-backed behavior can be tested without Apple signing assets. GameController, Steam and PowerA compatibility remain unverified until separate signed-build tests.
