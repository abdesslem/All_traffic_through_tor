#!/bin/sh

# Destinations you don't want routed through Tor
TOR_EXCLUDE="192.168.0.0/16 172.16.0.0/12 10.0.0.0/8"

# The UID Tor runs as
# change it if, starting tor, the command 'ps -e | grep tor' returns a different UID
TOR_UID="debian-tor"

# Tor's TransPort
TOR_PORT="9040"


function init {
killall -q "chrome dropbox iceweasel skype icedove thunderbird firefox chromium xchat transmission"
}

function start {

echo "VirtualAddrNetwork 10.192.0.0/10" > /etc/tor/torrc
echo "AutomapHostsOnResolve 1" >> /etc/tor/torrc
echo "TransPort 9040"  >> /etc/tor/torrc
echo "DNSPort 53"    >>  /etc/tor/torrc

# Run tor 
if [ ! -e /var/run/tor/tor.pid ]; then
   echo -e "Tor is not running! -- starting tor for you\n"
   service tor start
   sleep 6
fi
        

#save iptabes rules
if ! [ -f /etc/network/iptables.rules ]; then
   iptables-save > /etc/network/iptables.rules
   echo -e " Saved iptables rules"
fi

#delete iptables rules
iptables -F
iptables -t nat -F

#change /etc/resolv.conf file 
service resolvconf stop 2>/dev/null || echo -e "resolvconf already stopped"
echo -e 'nameserver 127.0.0.1' > /etc/resolv.conf
echo -e "Modified resolv.conf to use Tor"



# Add iptables rules file

# set iptables nat
iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A OUTPUT -p udp -m owner --uid-owner $TOR_UID -m udp --dport 53 -j REDIRECT --to-ports 53

#resolve .onion domains mapping 10.192.0.0/10 address space
iptables -t nat -A OUTPUT -p tcp -d 10.192.0.0/10 -j REDIRECT --to-ports 9040
iptables -t nat -A OUTPUT -p udp -d 10.192.0.0/10 -j REDIRECT --to-ports 9040
#exclude local addresses
        for NET in $TOR_EXCLUDE 127.0.0.0/9 127.128.0.0/10; do
                iptables -t nat -A OUTPUT -d $NET -j RETURN
        done
#redirect all other output through TOR
        iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $TOR_PORT
        iptables -t nat -A OUTPUT -p udp -j REDIRECT --to-ports $TOR_PORT
        iptables -t nat -A OUTPUT -p icmp -j REDIRECT --to-ports $TOR_PORT

        #accept already established connections
        iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

        #exclude local addresses
        for NET in $TOR_EXCLUDE 127.0.0.0/8; do
                iptables -A OUTPUT -d $NET -j ACCEPT
        done
 #allow only tor output
        iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT
        iptables -A OUTPUT -j REJECT

}


function stop {

echo -e " Deleted all iptables rules"
iptables -F
iptables -t nat -F
if [ -f /etc/network/iptables.rules ]; then
iptables-restore < /etc/network/iptables.rules
rm /etc/network/iptables.rules
echo -e "Restored iptables rules"
fi
rm /etc/tor/torrc
service resolvconf start 2>/dev/null || echo -e "resolvconf already started"
}


function change {

service tor stop
sleep 1
service tor start
sleep 4
echo -e "Restarted tor daemon and forced to change nodes\n"
sleep 1
}

case "$1" in
    start)
start
init
;;
    stop)
stop
;;
    restart)
$0 stop
sleep 1
$0 start

;;
    change)
change
;;
    *)
echo -e " Anonymous surf module\n
usage: privacy.sh start/stop/change 

"

exit 1
;;
esac

