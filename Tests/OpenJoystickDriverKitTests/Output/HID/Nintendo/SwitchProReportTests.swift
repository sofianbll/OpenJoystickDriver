import ProtocolPacketFixtures
import Testing

@testable import OpenJoystickDriverKit

private typealias Fixture = ProtocolPacketFixtures.SwitchProOutput

struct SwitchProReportTests {
  private let format = SwitchProHIDReportFormat()

  private func report(buttonBit: GamepadHIDDescriptor.ButtonBit) -> [UInt8] {
    format.buildInputReport(from: VirtualGamepadState(buttons: 1 << UInt32(buttonBit.rawValue)))
  }

  private func onlyByteDiffers(_ report: [UInt8], at index: Int) -> Bool {
    report.enumerated().allSatisfy {
      $0.offset == index || $0.element == Fixture.neutralInputReport[$0.offset]
    }
  }

  @Test
  func neutralReleaseAndDefaultTimerMatchTheIndependentPacket() {
    let pressed = VirtualGamepadState(
      buttons: 0xFFFF,
      leftStickX: .max,
      leftStickY: .max,
      rightStickX: .max,
      rightStickY: .max,
      leftTrigger: .max,
      rightTrigger: .max,
      hat: .north
    )
    _ = format.buildInputReport(from: pressed)

    #expect(format.buildInputReport(from: VirtualGamepadState()) == Fixture.neutralInputReport)
    #expect(
      format.buildInputReport(from: VirtualGamepadState(), packetTimer: 0)
        == Fixture.neutralInputReport
    )
  }

  @Test
  func explicitTimerChangesOnlyByteOne() {
    let report = format.buildInputReport(from: VirtualGamepadState(), packetTimer: 0xA7)

    #expect(report.count == 64)
    #expect(report[1] == 0xA7)
    #expect(onlyByteDiffers(report, at: 1))
  }

  @Test
  func everyNonDirectionalButtonUsesItsNintendoPosition() {
    let controls: [(GamepadHIDDescriptor.ButtonBit, Int, UInt8)] = [
      (.a, 3, 0x04),  // South = B
      (.b, 3, 0x08),  // East = A
      (.x, 3, 0x01),  // West = Y
      (.y, 3, 0x02),  // North = X
      (.rightBumper, 3, 0x40),
      (.leftBumper, 5, 0x40),
      (.back, 4, 0x01),
      (.start, 4, 0x02),
      (.rightStick, 4, 0x04),
      (.leftStick, 4, 0x08),
      (.guide, 4, 0x10),
      (.share, 4, 0x20),
    ]
    for (button, byte, mask) in controls {
      let value = report(buttonBit: button)
      #expect(value[byte] == mask)
      #expect(onlyByteDiffers(value, at: byte))
    }
  }

  @Test
  func digitalAndAnalogTriggerSourcesSetOnlyTheDigitalZLAndZRBits() {
    let states = [
      VirtualGamepadState(leftTrigger: 1),
      VirtualGamepadState(leftTrigger: .max),
      VirtualGamepadState(leftTriggerPressed: true),
    ]
    for state in states {
      let value = format.buildInputReport(from: state)
      #expect(value[5] == 0x80)
      #expect(onlyByteDiffers(value, at: 5))
    }

    let right = format.buildInputReport(from: VirtualGamepadState(rightTriggerPressed: true))
    #expect(right[3] == 0x80)
    #expect(onlyByteDiffers(right, at: 3))
  }

  @Test(arguments: [
    (GamepadHIDDescriptor.Hat.neutral, UInt8(0x00)),
    (.north, 0x02), (.northEast, 0x06), (.east, 0x04), (.southEast, 0x05),
    (.south, 0x01), (.southWest, 0x09), (.west, 0x08), (.northWest, 0x0A),
  ])
  func everyHatDirectionSetsTheNintendoDpadBits(hat: GamepadHIDDescriptor.Hat, bits: UInt8) {
    let value = format.buildInputReport(from: VirtualGamepadState(hat: hat))

    #expect(value[5] == bits)
    #expect(onlyByteDiffers(value, at: 5))
  }

  @Test
  func directionButtonsMatchTheHatAndOpposingPairsCancel() {
    let controls: [(GamepadHIDDescriptor.ButtonBit, UInt8)] = [
      (.dpadDown, 0x01), (.dpadUp, 0x02), (.dpadRight, 0x04), (.dpadLeft, 0x08),
    ]
    for (button, mask) in controls {
      let value = report(buttonBit: button)
      #expect(value[5] == mask)
      #expect(onlyByteDiffers(value, at: 5))
    }

    let vertical: UInt32 =
      (1 << UInt32(GamepadHIDDescriptor.ButtonBit.dpadUp.rawValue))
      | (1 << UInt32(GamepadHIDDescriptor.ButtonBit.dpadDown.rawValue))
    let horizontal: UInt32 =
      (1 << UInt32(GamepadHIDDescriptor.ButtonBit.dpadLeft.rawValue))
      | (1 << UInt32(GamepadHIDDescriptor.ButtonBit.dpadRight.rawValue))
    #expect(
      format.buildInputReport(from: VirtualGamepadState(buttons: vertical))
        == Fixture.neutralInputReport
    )
    #expect(
      format.buildInputReport(from: VirtualGamepadState(buttons: horizontal))
        == Fixture.neutralInputReport
    )
  }

  @Test
  func sticksCoverBothExtremesWithYDownInvertedToNintendoYUp() {
    let maximum = VirtualGamepadState(
      leftStickX: .max,
      leftStickY: .min,
      rightStickX: .max,
      rightStickY: .min
    )
    let minimum = VirtualGamepadState(
      leftStickX: .min,
      leftStickY: .max,
      rightStickX: .min,
      rightStickY: .max
    )

    #expect(format.buildInputReport(from: maximum) == Fixture.maximumStickInputReport)
    #expect(format.buildInputReport(from: minimum) == Fixture.minimumStickInputReport)
  }

  @Test
  func descriptorAndPrimaryReportSizesMatchThePinnedSource() throws {
    let parsed = try #require(HIDReportDescriptorParser.parse(descriptor: format.descriptor))

    #expect(format.descriptor == Fixture.descriptor)
    #expect(format.inputReportID == 0x30)
    #expect(format.inputReportPayloadSize == 63)
    #expect(format.outputReportID == 0x01)
    #expect(format.outputReportPayloadSize == 63)
    #expect(parsed.payloadSizeBytesByReportID[0x30] == 63)
    #expect(Fixture.neutralInputReport.count == 64)
  }
}
