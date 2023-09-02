#!/bin/bash

whiptail --title "Exit Relay Warning" --msgbox "You're about to set up an exit relay. Before doing so make sure you understand your local laws and the implications of acting as a Tor exit node.\n\nNever operate an exit relay from home." 16 64
whiptail --title "Are You Sure You're Sure?" --msgbox "We'll stress this again - make sure you understand your local laws, and NEVER RUN AN EXIT RELAY FROM HOME." 16 64

# Verify the CPU architecture
architecture=$(dpkg --print-architecture)
echo "CPU architecture is $architecture"

# Install Packages
sudo apt-get install -y apt-transport-https whiptail unattended-upgrades apt-listchanges bc nginx

# Determine the codename of the operating system
codename=$(lsb_release -c | cut -f2)

# Add the tor repository to the sources.list.d
echo "deb [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | sudo tee /etc/apt/sources.list.d/tor.list
echo "deb-src [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | sudo tee -a /etc/apt/sources.list.d/tor.list

# Download and add the gpg key used to sign the packages
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | sudo tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null

# Update system packages
sudo apt-get update && sudo apt-get -y dist-upgrade && sudo apt-get -y autoremove

# Install tor and tor debian keyring
sudo apt-get install -y tor deb.torproject.org-keyring nyx

# Configure Tor Auto Updates
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOL
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=TorProject";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::Automatic-Reboot "true";
EOL

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "5";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "1";
EOL

SERVER_IP=$(curl -s ifconfig.me)
current_dir=$(pwd)
wget https://raw.githubusercontent.com/scidsg/tor-exit-notice/main/index.html -O /var/www/html/index.html

# Function to configure Tor as a middle relay
configure_tor() {
    # Parse the value and the unit from the provided accounting max
    max_value=$(echo "$4" | cut -d ' ' -f1)
    max_unit=$(echo "$4" | cut -d ' ' -f2)

    # Calculate the new max value (half of the provided value)
    new_max_value=$(echo "scale=2; $max_value / 2" | bc -l)

    echo "Log notice file /var/log/tor/notices.log
RunAsDaemon 1
ControlPort 9051
CookieAuthentication 1
ORPort $7
Nickname $1
RelayBandwidthRate $2
RelayBandwidthBurst $3
AccountingMax $new_max_value $max_unit
ContactInfo $5 $6
DirPort 80
DirPortFrontPage /var/www/html/index.html

# Reject server's own IP
ExitPolicy reject $SERVER_IP:*

# Reject private networks
ExitPolicy reject 0.0.0.0/8:*
ExitPolicy reject 169.254.0.0/16:*
ExitPolicy reject 127.0.0.0/8:*
ExitPolicy reject 192.168.0.0/16:*
ExitPolicy reject 10.0.0.0/8:*
ExitPolicy reject 172.16.0.0/12:*

# Accept common web ports and other ports
ExitPolicy accept *:80
ExitPolicy accept *:443
ExitPolicy accept *:20-23
ExitPolicy accept *:53
ExitPolicy accept *:110
ExitPolicy accept *:143
ExitPolicy accept *:993
ExitPolicy accept *:995

# Reject common P2P ports
ExitPolicy reject *:6881-6889

# Reject everything else
ExitPolicy reject *:*

# Paths to the private data directories for this relay
DataDirectory /var/lib/tor
DisableDebuggerAttachment 0" | sudo tee /etc/tor/torrc

    sudo systemctl restart tor
    sudo systemctl enable tor
}


# Function to validate Tor relay nickname
validate_nickname() {
    local nn="$1"
    
    # Check for length
    if [ "${#nn}" -lt 1 ] || [ "${#nn}" -gt 19 ]; then
        return 1
    fi

    # Check for valid characters: only alphanumeric characters
    if [[ ! "$nn" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 1
    fi

    return 0
}

# Function to collect user information
collect_info() {
    while true; do
        nickname=$(whiptail --inputbox "Give your relay a nickname. Avoid special characters and spaces." 8 78 "piExitRelay$(date +"%y%m%d")" --title "Nickname" 3>&1 1>&2 2>&3)
        if validate_nickname "$nickname"; then
            break
        else
            whiptail --title "Invalid Nickname" --msgbox "Please enter a valid nickname. It must be between 1 and 19 characters and can only include alphanumeric characters." 10 78
        fi
    done

    bandwidth=$(whiptail --inputbox "Enter your desired bandwidth per second" 8 78 "1 MB" --title "Bandwidth Rate" 3>&1 1>&2 2>&3)
    burst=$(whiptail --inputbox "Enter your burst rate per second" 8 78 "2 MB" --title "Bandwidth Burst" 3>&1 1>&2 2>&3)
    max=$(whiptail --inputbox "Set your maximum bandwidth each month" 8 78 "1.5 TB" --title "Accounting Max" 3>&1 1>&2 2>&3)
    contactname=$(whiptail --inputbox "Please enter your name" 8 78 "Random Person" --title "Contact Name" 3>&1 1>&2 2>&3)        
    email=$(whiptail --inputbox "Please enter your contact email. Use the provided format to help avoid spam." 8 78 "<nobody AT example dot com>" --title "Contact Email" 3>&1 1>&2 2>&3)        
    port=$(whiptail --inputbox "Which port do you want to use?" 8 78 "443" --title "Relay Port" 3>&1 1>&2 2>&3)
}

# Main function to orchestrate the setup
setup_tor_relay() {
    collect_info
    configure_tor "$nickname" "$bandwidth" "$burst" "$max" "$contactname" "$email" "$port"
}

sudo mkdir -p /var/log/tor
sudo chown debian-tor:debian-tor /var/log/tor
sudo chmod 700 /var/log/tor
sudo chown -R debian-tor:debian-tor /var/lib/tor
sudo chmod 700 /var/lib/tor
sudo systemctl restart tor

setup_tor_relay

echo "
✅ Installation complete!
                                               
Pi Relay is a product by Science & Design. 
Learn more about us at https://scidsg.org.
Have feedback? Send us an email at feedback@scidsg.org.

To run Nyx, enter: sudo -u debian-tor nyx

To configure a Waveshare 2.13 inch e-paper display, enter: curl -sSL https://raw.githubusercontent.com/scidsg/pi-relay/main/scripts/waveshare-2_13in-eink-display.sh | sudo bash
"
