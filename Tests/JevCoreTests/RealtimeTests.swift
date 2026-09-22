import XCTest
@testable import JevCore

final class RealtimeTests: XCTestCase {
    private let config = RealtimeConfiguration(stabilityDuration: 0.2, minimumStableUpdates: 2)

    func testPartialTranscriptStability() {
        var manager = PartialTranscriptManager(configuration: config)
        XCTAssertNil(manager.update("open", at: 0).stableTranscript)
        XCTAssertNil(manager.update("open no", at: 0.1).stableTranscript)
        XCTAssertNil(manager.update("open notes", at: 0.2).stableTranscript)
        XCTAssertEqual(manager.update("open notes", at: 0.45).stableTranscript, "open notes")
    }

    func testUnstableRevisionDoesNotCommitHallucinatedSuffix() {
        var manager = PartialTranscriptManager(configuration: config)
        _ = manager.update("open notes", at: 0)
        let update = manager.update("open notion", at: 0.3)
        XCTAssertNil(update.stableTranscript)
        XCTAssertEqual(manager.lastStableTranscript, "")
    }

    func testDuplicateSuppression() {
        var ledger = ExecutedActionLedger()
        let id = ExecutedActionLedger.identity(operation: "OPEN_APP", target: "Notes")
        XCTAssertTrue(ledger.record(id: id, transcriptSpan: "open notes", timestamp: 1, result: "opened"))
        XCTAssertFalse(ledger.record(id: id, transcriptSpan: "open notes and", timestamp: 2, result: "opened"))
        XCTAssertEqual(ledger.actions.count, 1)
    }

    func testPartialLowConfidenceAndDangerousSpeculation() {
        XCTAssertFalse(RealtimeSafetyPolicy.allowsSpeculation(operation: "OPEN_APP", target: "Notes", transcript: "open", confidence: 0.7))
        XCTAssertFalse(RealtimeSafetyPolicy.allowsSpeculation(operation: "CLICK", target: "Delete file", transcript: "delete file", confidence: 1))
        XCTAssertEqual(RealtimeSafetyPolicy.classify(operation: "PRESS_RETURN", transcript: "send email"), .dangerous)
    }

    func testSafeSpeculation() {
        XCTAssertTrue(RealtimeSafetyPolicy.allowsSpeculation(operation: "OPEN_APP", target: "Notes", transcript: "open notes", confidence: 0.94))
        XCTAssertTrue(RealtimeSafetyPolicy.allowsSpeculation(operation: "SCROLL_DOWN", transcript: "scroll down", confidence: 0.91))
        XCTAssertFalse(RealtimeSafetyPolicy.allowsSpeculation(operation: "TYPE_TEXT", target: "editor", transcript: "write hello", confidence: 0.99))
    }

    func testCompoundProgressiveSegmentation() {
        XCTAssertEqual(PartialTranscriptManager.segments(in: "open notes and create a note and write hello"),
                       ["open notes", "create a note", "write hello"])
    }

    func testEnvironmentConfigurationAndLatencyStatistics() {
        let values = ["REALTIME_MODE": "0", "PARTIAL_INTERVAL_MS": "150", "SPECULATIVE_ACTION_CONFIDENCE": "0.95"]
        let configured = RealtimeConfiguration.environment(values)
        XCTAssertFalse(configured.enabled)
        XCTAssertEqual(configured.partialInterval, 0.15)
        XCTAssertEqual(configured.speculativeConfidence, 0.95)
        XCTAssertEqual(LatencyStatistics.summarize([0.4, 0.1, 0.2, 0.3]),
                       LatencySummary(minimum: 0.1, p50: 0.3, p95: 0.4, maximum: 0.4))
    }
}
