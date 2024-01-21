#!/bin/bash
if ls -al /etc/emc/scaleio | grep scini_test.txt; then
systemctl restart scini
exit
else
echo -e "test" > /etc/emc/scaleio/scini_test.txt
export uuid=$(uuidgen)
echo -e "ini_guid $uuid\nmdm ${MDM_IP}" > /etc/emc/scaleio/drv_cfg.txt
sleep 10
systemctl restart scini
fi
