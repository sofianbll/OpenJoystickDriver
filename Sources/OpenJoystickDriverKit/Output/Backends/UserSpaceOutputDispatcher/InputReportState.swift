import Foundation

/// Owns the current virtual state and the exact report exposed through both push and get-report
/// APIs.
final class UserSpaceInputReportState: Sendable {
  private struct Current {
    var state = VirtualGamepadState()
    var report: [UInt8]
    var remapped = false
    var packetTimer: UInt8 = 0
    /// The input report input delivery last published; nil once another path published.
    var deliveredReport: [UInt8]?
    /// The auxiliary input reports last handed to delivery, index-aligned with the format's.
    var deliveredAuxiliaryReports: [[UInt8]]
    /// Set once the published device closes; host report requests then fail.
    var closed = false
  }

  private let format: any VirtualGamepadReportFormat
  private let current: Locked<Current>

  var isRemapped: Bool { current.withLock { $0.remapped } }

  /// Nintendo's several host-report IDs share one bounded USB report buffer.
  var maximumConsumerReportSize: Int? {
    format is SwitchProHIDReportFormat ? SwitchProHIDReportFormat.maximumReportSize : nil
  }

  init(format: any VirtualGamepadReportFormat) {
    self.format = format
    let neutral = VirtualGamepadState()
    self.current = Locked(
      Current(
        report: format.buildInputReport(from: neutral),
        deliveredAuxiliaryReports: format.buildAuxiliaryInputReports(from: neutral)
      )
    )
  }

  /// The controller state last built.
  func currentState() -> VirtualGamepadState { current.withLock { $0.state } }

  func update(remapped: Bool = false, _ body: (inout VirtualGamepadState) -> Void) -> [UInt8] {
    current.withLock { current in
      current.remapped = remapped
      // Compare deterministic bytes so packet timing cannot defeat deduplication.
      let previous = format.buildInputReport(from: current.state)
      body(&current.state)
      if format.buildInputReport(from: current.state) != previous {
        current.packetTimer &+= 1
        current.report = format.buildInputReport(
          from: current.state,
          packetTimer: current.packetTimer
        )
      }
      return current.report
    }
  }

  func currentReport() -> [UInt8] { current.withLock { $0.report } }

  /// Records `report` for delivery and returns whether consumers do not hold it yet.
  func claimDelivery(of report: [UInt8]) -> Bool {
    current.withLock { current in
      guard report != current.deliveredReport else { return false }
      current.deliveredReport = report
      return true
    }
  }

  /// The auxiliary input reports whose bytes differ from those last returned here.
  func claimChangedAuxiliaryReports() -> [[UInt8]] {
    current.withLock { current in
      let reports = format.buildAuxiliaryInputReports(from: current.state)
      let changed = reports.enumerated().filter { index, report in
        index >= current.deliveredAuxiliaryReports.count
          || current.deliveredAuxiliaryReports[index] != report
      }.map(\.element)
      current.deliveredAuxiliaryReports = reports
      return changed
    }
  }

  func reset() -> [UInt8] {
    current.withLock { current in
      current.state = VirtualGamepadState()
      current.remapped = false
      current.deliveredReport = nil
      current.packetTimer &+= 1
      current.report = format.buildInputReport(
        from: current.state,
        packetTimer: current.packetTimer
      )
      return current.report
    }
  }

  func close() { current.withLock { $0.closed = true } }

  var isClosed: Bool { current.withLock { $0.closed } }

  /// Validates synchronously before a native callback acknowledges enqueueing.
  func validateConsumerRequest(_ request: VirtualHostReportRequest) throws {
    try current.withLock { current in
      guard !current.closed else { throw VirtualHostReportError.closed }
      _ = try ConsumerOutputCodec.response(
        request,
        in: format,
        state: current.state,
        packetTimer: current.packetTimer
      )
    }
  }

  /// Builds replies inside the ordered sender, after preceding input updates.
  func consumerResponse(_ request: VirtualHostReportRequest) throws -> ConsumerOutputResponse {
    try current.withLock { current in
      guard !current.closed else { throw VirtualHostReportError.closed }
      let timer = current.packetTimer &+ 1
      let response = try ConsumerOutputCodec.response(
        request,
        in: format,
        state: current.state,
        packetTimer: timer
      )
      current.packetTimer = timer
      return response
    }
  }

  /// The current input report a host requests, bounded to `maxSize` and including its ID when the
  /// format declares one; the format answers no other report.
  func hostReport(type: VirtualHostReportType, reportID: UInt32, maxSize: Int) throws -> [UInt8] {
    try current.withLock { current in
      guard !current.closed else { throw VirtualHostReportError.closed }
      guard maxSize > 0, let identifier = UInt8(exactly: reportID) else {
        throw VirtualHostReportError.malformed
      }
      guard type == .input, identifier == format.inputReportID ?? 0 else {
        throw VirtualHostReportError.unsupported
      }
      return Array(current.report.prefix(maxSize))
    }
  }
}
