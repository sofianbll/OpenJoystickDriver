// Provenance: libvirtualhid 4847ea017f02115a02f57bd9372c0d2d8fe7c06f;
// src/core/profiles.cpp make_switch_pro_report_descriptor; src/core/report.cpp
// pack_switch_pro_input_report, normalize_switch_stick_axis, write_switch_stick,
// write_switch_imu_sample and switch_battery_and_connection.
// Copyright (c) 2026 LizardByte. MIT License; see Resources/Licenses/libvirtualhid-MIT.txt.

import Foundation

/// Nintendo Switch Pro core input over 64-byte, numbered HID reports.
///
/// Face buttons retain physical position: South is B, East is A, West is Y and North is X. The
/// state's Y axes point down, while Nintendo's stick values point up. ZL and ZR are digital.
/// Motion fields contain the reference's fixed rest sample; no gyroscope state is forwarded.
public struct SwitchProHIDReportFormat: VirtualGamepadReportFormat {
  static let maximumReportSize = 64

  public let descriptor: [UInt8] = [
    0x05, 0x01, 0x15, 0x00, 0x09, 0x04, 0xA1, 0x01, 0x85, 0x30, 0x05, 0x01,
    0x05, 0x09, 0x19, 0x01, 0x29, 0x0A, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01,
    0x95, 0x0A, 0x55, 0x00, 0x65, 0x00, 0x81, 0x02, 0x05, 0x09, 0x19, 0x0B,
    0x29, 0x0E, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x04, 0x81, 0x02,
    0x75, 0x01, 0x95, 0x02, 0x81, 0x03, 0x0B, 0x01, 0x00, 0x01, 0x00, 0xA1,
    0x00, 0x0B, 0x30, 0x00, 0x01, 0x00, 0x0B, 0x31, 0x00, 0x01, 0x00, 0x0B,
    0x32, 0x00, 0x01, 0x00, 0x0B, 0x35, 0x00, 0x01, 0x00, 0x15, 0x00, 0x27,
    0xFF, 0xFF, 0x00, 0x00, 0x75, 0x10, 0x95, 0x04, 0x81, 0x02, 0xC0, 0x0B,
    0x39, 0x00, 0x01, 0x00, 0x15, 0x00, 0x25, 0x07, 0x35, 0x00, 0x46, 0x3B,
    0x01, 0x65, 0x14, 0x75, 0x04, 0x95, 0x01, 0x81, 0x02, 0x05, 0x09, 0x19,
    0x0F, 0x29, 0x12, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x04, 0x81,
    0x02, 0x75, 0x08, 0x95, 0x34, 0x81, 0x03, 0x06, 0x00, 0xFF, 0x85, 0x21,
    0x09, 0x01, 0x75, 0x08, 0x95, 0x3F, 0x81, 0x03, 0x85, 0x81, 0x09, 0x02,
    0x75, 0x08, 0x95, 0x3F, 0x81, 0x03, 0x85, 0x01, 0x09, 0x03, 0x75, 0x08,
    0x95, 0x3F, 0x91, 0x83, 0x85, 0x10, 0x09, 0x04, 0x75, 0x08, 0x95, 0x3F,
    0x91, 0x83, 0x85, 0x80, 0x09, 0x05, 0x75, 0x08, 0x95, 0x3F, 0x91, 0x83,
    0x85, 0x82, 0x09, 0x06, 0x75, 0x08, 0x95, 0x3F, 0x91, 0x83, 0xC0,
  ]

  public var inputReportPayloadSize: Int { Self.maximumReportSize - 1 }
  public var inputReportID: UInt8? { 0x30 }
  public var outputReportPayloadSize: Int? { Self.maximumReportSize - 1 }
  public var outputReportID: UInt8? { 0x01 }

  public init() {}

  /// Deterministic mapping uses timer zero. Per-device timing belongs to the report sender.
  public func buildInputReport(from state: VirtualGamepadState) -> [UInt8] {
    buildInputReport(from: state, packetTimer: 0)
  }

  public func buildInputReport(
    from state: VirtualGamepadState,
    packetTimer: UInt8
  ) -> [UInt8] {
    var report = [UInt8](repeating: 0, count: Self.maximumReportSize)
    report[0] = 0x30
    report[1] = packetTimer
    report[2] = 0x81  // Full battery, USB connection; no battery telemetry is claimed.

    func pressed(_ button: GamepadHIDDescriptor.ButtonBit) -> Bool {
      state.buttons & (1 << UInt32(button.rawValue)) != 0
    }

    if pressed(.y) { report[3] |= 0x02 }  // X, North
    if pressed(.x) { report[3] |= 0x01 }  // Y, West
    if pressed(.b) { report[3] |= 0x08 }  // A, East
    if pressed(.a) { report[3] |= 0x04 }  // B, South
    if pressed(.rightBumper) { report[3] |= 0x40 }
    if state.effectiveRightTrigger > 0 { report[3] |= 0x80 }

    if pressed(.back) { report[4] |= 0x01 }  // Minus
    if pressed(.start) { report[4] |= 0x02 }  // Plus
    if pressed(.rightStick) { report[4] |= 0x04 }
    if pressed(.leftStick) { report[4] |= 0x08 }
    if pressed(.guide) { report[4] |= 0x10 }  // Home
    if pressed(.share) { report[4] |= 0x20 }  // Capture

    var up = pressed(.dpadUp) || [.north, .northEast, .northWest].contains(state.hat)
    var down = pressed(.dpadDown) || [.south, .southEast, .southWest].contains(state.hat)
    var left = pressed(.dpadLeft) || [.west, .northWest, .southWest].contains(state.hat)
    var right = pressed(.dpadRight) || [.east, .northEast, .southEast].contains(state.hat)
    if up && down { (up, down) = (false, false) }
    if left && right { (left, right) = (false, false) }
    if down { report[5] |= 0x01 }
    if up { report[5] |= 0x02 }
    if right { report[5] |= 0x04 }
    if left { report[5] |= 0x08 }
    if pressed(.leftBumper) { report[5] |= 0x40 }
    if state.effectiveLeftTrigger > 0 { report[5] |= 0x80 }

    Self.writeStick(
      into: &report,
      at: 6,
      x: Self.axis(state.leftStickX),
      y: Self.axis(state.leftStickY, invert: true)
    )
    Self.writeStick(
      into: &report,
      at: 9,
      x: Self.axis(state.rightStickX),
      y: Self.axis(state.rightStickY, invert: true)
    )

    // Three copies of the fixed rest sample: acceleration Z is 4096 and all other fields are zero.
    for offset in [13, 25, 37] { report[offset + 5] = 0x10 }
    return report
  }

  /// Signed normalized input to the calibrated unsigned 12-bit range 0...4095, centered at 2048.
  private static func axis(_ value: Int16, invert: Bool = false) -> UInt16 {
    let signed = invert ? -Int(value) : Int(value)
    let denominator = signed < 0 ? 32_768.0 : 32_767.0
    let normalized = max(-1, min(1, Double(signed) / denominator))
    return UInt16(((normalized + 1) * 2047.5).rounded())
  }

  private static func writeStick(
    into report: inout [UInt8],
    at offset: Int,
    x: UInt16,
    y: UInt16
  ) {
    report[offset] = UInt8(x & 0xFF)
    report[offset + 1] = UInt8((x >> 8) | ((y & 0x0F) << 4))
    report[offset + 2] = UInt8(y >> 4)
  }
}
