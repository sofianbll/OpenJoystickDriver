# Switch Pro virtual output

This checklist separates source-backed report encoding, virtual HID publication and actual consumer input.

## Evidence status

- The implementation reference is libvirtualhid `4847ea017f02115a02f57bd9372c0d2d8fe7c06f`.
- Packet fixtures are source-derived synthetic data, not genuine controller captures.
- A real Switch Pro virtual HID device has not been created or tested.
- GameController, Steam/SDL, browser and physical PowerA input are not verified.
- The repository pins Swift 6.4.0. Local Swift compilation and tests are not verified with that toolchain.

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

The reported PowerA appears as `Lic Pro Controller` with `0000:0000` over Bluetooth. The output persona does not change OJD's physical admission or ownership rules. Before connecting a real source, establish a precise descriptor/name/transport match and an isolated regression test. Never seize every device with vendor zero. Only after that source path is approved and tested can physical PowerA presses establish end-to-end support.
