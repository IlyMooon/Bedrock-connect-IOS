# Bedrock DirectConnect iOS

[![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B%20%7C%20macOS%2013.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9%20%7C%206.0-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/xcode-15.0%2B-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/license-TODO-lightgrey.svg)](#license)

A native iOS application enabling Minecraft Bedrock console and mobile players to join any external server directly via local network redirection.

---

## Description

Minecraft Bedrock Edition on gaming consoles (**PlayStation 4/5**, **Xbox One / Series X|S**, **Nintendo Switch**) restricts multiplayer access to a small list of featured partner servers. Console players cannot freely enter arbitrary server IP addresses or custom domain names.

**Bedrock DirectConnect iOS** solves this problem by running an embedded lightweight UDP server on your iPhone or iPad. It advertises your chosen target server on the local Wi-Fi network using standard Minecraft LAN broadcast packets (`255.255.255.255:19132`). When you select the server under the **Friends > LAN Games** tab on your console, Bedrock DirectConnect issues a native Bedrock `TransferPacket` (`ID 85`).

### Standalone & Disconnectable Architecture

Unlike traditional relay proxies that must continuously forward every packet between the console and the target server, Bedrock DirectConnect hands off the connection directly:

1. The console connects to the iOS device on the local network.
2. The iOS server handles the RakNet handshake and sends a native `TransferPacket` instructing the console to connect to the target server's real IP and port.
3. The console client disconnects from the iOS device and establishes a direct connection to the external server.
4. **You can lock your iPhone or close the app immediately after the transfer succeeds.** Gameplay continues on the console with zero proxy latency and zero device battery drain.

---

## Features

- **Native Transfer Handoff:** Uses the official Minecraft Bedrock `TransferPacket` (`ID 85`) for direct client-to-server connection.
- **100% Disconnectable:** No persistent relaying required. The app can be closed once the player enters the target server.
- **Instant LAN Discovery:** Automatic UDP broadcasting on `255.255.255.255:19132` allows consoles to detect the server immediately in the "Friends" menu.
- **Live UDP Ping & MOTD:** Real-time latency measurement (ms), player counts, online status, and Minecraft section-sign (`§`) color code rendering.
- **Partner Server Presets:** One-tap selection for featured public networks including The Hive, CubeCraft Games, Galaxite, Lifeboat, and Mineville.
- **Custom Favorites Manager:** Add, edit, and store up to 5 custom server profiles with persistent storage via `UserDefaults`.
- **Live Event Log:** Real-time log tracking console detection, player Gamertags, and transfer status.
- **In-App Console Guides:** Step-by-step connection walkthroughs for PlayStation, Xbox, Nintendo Switch, and mobile platforms.
- **Pure Swift Implementation:** Built from scratch with Swift, SwiftUI, POSIX sockets, and Apple's `libz` compression library, with no external package dependencies.

---

## Screenshots / Demo

<!-- TODO: Add application screenshots showing the main dashboard, server selector, and active redirection log. -->

```
+-------------------------------------------------------+
|  Bedrock DirectConnect                          [o]   |
+-------------------------------------------------------+
|  [ PARTNER SERVERS ]   [ CUSTOM FAVORITES ]           |
|                                                       |
|  +-------------------------------------------------+  |
|  |  The Hive                 * Online  [ 42 ms ]   |  |
|  |  geo.hivebedrock.network:19132                  |  |
|  |  Bedwars, Murder Mystery & SkyWars              |  |
|  +-------------------------------------------------+  |
|                                                       |
|  TARGET SERVER CONFIGURATION                          |
|  Host: geo.hivebedrock.network       Port: 19132      |
|                                                       |
|  [                     START                       ]  |
|                                                       |
|  LIVE EVENT LOG                                       |
|  [*] UDP Broadcast active on 255.255.255.255:19132    |
|  [+] Console detected: Xbox Series X (192.168.1.45)   |
|  [+] Player Gamertag: PlayerOne                       |
|  [+] TransferPacket sent! Client redirecting...       |
+-------------------------------------------------------+
```

---

## Requirements / Prerequisites

- **Host Device:** iPhone or iPad running **iOS 16.0** or later.
- **Development Workstation:** Mac running **macOS 13.0 (Ventura)** or later.
- **IDE & Toolchain:** **Xcode 15.0+** or **Xcode 16+** supporting Swift 5.9 / Swift 6.
- **Apple Developer Account:**
  - A free personal Apple ID is sufficient for local debugging and 7-day sideloading.
  - A paid Apple Developer Program membership is required for TestFlight or App Store distribution.
- **Local Network:** The iOS device and target gaming console must be connected to the **same Wi-Fi network and subnet**. Wi-Fi client isolation (AP isolation) must be disabled on your wireless router.
- **Target Minecraft Client:** Minecraft Bedrock Edition (compatible with modern Bedrock protocol releases).

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/IlyMooon/Bedrock-connect.git "BedrockConnectIOS"
cd "BedrockConnectIOS"
```

### 2. Open in Xcode

Double-click `BedrockConnect.xcodeproj` or open it from the terminal:

```bash
open BedrockConnect.xcodeproj
```

### 3. Configure Signing

1. In Xcode, select the top-level **BedrockConnect** project in the Project Navigator.
2. Under **Targets**, select **BedrockConnect**.
3. Navigate to the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. In the **Team** dropdown, select your Apple Developer Team or personal account.
6. If needed, update the **Bundle Identifier** to a unique string (e.g., `com.yourname.BedrockConnect`).

---

## Configuration

### Local Network Permissions (`Info.plist`)

Bedrock DirectConnect requires local network broadcast access to announce the server to Minecraft clients. These permissions are configured in `BedrockConnect/App/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Bedrock DirectConnect requires local network access to broadcast your server to PlayStation, Xbox, and Nintendo Switch consoles on your Wi-Fi.</string>
<key>NSBonjourServices</key>
<array>
    <string>_minecraft._udp</string>
</array>
```

When you launch the app on your iOS device for the first time, accept the iOS permission prompt asking to find and connect to devices on your local network.

### Persistent Settings (`UserDefaults`)

User preferences and saved servers are stored locally in `UserDefaults`:

| Key | Type | Description |
| :--- | :--- | :--- |
| `bedrock_connect_favorites` | JSON `Data` | Encoded list of custom `ServerModel` entries (up to 5 servers). |
| `show_event_logs` | `Bool` | User preference toggling the visibility of the real-time event log. |

No external API keys, database connections, or `.env` files are required.

---

## How to Run

### Development Mode (Simulator or Physical Device)

1. Connect your iPhone or iPad to your Mac via USB or Wi-Fi.
2. In Xcode's toolbar, select the **BedrockConnect** scheme and choose your target device from the run destination menu.
3. Press **`Cmd + R`** or click the **Play** button to build and run.

> **Note on Simulators:** The iOS Simulator can run the UI and ping external servers. However, sending UDP broadcast packets to physical consoles across the local Wi-Fi network requires running the app on a **physical iOS device**.

### Production / Release Mode

To create an optimized release build for testing or distribution:

1. In Xcode, select **Product > Scheme > Edit Scheme...**.
2. Select **Run** on the left panel, and set **Build Configuration** to `Release`.
3. Select your connected device and press **`Cmd + R`**.

For packaging and deployment:
1. Select **Any iOS Device (arm64)** as the target.
2. Select **Product > Archive**.
3. In the Xcode Organizer, choose **Distribute App** to deploy via TestFlight, Ad Hoc, or enterprise provisioning.

### Running Unit Tests

Execute the automated test suite covering the VarInt codec, RakNet packets, Bedrock protocols, and query parser:

**Via Xcode:**
Press **`Cmd + U`** while the project is open.

**Via Terminal:**
```bash
xcodebuild test \
  -project BedrockConnect.xcodeproj \
  -scheme BedrockConnect \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Usage

### Connecting from a Console

1. **Connect to Wi-Fi:** Ensure your iPhone and console (PS4/PS5, Xbox, Switch) are on the **exact same Wi-Fi network**.
2. **Launch App:** Open **Bedrock DirectConnect** on your iPhone.
3. **Select Server:**
   - Choose a featured network from the **Partner Servers** tab (e.g., *The Hive*, *CubeCraft*).
   - Or switch to **Favorites**, tap **Add Server**, and enter your custom server IP/hostname and UDP port.
4. **Start Redirection:** Tap the green **`▶ DÉMARRER`** (Start) button.
5. **Open Minecraft on Console:**
   - Launch Minecraft Bedrock Edition on your console.
   - Select **Play** > **Friends** tab.
   - Scroll down to the **LAN Games** section.
   - Select **Bedrock DirectConnect**.
6. **Handoff Complete:** The console will connect, display "Generating Terrain...", and immediately show "Transferring to external server...".
7. **Close App:** Once your player appears in the target world, the transfer is complete. You can close or lock your iPhone.

---

## Project Structure

```
.
├── BedrockConnect.xcodeproj/        # Xcode project configuration and scheme files
├── BedrockConnect/                  # Main application source code
│   ├── App/
│   │   ├── BedrockConnectApp.swift  # SwiftUI @main entry point
│   │   └── Info.plist               # App metadata and network permission keys
│   ├── Models/
│   │   ├── LogEntry.swift           # Model representing console log events
│   │   ├── ServerConfigManager.swift# Observable state manager and UserDefaults coordinator
│   │   └── ServerModel.swift        # Server profile model and default partner configurations
│   ├── Protocol/
│   │   ├── BedrockProtocol.swift    # Minecraft packet definitions, batch framing, and zlib deflate
│   │   ├── BedrockQuery.swift       # Async UDP ping client and MOTD color parser
│   │   ├── RakNet.swift             # RakNet datagrams, acks, handshakes, and binary codecs
│   │   └── VarInt.swift             # LEB128 variable-length integer encoding and decoding
│   ├── Resources/
│   │   └── Assets.xcassets/         # App icons, accent colors, and background palettes
│   ├── Server/
│   │   ├── BedrockTransferServer.swift # Embedded UDP server, LAN broadcast, and transfer engine
│   │   └── ClientSession.swift      # Client session management and packet fragmentation
│   └── UI/
│       ├── Components/
│       │   ├── FavoriteServerCardView.swift # Card view for saved custom servers
│       │   ├── LiveLogView.swift            # Real-time event log viewer
│       │   ├── PartnerServerCardView.swift  # Card view for featured partner servers
│       │   └── SegmentedSliderBar.swift     # Custom sliding navigation tab bar
│       ├── Theme/
│       │   ├── AppTheme.swift               # Color schemes, gradients, and gaming UI styling
│       │   └── MinecraftTextParser.swift    # Minecraft formatting parser (§ codes to Text views)
│       └── Views/
│           ├── ComingSoonView.swift         # Placeholder view for upcoming features
│           ├── GameView.swift               # Primary control dashboard and server selector
│           ├── InfosView.swift              # Console help center and connection instructions
│           └── MainContainerView.swift      # Root container view with bottom tab navigation
├── Package.swift                    # Swift Package Manager manifest for core library & tests
├── Tests/                           # Unit test suite
│   └── BedrockConnectTests/
│       ├── BedrockProtocolTests.swift       # Verification of Bedrock packet serialization
│       ├── BedrockQueryTests.swift          # Verification of RakNet ping response parsing
│       ├── RakNetTests.swift                # Verification of RakNet framing and handshake logic
│       └── VarIntTests.swift                # Verification of LEB128 VarInt encode/decode routines
├── .gitignore                       # Git ignore rules for Xcode, SPM, and macOS
└── README.md                        # Project documentation
```

---

## Build / Deploy

### Archiving and Exporting IPA

To generate an unsigned `.ipa` or export for ad-hoc distribution:

```bash
# 1. Archive the application
xcodebuild archive \
  -project BedrockConnect.xcodeproj \
  -scheme BedrockConnect \
  -configuration Release \
  -archivePath ./build/BedrockConnect.xcarchive

# 2. Export IPA using an exportOptions.plist
xcodebuild -exportArchive \
  -archivePath ./build/BedrockConnect.xcarchive \
  -exportOptionsPlist ./exportOptions.plist \
  -exportPath ./build/output
```

### Sideloading via Third-Party Tools

If you do not have an active paid Apple Developer account, you can build the `.ipa` or `.app` bundle and install it on your iOS device using tools such as:
- **Xcode Devices and Simulators** (`Cmd + Shift + 2`)
- **AltStore**
- **Sideloadly**

---

## Troubleshooting / FAQ

### The server does not appear under "LAN Games" on my console
1. **Wi-Fi Isolation:** Check your home router settings and disable **AP Isolation** / **Client Isolation**. When enabled, the router blocks devices on the same Wi-Fi from discovering each other.
2. **Subnet Mismatch:** Verify that your iPhone and console share the same subnet (e.g., both have IP addresses starting with `192.168.1.xxx`). If your router provides separate 2.4 GHz and 5 GHz networks, ensure they bridge local traffic.
3. **Local Network Permission:** Open iOS **Settings > Privacy & Security > Local Network** and confirm that **BedrockConnect** is allowed.
4. **Physical Device:** Ensure you are running the app on a physical iPhone or iPad; simulators cannot broadcast UDP packets across the physical LAN.

### Port 19132 is already bound or cannot be opened
- Another app or instance on your device may be using UDP port 19132. Force-close any other network utilities or Minecraft instances, then restart Bedrock DirectConnect.

### Console displays "Could not connect: Outdated server" or "Outdated client"
- The target server you are joining may be running an incompatible version of Minecraft. Check that the target server supports your console's Minecraft version (or has Geyser/ViaVersion installed).

### Console gets stuck on "Locating Server"
- Verify that the target server is online using the in-app ping test.
- Some complex corporate or school Wi-Fi networks block UDP broadcast packets (`255.255.255.255`). Test on a standard home Wi-Fi network or mobile personal hotspot.

---

## Contributing

Contributions, bug reports, and pull requests are welcome.

1. Fork the repository.
2. Create a dedicated feature branch:
   ```bash
   git checkout -b feature/my-new-feature
   ```
3. Commit your changes with clear, descriptive commit messages:
   ```bash
   git commit -m "feat: add support for custom broadcast ports"
   ```
4. Run all unit tests to ensure no regressions:
   ```bash
   xcodebuild test -project BedrockConnect.xcodeproj -scheme BedrockConnect -destination 'platform=iOS Simulator,name=iPhone 15'
   ```
5. Push to your branch and submit a Pull Request.

---

## License

<!-- TODO: Add a LICENSE file (e.g., MIT, Apache 2.0, or GPL-3.0) to specify distribution terms. -->

This project currently has no explicit LICENSE file. See repository details or contact the author before redistribution.

---

## Credits / Acknowledgements

- **BedrockConnect & BedrockTogether:** For pioneering the concept of native LAN redirection via Minecraft Bedrock `TransferPacket`.
- **Minecraft Bedrock Protocol Specifications:** Protocol research and community packet documentation.
- **Apple zlib:** High-performance compression library powering Bedrock packet deflating.
