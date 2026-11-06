import Foundation
import IOKit.hid
import Testing

@testable import OpenJoystickDriverKit

struct VirtualHostReportTests {
  @Test
  func nintendoNativeBufferLimitIsCheckedBeforeCopyingTheRequest() throws {
    let input = UserSpaceInputReportState(format: SwitchProHIDReportFormat())
    let handler = UserSpaceHostReportHandler(
      identifier: LogicalControllerID(vendorID: 1406, productID: 8201),
      input: input,
      sender: UserSpaceReportSender(),
      isOpen: { true },
      onOutput: nil
    ) { _ in }
    try handler.validateSetReportSize(64)
    #expect(throws: VirtualHostReportError.malformed) { try handler.validateSetReportSize(-1) }
    #expect(throws: VirtualHostReportError.tooLarge) { try handler.validateSetReportSize(65) }
    #expect(throws: VirtualHostReportError.tooLarge) {
      try handler.setReport(type: .output, reportID: 1, bytes: [UInt8](repeating: 1, count: 65))
    }
  }

  @Test
  func nintendoTimerDoesNotDefeatInputDeduplication() throws {
    let input = UserSpaceInputReportState(format: SwitchProHIDReportFormat())
    let held = input.update { $0.buttons = 1 }
    #expect(input.claimDelivery(of: held))
    let request = try VirtualHostReportRequest(
      type: .output,
      reportID: 0x80,
      bytes: [0x80, 1]
    )
    _ = try input.consumerResponse(request)
    let repeated = input.update { $0.buttons = 1 }
    #expect(repeated == held)
    #expect(!input.claimDelivery(of: repeated))
    let released = input.update { $0.buttons = 0 }
    #expect(input.claimDelivery(of: released))
    #expect(released[3] & 0x04 == 0)
  }

  @Test
  func nintendoCountersArePerDeviceAndValidationDoesNotAdvanceThem() throws {
    let first = UserSpaceInputReportState(format: SwitchProHIDReportFormat())
    let second = UserSpaceInputReportState(format: SwitchProHIDReportFormat())
    let request = try VirtualHostReportRequest(
      type: .output,
      reportID: 1,
      bytes: [0x01, 0] + [UInt8](repeating: 0, count: 8) + [0x02]
    )
    try first.validateConsumerRequest(request)
    try first.validateConsumerRequest(request)
    #expect(try first.consumerResponse(request).reports.first?[1] == 1)
    #expect(try second.consumerResponse(request).reports.first?[1] == 1)
    _ = first.update { $0.buttons = 1 }
    #expect(try first.consumerResponse(request).reports.first?[1] == 3)
    first.close()
    #expect(throws: VirtualHostReportError.closed) { try first.consumerResponse(request) }
    #expect(try second.consumerResponse(request).reports.first?[1] == 2)
  }

  @Test
  func numberedReportsCarryTheirIDAsByteZero() throws {
    let numbered = try VirtualHostReportRequest(type: .output, reportID: 5, bytes: [5, 5, 9])
    #expect(numbered.payload == [5, 9])
    // An unnumbered report is all data, whatever its first byte.
    let unnumbered = try VirtualHostReportRequest(type: .output, reportID: 0, bytes: [5, 9])
    #expect(unnumbered.payload == [5, 9])
    #expect(throws: VirtualHostReportError.malformed) {
      try VirtualHostReportRequest(type: .output, reportID: 5, bytes: [9])
    }
    #expect(throws: VirtualHostReportError.malformed) {
      try VirtualHostReportRequest(type: .output, reportID: 256, bytes: [])
    }
  }

  @Test
  func hostReportChecksTypeIdentityCapacityAndLifetime() throws {
    let input = UserSpaceInputReportState(format: OJDGenericGamepadFormat())
    let current = input.update { $0.buttons = 1 }
    #expect(try input.hostReport(type: .input, reportID: 0, maxSize: 3) == Array(current.prefix(3)))
    for type in [VirtualHostReportType.feature, .output] {
      #expect(throws: VirtualHostReportError.unsupported) {
        try input.hostReport(type: type, reportID: 0, maxSize: 64)
      }
    }
    #expect(throws: VirtualHostReportError.unsupported) {
      try input.hostReport(type: .input, reportID: 1, maxSize: 64)
    }
    for size in [-1, 0] {
      #expect(throws: VirtualHostReportError.malformed) {
        try input.hostReport(type: .input, reportID: 0, maxSize: size)
      }
    }
    input.close()
    #expect(input.isClosed)
    #expect(throws: VirtualHostReportError.closed) {
      try input.hostReport(type: .input, reportID: 0, maxSize: 64)
    }
  }

  @Test
  func inputOnlyGenericFormatRejectsOutputWhileXboxDecodesItsReport() throws {
    let generic = UserSpaceInputReportState(format: OJDGenericGamepadFormat())
    for bytes: [UInt8] in [[8, 0, 127, 255, 0, 0, 0], [8, 0, 127, 255], [0x4F, 10, 20, 0, 0]] {
      let request = try VirtualHostReportRequest(type: .output, reportID: 0, bytes: bytes)
      #expect(throws: VirtualHostReportError.unsupported) { try generic.consumerResponse(request) }
    }
    let xbox = UserSpaceInputReportState(format: XboxOneGIPHIDReportFormat())
    let rumble = try VirtualHostReportRequest(
      type: .output,
      reportID: 9,
      bytes: gipRumbleReport(activation: 0x03, left: 127, right: 255, duration: 25)
    )
    let response = try xbox.consumerResponse(rumble)
    #expect(response.command == .consumerRumble(left: 127, right: 255))
    #expect(response.reports.isEmpty)
    let feature = try VirtualHostReportRequest(
      type: .feature,
      reportID: 9,
      bytes: gipRumbleReport(activation: 0x03, left: 127, right: 255, duration: 25)
    )
    #expect(throws: VirtualHostReportError.unsupported) { try xbox.consumerResponse(feature) }
  }

  @Test
  func setReportOnTheInputOnlyGenericFormatProducesNoCommand() async throws {
    let input = UserSpaceInputReportState(format: OJDGenericGamepadFormat())
    let sender = UserSpaceReportSender()
    let isOpen: @Sendable () -> Bool = { true }
    let handler = UserSpaceHostReportHandler(
      identifier: LogicalControllerID(vendorID: 1, productID: 2),
      input: input,
      sender: sender,
      isOpen: isOpen,
      onOutput: { _, command in Issue.record("Unexpected output command \(command)") },
      onRumbleStatus: { _ in }
    )
    #expect(throws: VirtualHostReportError.unsupported) {
      try handler.setReport(type: .output, reportID: 0, bytes: [0x4F, 10, 20, 0, 0])
    }
    await sender.beginClose().value
  }

  @Test
  func setReportAfterInputCloseIsClosed() async throws {
    let input = UserSpaceInputReportState(format: OJDGenericGamepadFormat())
    let sender = UserSpaceReportSender()
    let isOpen: @Sendable () -> Bool = { true }
    let handler = UserSpaceHostReportHandler(
      identifier: LogicalControllerID(vendorID: 1, productID: 2),
      input: input,
      sender: sender,
      isOpen: isOpen,
      onOutput: nil
    ) { _ in }
    input.close()
    #expect(throws: VirtualHostReportError.closed) {
      try handler.setReport(type: .output, reportID: 0, bytes: [0x4F, 10, 20, 0, 0])
    }
    await sender.beginClose().value
  }
}
