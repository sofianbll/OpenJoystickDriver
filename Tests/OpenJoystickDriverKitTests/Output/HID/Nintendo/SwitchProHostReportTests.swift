import ProtocolPacketFixtures
import Testing

@testable import OpenJoystickDriverKit

private typealias HostFixture = ProtocolPacketFixtures.SwitchProOutput

struct SwitchProHostReportTests {
  private let format = SwitchProHIDReportFormat()
  private let neutral = VirtualGamepadState()

  private func request(
    _ reportID: UInt8,
    payload: [UInt8],
    type: VirtualHostReportType = .output
  ) throws -> VirtualHostReportRequest {
    try VirtualHostReportRequest(
      type: type,
      reportID: UInt32(reportID),
      bytes: [reportID] + payload
    )
  }

  private func subcommand(_ command: UInt8, data: [UInt8] = []) -> [UInt8] {
    [0x00, 0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40, command] + data
  }

  private func spiRequest(address: UInt32, length: UInt8) -> [UInt8] {
    subcommand(
      0x10,
      data: [
        UInt8(truncatingIfNeeded: address),
        UInt8(truncatingIfNeeded: address >> 8),
        UInt8(truncatingIfNeeded: address >> 16),
        UInt8(truncatingIfNeeded: address >> 24),
        length,
      ]
    )
  }

