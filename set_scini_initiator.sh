#!/bin/bash
if ls -al /etc/emc/scaleio | grep scini_test.txt; then
systemctl restart scini
exit
else
#mdmIP=mdmIpAddress
echo -e "test" > /etc/emc/scaleio/scini_test.txt
export uuid=$(uuidgen)
source ~/.profile
echo -e "ini_guid $uuid\nmdm $MDM_IP" > /etc/emc/scaleio/drv_cfg.txt
sleep 10
systemctl restart scini
fi
