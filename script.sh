#!/bin/bash

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
   echo "Please run with sudo privileges"
   exit 1
fi

# Cleanup function
cleanup() {
    echo "Cleaning up existing configuration..."
    # Delete namespaces
    ip netns del ns1 2>/dev/null || true
    ip netns del ns2 2>/dev/null || true
    ip netns del router-ns 2>/dev/null || true
    
    # Delete interfaces and bridges
    ip link del veth-ns1 2>/dev/null || true
    ip link del veth-ns2 2>/dev/null || true
    ip link del veth-router0 2>/dev/null || true
    ip link del veth-router1 2>/dev/null || true
    ip link del br0 2>/dev/null || true
    ip link del br1 2>/dev/null || true
    
    # Reset IP forwarding and bridge settings
    echo 0 > /proc/sys/net/ipv4/ip_forward
    modprobe -r bridge
    modprobe bridge
}

# Execute cleanup
cleanup

# Load bridge module and enable IP forwarding
modprobe bridge
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

echo "Creating Network Bridges..."
ip link add br0 type bridge
ip link add br1 type bridge

# Disable STP and enable bridge forwarding
ip link set br0 type bridge stp_state 0
ip link set br1 type bridge stp_state 0
ip link set br0 type bridge forward_delay 0
ip link set br1 type bridge forward_delay 0

# Bring up bridges
ip link set br0 up
ip link set br1 up

# Assign IPs to bridges
ip addr add 192.168.1.254/24 dev br0
ip addr add 192.168.2.254/24 dev br1

echo "Creating Network Namespaces..."
ip netns add ns1
ip netns add ns2
ip netns add router-ns

echo "Creating Virtual Interfaces and Connections..."
# Create veth pairs
ip link add veth-ns1 type veth peer name veth-ns1-br
ip link add veth-ns2 type veth peer name veth-ns2-br
ip link add veth-router0 type veth peer name veth-router0-br
ip link add veth-router1 type veth peer name veth-router1-br

# Move interfaces to namespaces
ip link set veth-ns1 netns ns1
ip link set veth-ns2 netns ns2
ip link set veth-router0 netns router-ns
ip link set veth-router1 netns router-ns

# Connect to bridges
ip link set veth-ns1-br master br0
ip link set veth-ns2-br master br1
ip link set veth-router0-br master br0
ip link set veth-router1-br master br1

# Configure loopback interfaces
ip netns exec ns1 ip link set lo up
ip netns exec ns2 ip link set lo up
ip netns exec router-ns ip link set lo up

# Bring up all interfaces
ip link set veth-ns1-br up
ip link set veth-ns2-br up
ip link set veth-router0-br up
ip link set veth-router1-br up

ip netns exec ns1 ip link set veth-ns1 up
ip netns exec ns2 ip link set veth-ns2 up
ip netns exec router-ns ip link set veth-router0 up
ip netns exec router-ns ip link set veth-router1 up

echo "Configuring IP Addresses..."
# Configure namespace IPs
ip netns exec ns1 ip addr add 192.168.1.2/24 dev veth-ns1
ip netns exec ns2 ip addr add 192.168.2.2/24 dev veth-ns2

# Configure router IPs
ip netns exec router-ns ip addr add 192.168.1.1/24 dev veth-router0
ip netns exec router-ns ip addr add 192.168.2.1/24 dev veth-router1

echo "Setting Up Routing..."
# Enable IP forwarding in router
ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1

# Configure routes
ip netns exec ns1 ip route del default 2>/dev/null || true
ip netns exec ns2 ip route del default 2>/dev/null || true

ip netns exec ns1 ip route add default via 192.168.1.1
ip netns exec ns2 ip route add default via 192.168.2.1

# Configure router namespace iptables
ip netns exec router-ns iptables -F
ip netns exec router-ns iptables -t nat -F
ip netns exec router-ns iptables -t mangle -F
ip netns exec router-ns iptables -X
ip netns exec router-ns iptables -t nat -X
ip netns exec router-ns iptables -t mangle -X

# Set default policies
ip netns exec router-ns iptables -P INPUT ACCEPT
ip netns exec router-ns iptables -P FORWARD ACCEPT
ip netns exec router-ns iptables -P OUTPUT ACCEPT

# Add basic forwarding rules
ip netns exec router-ns iptables -A FORWARD -i veth-router0 -o veth-router1 -j ACCEPT
ip netns exec router-ns iptables -A FORWARD -i veth-router1 -o veth-router0 -j ACCEPT

# Configure NAT
ip netns exec router-ns iptables -t nat -A POSTROUTING -o veth-router1 -j MASQUERADE
ip netns exec router-ns iptables -t nat -A POSTROUTING -o veth-router0 -j MASQUERADE

# Host system iptables rules for bridges
iptables -F
iptables -t nat -F
iptables -P FORWARD ACCEPT
iptables -A FORWARD -m physdev --physdev-is-bridged -j ACCEPT


echo "Testing cross-namespace connectivity:"
ip netns exec ns1 ping -c 2 192.168.2.2
ip netns exec ns2 ping -c 2 192.168.1.2

echo "Done!"
