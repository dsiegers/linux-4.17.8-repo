#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# In Namespace 0 (at_ns0) using native tunnel
# Overlay IP: 10.1.1.100
# local 192.16.1.100 remote 192.16.1.200
# veth0 IP: 172.16.1.100, tunnel dev <type>00

# Out of Namespace using BPF set/get on lwtunnel
# Overlay IP: 10.1.1.200
# local 172.16.1.200 remote 172.16.1.100
# veth1 IP: 172.16.1.200, tunnel dev <type>11

function config_device {
	ip netns add at_ns0
	ip link add veth0 type veth peer name veth1
	ip link set veth0 netns at_ns0
	ip netns exec at_ns0 ip addr add 172.16.1.100/24 dev veth0
	ip netns exec at_ns0 ip link set dev veth0 up
	ip link set dev veth1 up mtu 1500
	ip addr add dev veth1 172.16.1.200/24
}

function add_gre_tunnel {
	# in namespace
	ip netns exec at_ns0 \
        ip link add dev $DEV_NS type $TYPE seq key 2 \
		local 172.16.1.100 remote 172.16.1.200
	ip netns exec at_ns0 ip link set dev $DEV_NS up
	ip netns exec at_ns0 ip addr add dev $DEV_NS 10.1.1.100/24

	# out of namespace
	ip link add dev $DEV type $TYPE key 2 external
	ip link set dev $DEV up
	ip addr add dev $DEV 10.1.1.200/24
}

function add_ip6gretap_tunnel {

	# assign ipv6 address
	ip netns exec at_ns0 ip addr add ::11/96 dev veth0
	ip netns exec at_ns0 ip link set dev veth0 up
	ip addr add dev veth1 ::22/96
	ip link set dev veth1 up

	# in namespace
	ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE seq flowlabel 0xbcdef key 2 \
		local ::11 remote ::22

	ip netns exec at_ns0 ip addr add dev $DEV_NS 10.1.1.100/24
	ip netns exec at_ns0 ip addr add dev $DEV_NS fc80::100/96
	ip netns exec at_ns0 ip link set dev $DEV_NS up

	# out of namespace
	ip link add dev $DEV type $TYPE external
	ip addr add dev $DEV 10.1.1.200/24
	ip addr add dev $DEV fc80::200/24
	ip link set dev $DEV up
}

function add_erspan_tunnel {
	# in namespace
	if [ "$1" == "v1" ]; then
		ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE seq key 2 \
		local 172.16.1.100 remote 172.16.1.200 \
		erspan_ver 1 erspan 123
	else
		ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE seq key 2 \
		local 172.16.1.100 remote 172.16.1.200 \
		erspan_ver 2 erspan_dir egress erspan_hwid 3
	fi
	ip netns exec at_ns0 ip link set dev $DEV_NS up
	ip netns exec at_ns0 ip addr add dev $DEV_NS 10.1.1.100/24

	# out of namespace
	ip link add dev $DEV type $TYPE external
	ip link set dev $DEV up
	ip addr add dev $DEV 10.1.1.200/24
}

function add_ip6erspan_tunnel {

	# assign ipv6 address
	ip netns exec at_ns0 ip addr add ::11/96 dev veth0
	ip netns exec at_ns0 ip link set dev veth0 up
	ip addr add dev veth1 ::22/96
	ip link set dev veth1 up

	# in namespace
	if [ "$1" == "v1" ]; then
		ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE seq key 2 \
		local ::11 remote ::22 \
		erspan_ver 1 erspan 123
	else
		ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE seq key 2 \
		local ::11 remote ::22 \
		erspan_ver 2 erspan_dir egress erspan_hwid 7
	fi
	ip netns exec at_ns0 ip addr add dev $DEV_NS 10.1.1.100/24
	ip netns exec at_ns0 ip link set dev $DEV_NS up

	# out of namespace
	ip link add dev $DEV type $TYPE external
	ip addr add dev $DEV 10.1.1.200/24
	ip link set dev $DEV up
}

function add_vxlan_tunnel {
	# Set static ARP entry here because iptables set-mark works
	# on L3 packet, as a result not applying to ARP packets,
	# causing errors at get_tunnel_{key/opt}.

	# in namespace
	ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE id 2 dstport 4789 gbp remote 172.16.1.200
	ip netns exec at_ns0 ip link set dev $DEV_NS address 52:54:00:d9:01:00 up
	ip netns exec at_ns0 ip addr add dev $DEV_NS 10.1.1.100/24
	ip netns exec at_ns0 arp -s 10.1.1.200 52:54:00:d9:02:00
	ip netns exec at_ns0 iptables -A OUTPUT -j MARK --set-mark 0x800FF

	# out of namespace
	ip link add dev $DEV type $TYPE external gbp dstport 4789
	ip link set dev $DEV address 52:54:00:d9:02:00 up
	ip addr add dev $DEV 10.1.1.200/24
	arp -s 10.1.1.100 52:54:00:d9:01:00
}

function add_geneve_tunnel {
	# in namespace
	ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE id 2 dstport 6081 remote 172.16.1.200
	ip netns exec at_ns0 ip link set dev $DEV_NS up
	ip netns exec at_ns0 ip addr add dev $DEV_NS 10.1.1.100/24

	# out of namespace
	ip link add dev $DEV type $TYPE dstport 6081 external
	ip link set dev $DEV up
	ip addr add dev $DEV 10.1.1.200/24
}

