
Overview

This script sets up a simple network topology using Linux network namespaces, virtual Ethernet (veth) pairs, and network bridges. It creates a basic router between two namespaces, enabling communication between them.

Topology

ns1 (192.168.1.2) connected to br0 via veth-ns1.

ns2 (192.168.2.2) connected to br1 via veth-ns2.

router-ns (192.168.1.1 & 192.168.2.1) acting as a bridge between br0 and br1.

IP forwarding and basic iptables rules are configured to allow communication.

Requirements

Linux system with root/sudo privileges

iproute2 package installed (for ip command)

iptables installed

Usage

Make the script executable:

chmod +x script.sh

Run the script with sudo:

sudo ./script.sh

Features

Creates and cleans up network namespaces

Sets up network bridges and connects namespaces

Configures IP addresses and routing

Enables packet forwarding and basic firewall rules

Tests connectivity using ping

Cleanup

To remove the created network namespaces and bridges, re-run the script as it includes a cleanup function.

Testing

You can manually test connectivity using:

ip netns exec ns1 ping -c 2 192.168.2.2
ip netns exec ns2 ping -c 2 192.168.1.2

Troubleshooting

Ensure you have sudo privileges.

Check if the ip and iptables commands are available.

Use ip netns list to verify namespaces.

Use ip link show to check interface statuses.
