//
//  AppState.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//


import Foundation

class AppState: ObservableObject {
    @Published var dailyStatistics: [Date: DailyStats] = [:]
    
    private let statsURL: URL
    
    init() {
        // Get the documents directory URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create a URL for the statistics file
        statsURL = documentsDirectory.appendingPathComponent("netmeter_stats.json")
        
        // Load saved statistics
        loadStatistics()
    }
    
    func addDailyStatistics(for date: Date, uploaded: UInt64, downloaded: UInt64) {
        // Format date to remove time component
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dayKey = calendar.date(from: components)!
        
        // Get or create stats for this day
        if var stats = dailyStatistics[dayKey] {
            // Update existing stats
            stats.totalUploaded += uploaded
            stats.totalDownloaded += downloaded
            dailyStatistics[dayKey] = stats
        } else {
            // Create new stats
            let stats = DailyStats(date: dayKey, totalUploaded: uploaded, totalDownloaded: downloaded, peakUploadSpeed: 0, peakDownloadSpeed: 0)
            dailyStatistics[dayKey] = stats
        }
        
        // Save statistics
        saveStatistics()
    }
    
    func updatePeakSpeeds(for date: Date, uploadSpeed: Double, downloadSpeed: Double) {
        // Format date to remove time component
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dayKey = calendar.date(from: components)!
        
        // Get or create stats for this day
        if var stats = dailyStatistics[dayKey] {
            // Update peak speeds if necessary
            if uploadSpeed > stats.peakUploadSpeed {
                stats.peakUploadSpeed = uploadSpeed
            }
            
            if downloadSpeed > stats.peakDownloadSpeed {
                stats.peakDownloadSpeed = downloadSpeed
            }
            
            dailyStatistics[dayKey] = stats
        } else {
            // Create new stats
            let stats = DailyStats(date: dayKey, totalUploaded: 0, totalDownloaded: 0, peakUploadSpeed: uploadSpeed, peakDownloadSpeed: downloadSpeed)
            dailyStatistics[dayKey] = stats
        }
        
        // Save statistics
        saveStatistics()
    }
    
    func getStatsForToday() -> DailyStats {
        // Get today's date
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let today = calendar.date(from: components)!
        
        // Return stats for today or create new empty stats
        return dailyStatistics[today] ?? DailyStats(date: today, totalUploaded: 0, totalDownloaded: 0, peakUploadSpeed: 0, peakDownloadSpeed: 0)
    }
    
    func getStatsForLast7Days() -> [DailyStats] {
        // Get today's date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Create array of the last 7 days
        var stats: [DailyStats] = []
        
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                if let dailyStat = dailyStatistics[date] {
                    stats.append(dailyStat)
                } else {
                    // Add empty stats for days without data
                    stats.append(DailyStats(date: date, totalUploaded: 0, totalDownloaded: 0, peakUploadSpeed: 0, peakDownloadSpeed: 0))
                }
            }
        }
        
        return stats
    }
    
    private func saveStatistics() {
        do {
            // Convert dictionary to array for easier encoding
            let statsArray = dailyStatistics.values.map { $0 }
            
            // Encode data
            let data = try JSONEncoder().encode(statsArray)
            
            // Write to file
            try data.write(to: statsURL)
        } catch {
            print("Failed to save statistics: \(error)")
        }
    }
    
    private func loadStatistics() {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: statsURL.path) else {
                return
            }
            
            // Read data from file
            let data = try Data(contentsOf: statsURL)
            
            // Decode data
            let statsArray = try JSONDecoder().decode([DailyStats].self, from: data)
            
            // Convert array to dictionary
            var statsDict: [Date: DailyStats] = [:]
            for stat in statsArray {
                statsDict[stat.date] = stat
            }
            
            dailyStatistics = statsDict
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }
    
    func resetStatistics() {
        DispatchQueue.main.async {
            self.dailyStatistics = [:]
            self.saveStatistics()
        }
    }
}

// Model for daily statistics
struct DailyStats: Codable, Identifiable {
    var id: String { date.ISO8601Format() }
    var date: Date
    var totalUploaded: UInt64
    var totalDownloaded: UInt64
    var peakUploadSpeed: Double
    var peakDownloadSpeed: Double
}