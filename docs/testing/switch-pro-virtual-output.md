# Switch Pro virtual output

This checklist separates source-backed report encoding, virtual HID publication and actual consumer input.

## Evidence status

- The implementation reference is libvirtualhid `4847ea017f02115a02f57bd9372c0d2d8fe7c06f`.
- Packet fixtures are source-derived synthetic data, not genuine controller captures.
- A real Switch Pro virtual HID device has not been created or tested.
- End-to-end GameController, Steam/SDL and browser input are not verified. Partial PowerA observations are listed under Personal-build observations.
- The repository pins Swift 6.4.0. Local Swift compilation and tests are not verified with that toolchain.
- Offline gates passed through cumulative CI execution on macOS 27.0.1 / Xcode 27.0 / Swift 6.4.0: warning-free compilation, focused tests, schemas, lint, catalog/profile checks, native tools, unsigned DriverKit, parser compatibility and equivalence snapshots. The three existing persona snapshots remain byte-identical.
- [Full-suite run 42139152572](https://github.com/sofianbll/OpenJoystickDriver/actions/runs/42139152572) passed 4,010/4,011 Swift tests. [CLI rerun 42141395123](https://github.com/sofianbll/OpenJoystickDriver/actions/runs/42141395123), on source `747ff1ad8964ebf6f209ee0f030a4fb2515efe1f`, passed all 10 launch tests, including that run's sole failing regression, with the four-profile fixture. No uninterrupted green full-suite run on the final tree or runtime-device result is claimed.

## Offline checks

Use the repository's supported toolchain. Run the focused Nintendo report, host-report, dispatcher, profile, mapping, feed, CLI, endpoint and presentation tests, then `just check`. Record the commands, exact tool versions, failures and skipped tests. Generate the Nintendo mapping snapshots through `./Scripts/ojd snapshots write` and inspect their diff before treating integration checks as complete. Preserve the existing persona sections byte-for-byte.

Offline checks need no Input Monitoring, Accessibility, signing credentials, running OJD service or physical controller. A fake publisher result is not runtime device-creation evidence.

## Signed-build prerequisites

Use a maintainer-signed test build with the existing virtual HID entitlement. Inspect its signature and provisioning first. Obtain the user's agreement before installing, launching, granting permissions, creating a virtual controller or interacting with hardware. Keep SIP and AMFI enabled. Do not change the USB DEXT, pairing, firmware or Apple drivers.

## Synthetic Nintendo feed

1. Record the complete OJD build identity, macOS build, signing result and active permissions.
2. Open one `ojd virtual feed --as switch-pro` session with no physical source attached to that feed.
3. Check that HID enumeration reports USB `057E:2009` and Nintendo core reports.
4. Send one normalized control at a time, followed by an explicit neutral frame, including Home, Capture, every face button, sticks, D-pad and ZL/ZR.
5. Check GameController enumeration separately, recording whether a controller object appears and which profile it exposes.
6. Observe actual changes through GameController in a focused test app, including neutral/release and held buttons during initialization requests.
7. Test Steam/SDL separately and record the consumer version and input backend, without treating its result as GameController evidence.
8. End the feed and verify the virtual controller disappears and no control remains held.
9. Repeat connection and teardown.
10. Test two independent virtual feeds and close them separately.

`supportsHIDDevice = true`, a matching system personality or a displayed product name alone does not pass the GameController test. Record Home/Capture system gestures and focus constraints separately. Motion, physical feedback and battery telemetry are outside this output slice.

## PowerA follow-up

The reported PowerA appears as `Lic Pro Controller` with `0000:0000` over Bluetooth. OJD's HID admission has an exact exception for that VID, PID, product name and Bluetooth transport, so it seizes that device for descriptor-driven input instead of leaving it to macOS. Other `0000:0000` devices do not match. The isolated identity test passes; correct physical input mapping, GameController enumeration, Steam/SDL, feedback and teardown remain not verified.

## Personal-build observations

Evidence date: 2026-11-06. Operator observations and direct inspection establish different results:

- The operator reports a successful Xcode app build and launch. The local Xcode supplies Swift 6.4.2; the repository's supported-toolchain checks require 6.4.0 and stop before compilation.
- The inspected app executable is dated 13:06:49 Europe/Paris. Its strict code-signature verification passes, but its signed entitlements omit `com.apple.developer.hid.virtual.device` and it contains no embedded provisioning profile. This build does not establish virtual-device publication.
- The app lists `Lic Pro Controller` over Bluetooth as Generic HID. Its log reports descriptor-driven decoding for `0000:0000`. The operator observes several controls in Input Test but reports incorrect mappings.
- Physical selection matches accept zero in both the decoder and JSON Schema; published virtual identities still require a nonzero vendor ID. A saved model-level SwitchPro selection for `0000:0000` supplies the regression reproducer. The operator reports that selecting SwitchPro works after rebuilding. This is selector evidence, not consumer input evidence.
- A stored unit-level SDLCompatible selection takes precedence over the model-level SwitchPro selection. These settings are user data, not bundled defaults.
- The operator cannot locate the desired gamepad destinations in the assignment picker. Successful remapping is not observed. Physical mapping and Apple-authorized virtual publication remain separate prerequisites for an end-to-end test.

## Resuming from a clone

The personal development fork is `sofianbll/OpenJoystickDriver`, with `feat/switch-pro-virtual-output` as its default branch. Clone it without a local backup or a sibling working tree:

```bash
git clone https://github.com/sofianbll/OpenJoystickDriver.git
cd OpenJoystickDriver
```

The clone contains the PowerA admission, the zero-vendor profile-selection fix, the Switch Pro output, tests, schemas, source/license references and this evidence record. The open acceptance items are in [the change checklist](../../openspec/changes/add-switch-pro-virtual-output/tasks.md#5-zero-vendor-profile-persistence).

1. Select the Xcode toolchain that provides the repository's pinned Swift 6.4.0 for supported-toolchain checks.
2. Follow [Building from source](../development/building-from-source.md) to install the declared development dependencies with `./Scripts/ojd setup`.
3. Open `OpenJoystickDriver.xcodeproj` and select `OpenJoystickDriverApp` for the app. Configure your own Apple Development team in Signing & Capabilities when signing personally; no personal team identifier is committed.
4. Keep physical-input mapping tests separate from virtual HID publication. A local app build without Apple's virtual HID entitlement does not establish a working virtual controller. Follow [Signing](../development/signing.md) for authorized publication prerequisites.

Apple certificates, private keys, provisioning profiles and user controller settings are external personal assets, not source files. They are not exported into this repository. A clone restores the development project, not Apple's missing authorization or a validated PowerA mapping.

## Retained validation files

[The validation archive](evidence/switch-pro-validation-2026-11-06.tar.gz) contains 38 text files: CI logs, Swift-generated mapping snapshots, a signing-configuration template, the bounded cleanup record and a manifest of source and published SHA-256 hashes. It is independent of expiring GitHub Actions artifacts. Personal home paths and the local signing team identifier are redacted; Xcode window state, user-profile hashes and signing credentials are excluded. The signing template uses `YOUR_TEAM_ID` and is not applied automatically.

Archive SHA-256: `d747276995cfb38acc5d48d950cab01ee26c6f9fa1206dfe7b010bd6d32e541b`.

The archive retains failed checks as well as their passing reruns. It does not establish a passing final Swift suite or hardware compatibility. No generated build or dependency directory is required from the originating Mac.
