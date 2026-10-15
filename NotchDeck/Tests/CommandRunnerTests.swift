// CommandRunnerTests.swift
// Unit tests for CommandRunner: async process execution, timeouts, exit codes.

import XCTest
@testable import NotchDeck

@MainActor
final class CommandRunnerTests: XCTestCase {

    func testRunEchoCommand() async throws {
        let result = try await CommandRunner.run("echo 'Hello NotchDeck'")
        XCTAssertEqual(result.stdout, "Hello NotchDeck")
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.exitCode, 0)
    }

    func testRunCommandWithNonZeroExitCode() async throws {
        let result = try await CommandRunner.run("echo 'error message' >&2; exit 2")
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.exitCode, 2)
        XCTAssertTrue(result.stderr.contains("error message"))
    }

    func testCommandTimeout() async {
        do {
            _ = try await CommandRunner.run("sleep 3", timeout: 0.3)
            XCTFail("Command should have timed out")
        } catch let error as CommandError {
            switch error {
            case .timeout(let s):
                XCTAssertEqual(s, 0.3)
            default:
                XCTFail("Expected timeout error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptyCommandThrowsError() async {
        do {
            _ = try await CommandRunner.run("   ")
            XCTFail("Empty command should throw")
        } catch let error as CommandError {
            switch error {
            case .invalidCommand:
                break // Success
            default:
                XCTFail("Expected invalidCommand, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
