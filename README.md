# Wi-Fi Deauthentication Attack Script with Dual Band Support

## Description
This Bash script facilitates deauthentication attacks on Wi-Fi networks, including support for both 2.4 GHz and 5 GHz (dual-band) networks. It provides functionalities to enable/disable monitor mode, scan for available networks, list connected devices, and perform normal or dual-band deauthentication attacks. The script requires root permissions and relies on tools such as `airmon-ng`, `airodump-ng`, and `aireplay-ng` from the Aircrack-ng suite.

This tool is designed for Wi-Fi security testing, penetration testing, and educational purposes. It is particularly useful for assessing the resilience of Wi-Fi networks against deauthentication attacks.

## Features
- Enable/disable monitor mode on your wireless interface.
- Scan and display available Wi-Fi networks.
- List devices connected to a specific access point.
- Perform deauthentication attacks on single or dual-band networks.
- User-friendly interface with clear prompts.

## Dependencies
- Root privileges (required for monitor mode and packet injection).
- A wireless network card that supports monitor mode and packet injection.
- Aircrack-ng suite installed (`airmon-ng`, `airodump-ng`, `aireplay-ng`).
  - Installation: `sudo apt install aircrack-ng`


## Legal Notice
**This script is intended solely for educational, testing, and authorized security purposes.** Unauthorized use of this script to disrupt or interfere with Wi-Fi networks is illegal and unethical. Always ensure you have explicit permission from the network owner before using this tool. The author and contributors are not responsible for any misuse, damage, or legal consequences resulting from the use of this script. By using this script, you agree to use it responsibly and in compliance with all applicable laws and regulations.

## Usage
**Clone the repository:**
```
git clone https://github.com/itsandre03/Wi-Fi-Deauthentication-Attack-Script-with-Dual-Band-Support
cd Wi-Fi-Deauthentication-Attack-Script-with-Dual-Band-Support
```
   
Make the script executable:
```
chmod +x Deauther.sh
```

Run the script with root privileges:
```
sudo ./Deauther.sh
```

# To Do
- Fix any existing bugs.
- Implement additional features
