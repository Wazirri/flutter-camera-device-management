#!/bin/bash

# Function to fix the dashboard_screen.dart file
fix_dashboard_screen() {
  # Replace String with String? in _buildNetworkItem function
  sed -i 's/String value/String? value/g' lib/screens/dashboard_screen.dart
  sed -i 's/String label/String label/g' lib/screens/dashboard_screen.dart
  
  # Replace String with String? in _buildThermalItem function
  sed -i 's/String temperature/String? temperature/g' lib/screens/dashboard_screen.dart
  
  # Fix double.parse calls with null safety
  sed -i 's/double.parse(sysInfo.totalRam)/double.parse(sysInfo.totalRam ?? "0")/g' lib/screens/dashboard_screen.dart
  sed -i 's/double.parse(sysInfo.freeRam)/double.parse(sysInfo.freeRam ?? "0")/g' lib/screens/dashboard_screen.dart
  
  # Fix eth0 and ppp0 Map handling
  sed -i 's/_buildNetworkItem(.Ethernet., sysInfo.eth0)/_buildNetworkItem("Ethernet", sysInfo.eth0["ip"]?.toString() ?? "N\/A")/g' lib/screens/dashboard_screen.dart
  sed -i 's/_buildNetworkItem(.PPP., sysInfo.ppp0)/_buildNetworkItem("PPP", sysInfo.ppp0["ip"]?.toString() ?? "N\/A")/g' lib/screens/dashboard_screen.dart

  # Fix nullable string values
  sed -i 's/_getTemperatureColor(double.tryParse(sysInfo.cpuTemp) ?? 0)/_getTemperatureColor(sysInfo.getCpuTempValue() ?? 0)/g' lib/screens/dashboard_screen.dart
  sed -i 's/value: sysInfo.totalConns/value: sysInfo.totalConns ?? "0"/g' lib/screens/dashboard_screen.dart
  sed -i 's/_buildThermalItem(.SoC., sysInfo.socThermal)/_buildThermalItem("SoC", sysInfo.socThermal ?? "N\/A")/g' lib/screens/dashboard_screen.dart
  sed -i 's/_buildThermalItem(.GPU., sysInfo.gpuThermal)/_buildThermalItem("GPU", sysInfo.gpuThermal ?? "N\/A")/g' lib/screens/dashboard_screen.dart
  sed -i 's/_buildNetworkItem(.Active Sessions., sysInfo.sessions)/_buildNetworkItem("Active Sessions", sysInfo.sessions ?? "0")/g' lib/screens/dashboard_screen.dart
}

# Apply fixes if the dashboard_screen.dart file exists
if [ -f lib/screens/dashboard_screen.dart ]; then
  fix_dashboard_screen
  echo "Fixed dashboard_screen.dart successfully"
else
  echo "dashboard_screen.dart not found"
fi
