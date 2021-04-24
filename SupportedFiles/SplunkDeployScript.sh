#!/bin/sh
sudo su
ADMIN_INIT_PASSWORD=Lima1Mike2India3Romeo4
USER1_INIT_PASSWORD=HotelSierra
USER2_INIT_PASSWORD=MikeTango
USER3_INIT_PASSWORD=RomeoJuliet
parted --script /dev/sdc mklabel gpt mkpart primary ext4 68.7GB
sleep 3 
mkfs -t ext4 /dev/sdc1
mkdir /media/splunk_ext
mount /dev/sdc1 /media/splunk_ext
grep /media/splunk_ext /etc/mtab >>/etc/fstab
mkdir /media/splunk_ext/splunk
ln -s /media/splunk_ext/splunk /opt/splunk
yum -y install wget
wget -O 'splunk-8.1.2-545206cc9f7-linux-2.6-x86_64.rpm' 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.2&product=splunk&filename=splunk-8.1.2-545206cc9f70-linux-2.6-x86_64.rpm&wget=true'
setenforce 0
rpm -i 'splunk-8.1.2-545206cc9f70-linux-2.6-x86_64.rpm'
setenforce 1
cd /opt/splunk/bin
./splunk enable boot-start --accept-license --answer-yes --auto-ports --no-prompt --seed-passwd $ADMIN_INIT_PASSWORD
./splunk start
./splunk add index 'azure_alerts' -maxDataSize 'auto_high_volume' -auth admin:$ADMIN_INIT_PASSWORD
./splunk add index 'o365_alerts' -maxDataSize 'auto_high_volume' -auth admin:$ADMIN_INIT_PASSWORD
./splunk http-event-collector enable -uri 'https//localhost:8089' -enable-ssl '1' -auth admin:$ADMIN_INIT_PASSWORD 

./splunk http-event-collector create new-token -uri 'https://127.0.0.1:8089' -name o365_alerts_hec-001' -disabled '0' -description '0365 Alerts HEC' -indexes '0365_alerts' -index 'o365_alerts' -use-ack '0' -auth admin.$ADM1N INIT PASSWORD 
./splunk add user 'user1' -role 'Admin' -password $USER1_INIT_PASSWORD -full-name 'USER One' -force-change-pass 'true' -auth admin:$ADMIN_INIT_PASSWORD
./splunk add user 'user2' -role 'Admin' -password $USER2_INIT_PASSWORD -full-name 'User Two' -force-change-pass 'true' -auth admin:$ADMIN_INIT_PASSWORD 
./splunk add user 'user3' -role 'Admin' -password $USER3_INIT_PASSWORD -full-name 'User Three' -force-change-pass 'true' -auth admin:$ADMIN_INIT_PASSWORD 
./splunk edit user 'admin' -role 'User' -auth admin:$ADMIN_INIT_PASSWORD
sudo firewall-cmd --permanent --zone=public --add-port=8000/tcp
sudo firewall-cmd --permanent --zone=public --add-port=8088/tcp 
sudo systemctl restart firewalld 
EOF 
