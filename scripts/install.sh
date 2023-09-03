#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
                  _                          
                 //                          
   _   o __  _  //  __.  __  ,     _   __  __
  /_)_<_/ (_</_</_ (_/|_/ (_/_    /_)_/ (_(_)
 /                         /     /           
'                         '     '            

The easiest way set up a Tor exit, middle, or bridge relay.

A free tool by Science & Design - https://scidsg.org

EOF
sleep 3

# Install whiptail if not present
sudo apt update && sudo apt -y dist-upgrade
sudo apt install -y whiptail git

git clone https://github.com/glenn-sorrentino/Pi-Relay-Test.git
sleep 6
cd ~/Pi-Relay-Test/scripts/
sleep 3

OPTION=$(whiptail --title "Tor Relay Configurator" --menu "Choose your relay type" 15 60 4 \
"1" "Exit relay" \
"2" "Middle relay" \
"3" "Bridge relay" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Your chosen option:" $OPTION
    if [ $OPTION = "1" ]; then
        bash exit_relay.sh
    elif [ $OPTION = "2" ]; then
        bash middle_relay.sh
    elif [ $OPTION = "2" ]; then
        cbash bridge_relay.sh
    fi
else
    echo "You chose Cancel."
fi
