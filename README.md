# Smart QR  Scanner 📱

A smart, intuitive, and feature-rich QR code scanner application built with Flutter. This app not only scans QR codes but also intelligently extracts intents and entities from the scanned text to provide contextual actions.

## ✨ Features

  * **⚡ Fast QR Code Scanning:** Quickly and efficiently scan QR codes.
  * **📚 Scan History:** Keep a log of all your scanned QR codes for future reference.
  * **❤️ Favorites:** Mark your most important scans as favorites for easy access.
  * **🎨 Customizable Themes:** Personalize your app experience with light and dark modes, and dynamic "Material You" coloring on supported devices.
  * **🤖 Smart Actions:** Using ML Kit's on-device text recognition and entity extraction, the app provides you with contextual actions based on the scanned content. This includes:
      * Opening URLs in a browser.
      * Connecting to Wi-Fi networks.
      * Adding contacts to your address book.
      * Composing emails.
      * Making phone calls.
      * Sending SMS messages.
      * Opening locations in a map application.
  * **📋 Clipboard Integration:** Easily copy scanned information to your clipboard.

## 🚀 Getting Started

To get a local copy up and running follow these simple steps.

### Prerequisites

  * Flutter SDK: Make sure you have the Flutter SDK installed on your machine. For more information, see the [Flutter documentation](https://flutter.dev/docs/get-started/install).

### Installation

1.  Clone the repo
    ```sh
    git clone https://github.com/snehashis365/smart-qr.git
    ```
2.  Install dependencies
    ```sh
    flutter pub get
    ```
3.  Run the app
    ```sh
    flutter run
    ```

## 🛠️ Built With

  * [Flutter](https://flutter.dev/) - The UI toolkit for building beautiful, natively compiled applications for mobile, web, and desktop from a single codebase.
  * [mobile\_scanner](https://pub.dev/packages/mobile_scanner) - For the QR code scanning functionality.
  * [google\_mlkit\_entity\_extraction](https://pub.dev/packages/google_mlkit_entity_extraction) - For on-device entity extraction from text.
  * [provider](https://pub.dev/packages/provider) - For state management.
  * [dynamic\_color](https://pub.dev/packages/dynamic_color) - For "Material You" dynamic theming.
  * [shared\_preferences](https://pub.dev/packages/shared_preferences) - For persisting data locally.

## 📄 License

Distributed under the Apache License 2.0. See `LICENSE` for more information.
