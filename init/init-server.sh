#!/bin/bash
#
# Initialise a server of any description

if [ -f /etc/default/orac-init ]; then
	. /etc/default/orac-init
fi

source /opt/orac/init/functions.sh

if [ ! -d /etc/shorewall ]; then
	echo "Please run /opt/orac/init/init-security.sh script first"
	exit 1
fi

gate shorewall "Configuring shorewall"
if [ $? == 0 ]; then
	rm -f /etc/shorewall/hosts
	rm -f /etc/shorewall/interfaces
	rm -f /etc/shorewall/policy
	rm -f /etc/shorewall/rules
	rm -f /etc/shorewall/zones

	ln -s /opt/letterboxd/etc/shorewall/* /etc/shorewall

	grep VLAN_IF /etc/shorewall/params
	if [ $? != 0 ]; then
		# Default contents of /etc/shorewall/params, may not be correct on all servers
		cat >> /etc/shorewall/params <<EOF
NET_IF=eth0
VLAN_IF=eth1
EOF
	fi
fi

# Bash
cat > /root/.bash_profile <<EOF
#!/bin/bash
#
# NB: file created by init-server.sh

eval `/usr/bin/ssh-agent -s`
trap "kill $SSH_AGENT_PID" 0
EOF

cat > /etc/profile.d/letterboxd.sh <<EOF
#!/bin/sh
export PATH=$PATH:/opt/letterboxd/bin
EOF

# SSH
cat >> /root/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0CH+e9092sI23gTBbSjrki8qL2IKH0Cs2pbyyCN3YyaxsW6U8Qj7Qfpv7d99njfT9C7ce4JRVgqUO6tgoGvjlPEDWrRSdjWy+94/pTSUiysWLZ69dVFiCvv5GV9eT83GJsnJwqDm1vhPeXM4uFuMhqFMz0L4ktFs7LC2iachcKF2S41gj++AZxEF4VV6lX+m75oy2wUL99l7z1MBkTQfruxk7q6MRfZi2il9KO8/o6UjEVMLbzcGFUxwMqu26kaH4SgjLKDe8Ff0Jp0sH5WKmRzC7UCsA1JL0128mIKp6HtQDvY4jY0V3PZNHWbnR0H8oOyKzbWMY+72f5Olt7xmL root@app1
EOF
cat > /root/.ssh/id_rsa <<EOF
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,435F84D1F60E7EFB6E639188FDF32036

FiHQRCr/Pk3Jkgqa67vKWAmllOTkxruEWfalw8BNNSCddCbZ5HbfUK7uzwPus6r1
qsdcrQ/soL0mYmjOLu9HlkKKWhAhBNxPbMgu+V+MOy4NlpwBqfXC73GmINcXP1Aj
rJ3sq+u5cvU5M0hl+ITXprgyke7NzwgPUcq1oWQSWH6Y+8PL4xEU3l5rWIF4NqXL
wnB+PI5sX0Lc4lbAlrVNUIJasp0IiriKTVSPZhm5iWeQSy2mzocHxAfX/lNaKdNa
+3cCj8iJjBhQPRLG6peeey1/TNX0c4ltuoCfVVtjM7JDi9Dm4t36HLBS+XS94SHO
WOVv+/rOD2x8PD/w+D8FWPnnfZgBvZO/ICJZuGq0e+4O0SLBEHjzloQmb5lc4a5V
xGSHfxfOtF1Tr0Y2O3S+YZ9lVz45G+toEd6nuTOy/GD+hi0wDqJ5AgudZ6JCvODD
zahADsEWkdns8Ird3Xmj3QN83GSGQZmynCBddfo6IfKzASzthxsVrcltwBFn96r4
JghMpTwD1bjx64f7rZvYx+zowHE99GXCyV4RVawdtZpAUnbeW2yNPn0dvslJT6/A
Tn7Ho+tEqaIs7C1FmrAgBCnWHpjnONNbtPKjVPqbRd7Y94KDfnZBv71UY6/qr/G4
MzWQiPDNvVAXEB4GcqbZVyiGpuGY5QdREZO/Nadqg7584T9UwhVlrd5vpd2E+aew
G/1VWKJfukmIVDgkGu0hXTyWyQpI0z+nGrta7pIoGcpALr/0VFmjJ4uk+AGeY3eq
xNpAm8NZSSGOFmKzlDoAZ+qhqwvONvvwbZ+yha/QE9Ya6ObngrLtzQe6AMn0DKlE
qhnvF+9g+jlMLkfznJh+ke275EtX4kO72fRwF45p+Ghqhp6hlANKtlZEQsp+Fl4Z
c71qb0zI4prlDtLlrUs83UnTts9+8cs4YBM2CR60O3nU69mZ8JYu6Ten2+QnWWoj
ZAyVLCt3d04Euc5NVxymK/SFiVfzBqohB1hR1w+GcFv/kHTF9YXWeM81o7AuA5DH
HzYEt2uBnUd3zNj0XrUdCuBB8CRv1OIFWEvV8Aw9MPeUmTKSORkb9JiM1QZSgrT/
R4Y8g4uzYeG2PcIyyJBRA6e0zE1hJAbxTubkPLKKaKeH2mTsRYBygxPtcf0iXb7G
r9e90KA2AMK2W+5pWx0ODU0bhTPAVU2TjFOsVXB5ZQF4tCQzjnvu/H+tCHzfEHbu
0S6tDC0ixcOwz9Xrvmw2aIArGCOCtfrq0EqagkwgtsX5VVCh4M5Z+XGKjj+9uyNT
9wyxeW5Ilm5WyEklYa5Hsn57sDAXfxHpdwiq+oZGVFVPRBRNdw5d/e2wC1S+d/fd
B9oJjJja/qdXk2E7fGK8ysjqKaLdPvb7GNSqUo+TGvqmjNSPfXwFeqAoxxl646bj
3b0VUujqI4pMnq/mtb9VNQIP0uV6y47yUER887Vea7PafbJ3LADpOwqDEMPBZcsI
uVUZh5hxJUu+eLy3xB8R2oZF0w0O25dH6yxZZd6rzlUIv7NhG4B+iltbm0j7tDnv
a9wqlXxhhei++yHaFBf7CuddPerKJgpmphT3a6lTpmaW4oRLAaR/o1dRSXXbdOxJ
-----END RSA PRIVATE KEY-----
EOF
cat > /root/.ssh/id_rsa.pub <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0CH+e9092sI23gTBbSjrki8qL2IKH0Cs2pbyyCN3YyaxsW6U8Qj7Qfpv7d99njfT9C7ce4JRVgqUO6tgoGvjlPEDWrRSdjWy+94/pTSUiysWLZ69dVFiCvv5GV9eT83GJsnJwqDm1vhPeXM4uFuMhqFMz0L4ktFs7LC2iachcKF2S41gj++AZxEF4VV6lX+m75oy2wUL99l7z1MBkTQfruxk7q6MRfZi2il9KO8/o6UjEVMLbzcGFUxwMqu26kaH4SgjLKDe8Ff0Jp0sH5WKmRzC7UCsA1JL0128mIKp6HtQDvY4jY0V3PZNHWbnR0H8oOyKzbWMY+72f5Olt7xmL root@app1
EOF

