// Provenance: libvirtualhid 4847ea017f02115a02f57bd9372c0d2d8fe7c06f;
// src/shared/switch_pro_protocol.hpp make_switch_pro_reply, set_neutral_controller_state,
// set_spi_reply, set_device_info_reply and copy_spi_data.
// Copyright (c) 2026 LizardByte. MIT License; see Resources/Licenses/libvirtualhid-MIT.txt.

import Foundation

extension SwitchProHIDReportFormat {
  /// Answers one bounded USB request. Replies use the current controls, not a neutral helper.
  ///
  /// IMU enable (0x40), vibration enable (0x48), player LEDs (0x30) and Home LED (0x38) receive
  /// no-op ACKs. Rumble-only report 0x10 is accepted without a reply.
  /// No physical feature is forwarded.
  /// SPI reads select only the two fixed calibration arrays below, never memory, files or hardware.
  func reply(
    to request: VirtualHostReportRequest,
    state: VirtualGamepadState,
    packetTimer: UInt8
  ) throws(VirtualHostReportError) -> [[UInt8]] {
    guard request.type == .output else { throw .unsupported }
    let payload = request.payload
    guard payload.count < Self.maximumReportSize else { throw .tooLarge }

    switch request.reportID {
    case 0x80: return try handshake(payload)
    case 0x01: return try subcommand(payload, state: state, packetTimer: packetTimer)
    case 0x10:
      guard payload.count >= 9 else { throw .malformed }
      return []
    default: throw .unsupported
    }
  }

  private func handshake(_ payload: [UInt8]) throws(VirtualHostReportError) -> [[UInt8]] {
    guard let command = payload.first else { throw .malformed }
    if command == 0x04 { return [] }  // The reference's USB initialization command has no reply.
    guard [0x01, 0x02, 0x03].contains(command) else { throw .unsupported }

    var reply = [UInt8](repeating: 0, count: Self.maximumReportSize)
    reply[0] = 0x81
    reply[1] = command
    if command == 0x01 {
      reply[3] = 0x03
      reply.replaceSubrange(4..<10, with: Self.controllerMAC.reversed())
    }
    return [reply]
  }

  private func subcommand(
    _ payload: [UInt8],
    state: VirtualGamepadState,
    packetTimer: UInt8
  ) throws(VirtualHostReportError) -> [[UInt8]] {
    guard payload.count >= 10 else { throw .malformed }
    let command = payload[9]
    switch command {
    case 0x02:  // Device information.
      var reply = acknowledgement(
        0x82,
        command: command,
        state: state,
        packetTimer: packetTimer
      )
      reply.replaceSubrange(15..<27, with: Self.deviceInfo)
      return [reply]
    case 0x03:  // Input report mode.
      guard payload.count >= 11 else { throw .malformed }
      guard payload[10] == 0x30 else { throw .unsupported }
      return [acknowledgement(0x80, command: command, state: state, packetTimer: packetTimer)]
    case 0x10:  // SPI flash read.
      return [try spiReply(payload, state: state, packetTimer: packetTimer)]
    case 0x30:  // Player LEDs: acknowledged no-op.
      guard payload.count >= 11 else { throw .malformed }
      return [acknowledgement(0x80, command: command, state: state, packetTimer: packetTimer)]
    case 0x38:  // Home LED: acknowledged no-op with its three-byte control payload.
      guard payload.count >= 13 else { throw .malformed }
      return [acknowledgement(0x80, command: command, state: state, packetTimer: packetTimer)]
    case 0x40, 0x48:  // IMU and vibration enable: acknowledged no-ops.
      guard payload.count >= 11 else { throw .malformed }
      guard payload[10] <= 1 else { throw .malformed }
      return [acknowledgement(0x80, command: command, state: state, packetTimer: packetTimer)]
    default: throw .unsupported
    }
  }

  private func acknowledgement(
    _ acknowledgement: UInt8,
    command: UInt8,
    state: VirtualGamepadState,
    packetTimer: UInt8
  ) -> [UInt8] {
    let input = buildInputReport(from: state, packetTimer: packetTimer)
    var reply = [UInt8](repeating: 0, count: Self.maximumReportSize)
    reply.replaceSubrange(0..<12, with: input.prefix(12))
    reply[0] = 0x21
    reply[13] = acknowledgement
    reply[14] = command
    return reply
  }

  private func spiReply(
    _ payload: [UInt8],
    state: VirtualGamepadState,
    packetTimer: UInt8
  ) throws(VirtualHostReportError) -> [UInt8] {
    guard payload.count >= 15 else { throw .malformed }
    let length = Int(payload[14])
    guard length <= Self.maximumReportSize - 20 else { throw .tooLarge }

    let address =
      UInt32(payload[10])
      | (UInt32(payload[11]) << 8)
      | (UInt32(payload[12]) << 16)
      | (UInt32(payload[13]) << 24)
    let requestedEnd = UInt64(address) + UInt64(length)
    guard
      let region = Self.spiRegions.first(where: {
        UInt64(address) >= UInt64($0.address)
          && requestedEnd <= UInt64($0.address) + UInt64($0.bytes.count)
      })
    else { throw .unsupported }

    var reply = acknowledgement(
      0x90,
      command: 0x10,
      state: state,
      packetTimer: packetTimer
    )
    reply.replaceSubrange(15..<20, with: payload[10..<15])
    let sourceOffset = Int(address - region.address)
    reply.replaceSubrange(
      20..<(20 + length),
      with: region.bytes[sourceOffset..<(sourceOffset + length)]
    )
    return reply
  }

  private static let controllerMAC: [UInt8] = [0x02, 0x00, 0x00, 0x00, 0x00, 0x01]

  private static let deviceInfo: [UInt8] = [
    0x04, 0x33, 0x03, 0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01,
  ]

  private static let factoryStickCalibration: [UInt8] = [
    // Center 2048, positive extent 2047 and negative extent 2048 cover the full emitted range.
    0xFF, 0xF7, 0x7F, 0x00, 0x08, 0x80, 0x00, 0x08, 0x80,
    0x00, 0x08, 0x80, 0xFF, 0xF7, 0x7F, 0x00, 0x08, 0x80,
  ]

  private static let factoryIMUCalibration: [UInt8] = [
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40,
    0x00, 0x40, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x3B, 0x34, 0x3B, 0x34, 0x3B, 0x34,
  ]

  private static let spiRegions = [
    SPIRegion(address: 0x6020, bytes: factoryIMUCalibration),
    SPIRegion(address: 0x603D, bytes: factoryStickCalibration),
  ]

  private struct SPIRegion: Sendable {
    let address: UInt32
    let bytes: [UInt8]
  }
}