  private func expect(
    _ error: VirtualHostReportError,
    _ request: VirtualHostReportRequest
  ) {
    #expect(throws: error) {
      try format.reply(to: request, state: neutral, packetTimer: 0)
    }
  }

  @Test
  func usbHandshakeCommandsHaveExactReplies() throws {
    let identify = try format.reply(
      to: request(0x80, payload: [0x01]),
      state: neutral,
      packetTimer: 0
    )
    #expect(identify == [HostFixture.usbHandshakeReply])

    for command: UInt8 in [0x02, 0x03] {
      var expected = [UInt8](repeating: 0, count: 64)
      expected[0] = 0x81
      expected[1] = command
      #expect(
        try format.reply(
          to: request(0x80, payload: [command]),
          state: neutral,
          packetTimer: 0
        ) == [expected]
      )
    }
    #expect(
      try format.reply(
        to: request(0x80, payload: [0x04]),
        state: neutral,
        packetTimer: 0
      ).isEmpty
    )
  }

  @Test
  func deviceInformationAndFullInputModeMatchGoldenReplies() throws {
    #expect(
      try format.reply(
        to: request(0x01, payload: subcommand(0x02)),
        state: neutral,
        packetTimer: 0
      ) == [HostFixture.deviceInfoReply]
    )
    #expect(
      try format.reply(
        to: request(0x01, payload: subcommand(0x03, data: [0x30])),
        state: neutral,
        packetTimer: 0
      ) == [HostFixture.modeReply]
    )
  }

  @Test
  func calibrationCoversTheEmittedZeroCenterAndMaximumForBothSticks() throws {
    let request = try request(0x01, payload: spiRequest(address: 0x603D, length: 18))
    let reply = try #require(format.reply(to: request, state: neutral, packetTimer: 0).first)
    let bytes = Array(reply[20..<38])
    func pair(_ offset: Int) -> (Int, Int) {
      (
        Int(bytes[offset]) | (Int(bytes[offset + 1] & 0x0F) << 8),
        Int(bytes[offset + 1] >> 4) | (Int(bytes[offset + 2]) << 4)
      )
    }
    let sticks = [(center: 3, positive: 0, negative: 6), (center: 9, positive: 12, negative: 15)]
    for offsets in sticks {
      let center = pair(offsets.center)
      let positive = pair(offsets.positive)
      let negative = pair(offsets.negative)
      #expect(center == (2048, 2048))
      #expect(center.0 - negative.0 == 0 && center.1 - negative.1 == 0)
      #expect(center.0 + positive.0 == 4095 && center.1 + positive.1 == 4095)
    }
  }

  @Test
  func factoryStickAndIMUCalibrationMatchGoldenReplies() throws {
    let stick = try request(0x01, payload: spiRequest(address: 0x603D, length: 18))
    let imu = try request(0x01, payload: spiRequest(address: 0x6020, length: 24))

    #expect(
      try format.reply(to: stick, state: neutral, packetTimer: 0)
        == [HostFixture.stickCalibrationReply]
    )
    #expect(
      try format.reply(to: imu, state: neutral, packetTimer: 0)
        == [HostFixture.imuCalibrationReply]
    )
  }

  @Test
  func boundedSPISubrangeReadsOnlyTheSelectedCalibrationBytes() throws {
    let request = try request(0x01, payload: spiRequest(address: 0x603E, length: 2))
    let reply = try #require(
      format.reply(to: request, state: neutral, packetTimer: 0).first
    )

    #expect(Array(reply[15...19]) == [0x3E, 0x60, 0x00, 0x00, 0x02])
    #expect(Array(reply[20...21]) == [0xF7, 0x7F])
    #expect(reply[22...].allSatisfy { $0 == 0 })
  }

  @Test
  func repliesPreserveHeldControlsAndTheProvidedPacketTimer() throws {
    let buttons: UInt32 =
      (1 << UInt32(GamepadHIDDescriptor.ButtonBit.a.rawValue))
      | (1 << UInt32(GamepadHIDDescriptor.ButtonBit.rightBumper.rawValue))
      | (1 << UInt32(GamepadHIDDescriptor.ButtonBit.guide.rawValue))
      | (1 << UInt32(GamepadHIDDescriptor.ButtonBit.share.rawValue))
    let held = VirtualGamepadState(
      buttons: buttons,
      leftStickX: .max,
      leftStickY: .min,
      rightStickX: .min,
      rightStickY: .max,
      leftTriggerPressed: true,
      hat: .southEast
    )

    #expect(
      try format.reply(
        to: request(0x01, payload: subcommand(0x02)),
        state: held,
        packetTimer: 0xA5
      ) == [HostFixture.heldControlsDeviceInfoReply]
    )
  }

  @Test
  func initializationHapticsAndLEDControlsAreExplicitAcknowledgedNoOps() throws {
    let commands: [(UInt8, [UInt8])] = [
      (0x30, [0x0F]),
      (0x38, [0x01, 0x02, 0x03]),
      (0x40, [0x01]),
      (0x48, [0x01]),
    ]
    for (command, data) in commands {
      let reply = try #require(
        format.reply(
          to: request(0x01, payload: subcommand(command, data: data)),
          state: neutral,
          packetTimer: 0
        ).first
      )
      #expect(reply.count == 64)
      #expect(Array(reply[0..<12]) == Array(HostFixture.modeReply[0..<12]))
      #expect(Array(reply[13...14]) == [0x80, command])
      #expect(reply[15...].allSatisfy { $0 == 0 })
    }

    let rumble = [UInt8](repeating: 0, count: 9)
    #expect(
      try format.reply(
        to: request(0x10, payload: rumble),
        state: neutral,
        packetTimer: 0
      ).isEmpty
    )
  }

  @Test
  func wrongTypeIDAndOversizedRequestsFailWithoutAReply() throws {
    #expect(throws: VirtualHostReportError.malformed) {
      try VirtualHostReportRequest(type: .output, reportID: 0x80, bytes: [0x01, 1])
    }
    for type in [VirtualHostReportType.input, .feature] {
      expect(
        .unsupported,
        try request(0x01, payload: subcommand(0x02), type: type)
      )
    }
    expect(.unsupported, try request(0x02, payload: subcommand(0x02)))
    expect(.unsupported, try request(0x21, payload: subcommand(0x02)))
    expect(.tooLarge, try request(0x01, payload: [UInt8](repeating: 0, count: 64)))
  }

  @Test
  func malformedHandshakeSubcommandsAndRumbleAreRejected() throws {
    expect(.malformed, try request(0x80, payload: []))
    expect(.unsupported, try request(0x80, payload: [0x7F]))
    expect(.malformed, try request(0x01, payload: Array(subcommand(0x02).dropLast())))
    expect(.unsupported, try request(0x01, payload: subcommand(0xFF)))
    expect(.malformed, try request(0x01, payload: subcommand(0x03)))
    expect(.unsupported, try request(0x01, payload: subcommand(0x03, data: [0x3F])))
    expect(.malformed, try request(0x10, payload: [UInt8](repeating: 0, count: 8)))
  }

  @Test
  func truncatedInvalidAndUnknownNoOpControlsAreNotAcknowledged() throws {
    expect(.malformed, try request(0x01, payload: subcommand(0x30)))
    expect(.malformed, try request(0x01, payload: subcommand(0x38, data: [0, 0])))
    for command: UInt8 in [0x40, 0x48] {
      expect(.malformed, try request(0x01, payload: subcommand(command)))
      expect(.malformed, try request(0x01, payload: subcommand(command, data: [2])))
    }
  }

  @Test
  func SPIReadsRejectTruncationCapacityAndAddressesOutsideFixedRegions() throws {
    for byteCount in 0..<5 {
      let data = Array(spiRequest(address: 0x603D, length: 18).suffix(5).prefix(byteCount))
      expect(.malformed, try request(0x01, payload: subcommand(0x10, data: data)))
    }
    expect(
      .tooLarge,
      try request(0x01, payload: spiRequest(address: 0x603D, length: 45))
    )
    expect(
      .unsupported,
      try request(0x01, payload: spiRequest(address: 0, length: 1))
    )
    expect(
      .unsupported,
      try request(0x01, payload: spiRequest(address: 0x603D, length: 19))
    )
    expect(
      .unsupported,
      try request(0x01, payload: spiRequest(address: UInt32.max, length: 2))
    )
  }
}