function add_ipip_tunnel {
	# in namespace
	ip netns exec at_ns0 \
		ip link add dev $DEV_NS type $TYPE local 172.16.1.100 remote 172.16.1.200
	ip netns exec at_ns0 ip link set dev $DEV_NS up
	ip netns exec at_ns0 ip addr add dev $DEV_NS 10.1.1.100/24

	# out of namespace
	ip link add dev $DEV type $TYPE external
	ip link set dev $DEV up
	ip addr add dev $DEV 10.1.1.200/24
}

function attach_bpf {
	DEV=$1
	SET_TUNNEL=$2
	GET_TUNNEL=$3
	tc qdisc add dev $DEV clsact
	tc filter add dev $DEV egress bpf da obj tcbpf2_kern.o sec $SET_TUNNEL
	tc filter add dev $DEV ingress bpf da obj tcbpf2_kern.o sec $GET_TUNNEL
}

function test_gre {
	TYPE=gretap
	DEV_NS=gretap00
	DEV=gretap11
	config_device
	add_gre_tunnel
	attach_bpf $DEV gre_set_tunnel gre_get_tunnel
	ping -c 1 10.1.1.100
	ip netns exec at_ns0 ping -c 1 10.1.1.200
	cleanup
}

function test_ip6gre {
	TYPE=ip6gre
	DEV_NS=ip6gre00
	DEV=ip6gre11
	config_device
	# reuse the ip6gretap function
	add_ip6gretap_tunnel
	attach_bpf $DEV ip6gretap_set_tunnel ip6gretap_get_tunnel
	# underlay
	ping6 -c 4 ::11
	# overlay: ipv4 over ipv6
	ip netns exec at_ns0 ping -c 1 10.1.1.200
	ping -c 1 10.1.1.100
	# overlay: ipv6 over ipv6
	ip netns exec at_ns0 ping6 -c 1 fc80::200
	cleanup
}

function test_ip6gretap {
	TYPE=ip6gretap
	DEV_NS=ip6gretap00
	DEV=ip6gretap11
	config_device
	add_ip6gretap_tunnel
	attach_bpf $DEV ip6gretap_set_tunnel ip6gretap_get_tunnel
	# underlay
	ping6 -c 4 ::11
	# overlay: ipv4 over ipv6
	ip netns exec at_ns0 ping -i .2 -c 1 10.1.1.200
	ping -c 1 10.1.1.100
	# overlay: ipv6 over ipv6
	ip netns exec at_ns0 ping6 -c 1 fc80::200
	cleanup
}

function test_erspan {
	TYPE=erspan
	DEV_NS=erspan00
	DEV=erspan11
	config_device
	add_erspan_tunnel $1
	attach_bpf $DEV erspan_set_tunnel erspan_get_tunnel
	ping -c 1 10.1.1.100
	ip netns exec at_ns0 ping -c 1 10.1.1.200
	cleanup
}

function test_ip6erspan {
	TYPE=ip6erspan
	DEV_NS=ip6erspan00
	DEV=ip6erspan11
	config_device
	add_ip6erspan_tunnel $1
	attach_bpf $DEV ip4ip6erspan_set_tunnel ip4ip6erspan_get_tunnel
	ping6 -c 3 ::11
	ip netns exec at_ns0 ping -c 1 10.1.1.200
	cleanup
}

function test_vxlan {
	TYPE=vxlan
	DEV_NS=vxlan00
	DEV=vxlan11
	config_device
	add_vxlan_tunnel
	attach_bpf $DEV vxlan_set_tunnel vxlan_get_tunnel
	ping -c 1 10.1.1.100
	ip netns exec at_ns0 ping -c 1 10.1.1.200
	cleanup
}

function test_geneve {
	TYPE=geneve
	DEV_NS=geneve00
	DEV=geneve11
	config_device
	add_geneve_tunnel
	attach_bpf $DEV geneve_set_tunnel geneve_get_tunnel
	ping -c 1 10.1.1.100
	ip netns exec at_ns0 ping -c 1 10.1.1.200
	cleanup
}

function test_ipip {
	TYPE=ipip
	DEV_NS=ipip00
	DEV=ipip11
	config_device
	tcpdump -nei veth1 &
	cat /sys/kernel/debug/tracing/trace_pipe &
	add_ipip_tunnel
	ethtool -K veth1 gso off gro off rx off tx off
	ip link set dev veth1 mtu 1500
	attach_bpf $DEV ipip_set_tunnel ipip_get_tunnel
	ping -c 1 10.1.1.100
	ip netns exec at_ns0 ping -c 1 10.1.1.200
	ip netns exec at_ns0 iperf -sD -p 5200 > /dev/null
	sleep 0.2
	iperf -c 10.1.1.100 -n 5k -p 5200
	cleanup
}

function cleanup {
	set +ex
	pkill iperf
	ip netns delete at_ns0
	ip link del veth1
	ip link del ipip11
	ip link del gretap11
	ip link del ip6gre11
	ip link del ip6gretap11
	ip link del vxlan11
	ip link del geneve11
	ip link del erspan11
	ip link del ip6erspan11
	pkill tcpdump
	pkill cat
	set -ex
}

trap cleanup 0 2 3 6 9
cleanup
echo "Testing GRE tunnel..."
test_gre
echo "Testing IP6GRE tunnel..."
test_ip6gre
echo "Testing IP6GRETAP tunnel..."
test_ip6gretap
echo "Testing ERSPAN tunnel..."
test_erspan v1
test_erspan v2
echo "Testing IP6ERSPAN tunnel..."
test_ip6erspan v1
test_ip6erspan v2
echo "Testing VXLAN tunnel..."
test_vxlan
echo "Testing GENEVE tunnel..."
test_geneve
echo "Testing IPIP tunnel..."
test_ipip
echo "*** PASS ***"
