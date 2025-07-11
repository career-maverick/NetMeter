# NetMeter

<div align="center">
  <img src="screenshots/netmeter-icon.png" alt="NetMeter Icon" width="128" height="128">
</div>

## Overview

NetMeter is a lightweight, non-intrusive macOS application designed to monitor and display real-time internet speed directly in the macOS menu bar. It offers users instant visibility into their current network activity and provides additional statistics through a clean, expandable bubble interface.

NetMeter combines function and elegance, offering an intuitive user experience for casual users, developers, gamers, and remote professionals who want to keep tabs on their network usage without cluttering their workspace.

## Features

- **Menu Bar Display**: Real-time upload and download speeds directly in your macOS menu bar
- **Detailed Statistics**: Access comprehensive network statistics by left-clicking the menu bar icon
- **Interface Information**: View active network interface, internal IP, and external IP
- **Usage Tracking**: Monitor daily and peak usage statistics
- **Non-Intrusive Design**: Runs completely in the background with no Dock icon
- **Resource Efficient**: Minimal CPU and memory usage
- **Error Handling**: Robust error handling with user-friendly error messages
- **Accessibility**: Full VoiceOver support and accessibility compliance
- **Performance Monitoring**: Built-in performance tracking and optimization
- **Multiple Network Services**: Fallback external IP services for reliability

## Architecture

NetMeter follows modern Swift development practices with a clean, testable architecture:

### Core Components

- **NetworkMonitor**: Handles network interface monitoring and statistics calculation
- **StatusBarManager**: Manages menu bar display and user interactions
- **AppController**: Coordinates application lifecycle and window management
- **NetworkInterfaceStats**: Provides low-level network interface access
- **AppState**: Manages persistent data and statistics

### Design Patterns

- **MVVM**: Model-View-ViewModel pattern with SwiftUI
- **Dependency Injection**: Loose coupling between components
- **Protocol-Oriented Programming**: Interfaces for testability
- **Error Handling**: Comprehensive error types and recovery mechanisms
- **Memory Management**: Proper use of weak references and cleanup

## Screenshots

<div align="center">
  <img src="screenshots/menu-bar.png" alt="Menu Bar Display" width="400"><br>
  <em>Menu Bar Display</em>
  
  <br><br>
  
  <img src="screenshots/statistics-popup.png" alt="Statistics Popup" width="300"><br>
  <em>Statistics Popup</em>
  
  <br><br>
  
  <img src="screenshots/preferences-1.png" alt="Preferences Window" width="400"><br>
  <em>Preferences Window 1</em>

  <br><br>
  
  <img src="screenshots/preferences-2.png" alt="Preferences Window" width="400"><br>
  <em>Preferences Window 2</em>

  <br><br>
  
  <img src="screenshots/preferences-3.png" alt="Preferences Window" width="400"><br>
  <em>Preferences Window 3</em>
</div>

## System Requirements

- macOS 14+ (Sonoma or later)
- Apple Silicon or Intel processors
- Minimal disk space (< 10MB)
- Network access permissions

## Installation

### Option 1: Download Release

1. Go to the [Releases](https://github.com/career-maverick/netmeter/releases) page
2. Download the latest `.dmg` file
3. Open the DMG and drag NetMeter to your Applications folder
4. Launch NetMeter from your Applications folder

### Option 2: Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/netmeter.git
```

2. Open the project in Xcode:
```bash
cd netmeter
open NetMeter.xcodeproj
```

3. Build the project (⌘+B) and run (⌘+R)

4. To create a standalone app, select Product > Archive

## Usage

- **View Network Speed**: NetMeter automatically displays your current upload and download speeds in the menu bar
- **View Detailed Statistics**: Left-click the menu bar icon to open the statistics popup
- **Access Settings and Quit**: Right-click the menu bar icon to access preferences or quit the application
- **Configure Settings**: Adjust refresh interval, display options, and startup behavior in Preferences

## Configuration

Access preferences by right-clicking the NetMeter icon in the menu bar and selecting "Preferences...". From there, you can:

### General Settings
- Toggle launch at startup
- Adjust the refresh interval (0.5s to 5.0s)
- Enable/disable notifications
- Configure auto-retry on network errors

### Display Settings
- Toggle compact display mode
- Show/hide speed units
- Choose display format (both, upload only, download only)
- Select theme (Light, Dark, System Default)

### Network Settings
- View current network interface information
- Test network connectivity
- Refresh external IP address
- Restart network monitoring

## Technical Details

NetMeter operates by monitoring network interfaces using native macOS frameworks. It:

- Uses IOKit and Network frameworks for accurate network statistics
- Updates data at customizable intervals (default: 1 second)
- Stores daily usage statistics locally using JSON persistence
- Runs efficiently with minimal resource usage
- Implements comprehensive error handling and recovery
- Provides performance monitoring and optimization

### Error Handling

The app includes robust error handling for:
- Network interface detection failures
- External IP service unavailability
- Permission denials
- Invalid network data
- Memory allocation failures

### Performance Features

- Caching for interface descriptions and active interfaces
- Performance monitoring with logging
- Efficient timer-based updates
- Memory leak prevention with proper cleanup

## Testing

NetMeter includes comprehensive unit tests covering:

- Network speed calculations
- Data formatting functions
- Error handling scenarios
- Performance benchmarks
- Integration tests with mocked components

Run tests in Xcode with ⌘+U or use:
```bash
xcodebuild test -project NetMeter.xcodeproj -scheme NetMeter
```

## Security & Privacy

- **Local Data Only**: All statistics are stored locally on your device
- **No Data Collection**: NetMeter does not collect or transmit any personal data
- **External IP Services**: Uses multiple fallback services for external IP detection
- **Network Permissions**: Properly handles macOS network access permissions

## Troubleshooting

### Common Issues

1. **"No active network interfaces found"**
   - Check that your network connection is active
   - Try restarting the application
   - Verify network permissions in System Preferences

2. **External IP shows "Unavailable"**
   - This is normal if external services are temporarily down
   - The app will automatically retry with fallback services
   - Check your internet connection

3. **High CPU usage**
   - Reduce the refresh interval in preferences
   - Restart the application
   - Check for other network monitoring apps

### Debug Mode

Enable debug logging by setting the environment variable:
```bash
export OS_ACTIVITY_MODE=debug
```

## Contributing

Contributions are welcome! If you'd like to contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the project's coding style and includes appropriate tests.

<<<<<<< HEAD
=======
### Development Guidelines

- Follow Swift style guidelines
- Add unit tests for new functionality
- Update documentation for new features
- Test on multiple macOS versions
- Ensure accessibility compliance

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
>>>>>>> 825a2d1 (updated code performance and removed obsolete libraries to leverage moder framework)

## Acknowledgments

- [Apple's Network Framework Documentation](https://developer.apple.com/documentation/network)
- [SwiftUI Framework](https://developer.apple.com/xcode/swiftui/)
- Icons and design inspiration from macOS system utilities
- Community feedback and testing

## Roadmap

### Planned Features
- [ ] Historical data charts and graphs
- [ ] Bandwidth alerts and notifications
- [ ] Export functionality (CSV/JSON)
- [ ] Multiple interface monitoring
- [ ] Customizable thresholds
- [ ] Dark mode improvements
- [ ] Widget support

### Technical Improvements
- [ ] Core Data integration for better data persistence
- [ ] Async/await implementation for network operations
- [ ] Enhanced performance profiling
- [ ] More comprehensive test coverage
- [ ] Accessibility improvements

---

<div align="center">
  <p>Made with love for the macOS community</p>
  <p><strong>Version 1.0</strong> - Production Ready</p>
</div>
