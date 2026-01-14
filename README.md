# Money Load Manager

**Money Load Manager** is a 100% offline Android application designed for mobile financial service agents. It automates the tracking of daily transactions by reading incoming SMS messages in real-time, detecting Flexiload, bKash, and utility bill transactions without manual data entry.

## 🚀 Key Features

*   **Real-time SMS Monitoring**: Automatically captures and parses incoming transaction SMS messages.
*   **Offline-First Privacy**: All data is stored locally on the device using SQLite. No internet connection is required, and no data is sent to external servers.
*   **Automated Tracking**: Detects and categorizes transactions (Cash In, Cash Out, Bill Pay) from various providers.
*   **Training Manager**: A built-in tool that allows users to teach the app new SMS patterns for different providers without waiting for app updates.
*   **Day-End Summaries**: Provides clear financial summaries and visualized data for daily reconciliation.
*   **Safe & Free**: No paid AI services, no ads, and no recurring costs.

## 🛠 Technology Stack

This project is built using **Flutter** and **Dart**.

*   **Core**: [Flutter](https://flutter.dev) (UI Toolkit)
*   **Database**: [sqflite](https://pub.dev/packages/sqflite) (Local SQL Storage)
*   **SMS Handling**: [another_telephony](https://pub.dev/packages/another_telephony) (Background SMS listening)
*   **Visualization**: [fl_chart](https://pub.dev/packages/fl_chart) (Graphs and Charts)
*   **Permissions**: [permission_handler](https://pub.dev/packages/permission_handler) (Android Runtime Permissions)

## 📱 Getting Started

### Prerequisites

*   Flutter SDK (3.10.7 or later)
*   Android Studio / VS Code
*   Android Device (Minimum SDK 21)

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/md-sada-mia/money-load-manager.git
    cd money_load_manager
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the app**:
    ```bash
    flutter run
    ```

### Permissions

The app requires the following permissions to function correctly:
*   `READ_SMS`: To read existing messages for history.
*   `RECEIVE_SMS`: To capture real-time transaction alerts.

## 📖 Basic Usage

1.  **Grant Permissions**: On first launch, allow SMS permissions.
2.  **Dashboard**: View your daily total Cash In, Cash Out, and Earnings.
3.  **Training**: If an SMS is not recognized, go to `Settings > Training Manager` to add the pattern.
4.  **Reports**: Check the `Transactions` tab for a detailed list of all matched messages.

---
*Built with ❤️ for financial agents.*
