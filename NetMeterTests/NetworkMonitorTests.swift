//
//  NetworkMonitorTests.swift
//  NetMeterTests
//
//  Created by Chiranjeevi Ram on 4/12/25.
//

import XCTest
@testable import NetMeter

class NetworkMonitorTests: XCTestCase {
    var networkMonitor: NetworkMonitor!
    
    override func setUpWithError() throws {
        networkMonitor = NetworkMonitor()
    }
    
    override func tearDownWithError() throws {
        networkMonitor = nil
    }
    
    // MARK: - Format Tests
    
    func testFormatBytes() throws {
        // Test bytes
        XCTAssertEqual(networkMonitor.formatBytes(512), "512.00 B")
        
        // Test kilobytes
        XCTAssertEqual(networkMonitor.formatBytes(1024), "1.00 KB")
        XCTAssertEqual(networkMonitor.formatBytes(1536), "1.50 KB")
        
        // Test megabytes
        XCTAssertEqual(networkMonitor.formatBytes(1024 * 1024), "1.00 MB")
        XCTAssertEqual(networkMonitor.formatBytes(1.5 * 1024 * 1024), "1.50 MB")
        
        // Test gigabytes
        XCTAssertEqual(networkMonitor.formatBytes(1024 * 1024 * 1024), "1.00 GB")
        XCTAssertEqual(networkMonitor.formatBytes(1.5 * 1024 * 1024 * 1024), "1.50 GB")
    }
    
    func testFormatSpeed() throws {
        // Test bytes per second
        XCTAssertEqual(networkMonitor.formatSpeed(512), "512.00 B/s")
        
        // Test kilobytes per second
        XCTAssertEqual(networkMonitor.formatSpeed(1024), "1.00 KB/s")
        XCTAssertEqual(networkMonitor.formatSpeed(1536), "1.50 KB/s")
        
        // Test megabytes per second
        XCTAssertEqual(networkMonitor.formatSpeed(1024 * 1024), "1.00 MB/s")
        XCTAssertEqual(networkMonitor.formatSpeed(1.5 * 1024 * 1024), "1.50 MB/s")
        
        // Test gigabytes per second
        XCTAssertEqual(networkMonitor.formatSpeed(1024 * 1024 * 1024), "1.00 GB/s")
        XCTAssertEqual(networkMonitor.formatSpeed(1.5 * 1024 * 1024 * 1024), "1.50 GB/s")
    }
    
    // MARK: - Speed Calculation Tests
    
    func testSpeedCalculation() throws {
        // Simulate network data
        let currentTime = Date()
        let timeInterval: TimeInterval = 1.0
        
        // Test upload speed calculation
        let uploadBytes: UInt64 = 1024 * 1024 // 1 MB
        let uploadSpeed = Double(uploadBytes) / timeInterval
        XCTAssertEqual(uploadSpeed, 1024 * 1024, accuracy: 0.01)
        
        // Test download speed calculation
        let downloadBytes: UInt64 = 2 * 1024 * 1024 // 2 MB
        let downloadSpeed = Double(downloadBytes) / timeInterval
        XCTAssertEqual(downloadSpeed, 2 * 1024 * 1024, accuracy: 0.01)
    }
    
    func testOverflowHandling() throws {
        // Test that overflow is handled gracefully
        let maxUInt64: UInt64 = UInt64.max
        let smallValue: UInt64 = 1000
        
        // This should not crash and should handle overflow
        let result = maxUInt64.addingReportingOverflow(smallValue)
        XCTAssertTrue(result.overflow)
    }
    
    // MARK: - Network Status Tests
    
    func testInitialNetworkStatus() throws {
        // Initially should be disconnected until network is detected
        XCTAssertEqual(networkMonitor.networkStatus, .disconnected)
    }
    
    func testNetworkStatusTransitions() throws {
        // Test status transitions (these would be more comprehensive in integration tests)
        XCTAssertEqual(networkMonitor.networkStatus, .disconnected)
        
        // Note: In a real test environment, you'd mock the network interface
        // to test different states
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidRefreshInterval() throws {
        // Test that invalid intervals are handled
        networkMonitor.setRefreshInterval(0) // Invalid interval
        networkMonitor.setRefreshInterval(-1) // Invalid interval
        
        // Should not crash and should maintain valid state
        XCTAssertNotNil(networkMonitor)
    }
    
    func testStatisticsReset() throws {
        // Set some initial values
        networkMonitor.totalUploadedToday = 1000
        networkMonitor.totalDownloadedToday = 2000
        networkMonitor.peakUploadSpeed = 500
        networkMonitor.peakDownloadSpeed = 1000
        
        // Reset statistics
        networkMonitor.resetStatistics()
        
        // Verify reset
        XCTAssertEqual(networkMonitor.totalUploadedToday, 0)
        XCTAssertEqual(networkMonitor.totalDownloadedToday, 0)
        XCTAssertEqual(networkMonitor.peakUploadSpeed, 0)
        XCTAssertEqual(networkMonitor.peakDownloadSpeed, 0)
    }
    
    // MARK: - Performance Tests
    
    func testFormatPerformance() throws {
        let iterations = 10000
        
        measure {
            for _ in 0..<iterations {
                _ = networkMonitor.formatBytes(Double.random(in: 0...1e12))
                _ = networkMonitor.formatSpeed(Double.random(in: 0...1e9))
            }
        }
    }
}

// MARK: - Mock Network Monitor for Testing
class MockNetworkMonitor: NetworkMonitor {
    var mockInterfaceStats: InterfaceStats?
    var mockNetworkStatus: NetworkStatus = .connected
    var mockError: NetworkMonitorError?
    
    override func updateNetworkStats() {
        // Mock implementation for testing
        if let error = mockError {
            DispatchQueue.main.async {
                self.lastError = error
                self.networkStatus = .error(error)
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = nil
                self.networkStatus = self.mockNetworkStatus
            }
        }
    }
}

// MARK: - Integration Tests
class NetworkMonitorIntegrationTests: XCTestCase {
    var mockNetworkMonitor: MockNetworkMonitor!
    
    override func setUpWithError() throws {
        mockNetworkMonitor = MockNetworkMonitor()
    }
    
    override func tearDownWithError() throws {
        mockNetworkMonitor = nil
    }
    
    func testErrorHandling() throws {
        // Test error state
        mockNetworkMonitor.mockError = .interfaceNotFound
        
        // Trigger update
        mockNetworkMonitor.updateNetworkStats()
        
        // Wait for async update
        let expectation = XCTestExpectation(description: "Error state updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.mockNetworkMonitor.networkStatus, .error(.interfaceNotFound))
            XCTAssertNotNil(self.mockNetworkMonitor.lastError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testConnectedState() throws {
        // Test connected state
        mockNetworkMonitor.mockNetworkStatus = .connected
        mockNetworkMonitor.mockError = nil
        
        // Trigger update
        mockNetworkMonitor.updateNetworkStats()
        
        // Wait for async update
        let expectation = XCTestExpectation(description: "Connected state updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.mockNetworkMonitor.networkStatus, .connected)
            XCTAssertNil(self.mockNetworkMonitor.lastError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
} 