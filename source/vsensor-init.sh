#!/bin/bash -xe
set -x
set -e
wait_for_apt() {
    echo "Waiting for apt/dpkg lock."
    tries=0
    maxtries=10
    while sudo fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1 && [ $tries -le $maxtries ]; do
       sleep 20
       ((tries=tries+1))
    done
    if [ $tries -ge $maxtries ]; then
        echo "ERROR: Failed to get apt / dpkg lock before timeout. Please wait and try again, or fix dpkg lock manually."
        exit 1
    fi
}
if [ -f "/etc/darktrace/.user-data-success" ]; then
    echo "Not re-running user-data, already succeeded"
    exit 0
fi
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
if [[ "${vSensorUpdateKey}" == "updateKey-example" ]]; then
    echo "Skipping install in CI due to dummy key."
    exit 0
fi
wait_for_apt
sleep 10
wait_for_apt
bash <(wget https://packages-cdn.darktrace.com/install -O -) --updateKey "${vSensorUpdateKey}"
set_pushtoken.sh "${appliancePushtoken}" "${applianceHostName}:${appliancePort}" "${applianceProxy}"
set_ossensor_hmac.sh "${osSensorHMACToken}"
if [[ "${blobStorageEnable}" == "true" ]]; then
    set_pcap_azure_container.sh "${blobStorageAccountName}" "${blobStorageContainerName}"
else
    set_pcap_size.sh 0
fi
set_ossensor_loadbalancer_direct.sh "${loadBalancerDirectEnable}"
if [ "${loadBalancerDirectEnable}" -eq "0" ]; then
    set_tcp_proxy_access.sh "${privateLinkIP}/32"
    set_tcp_proxy_access.sh "168.63.129.16/32" # Allow Load Balancer Health Probes
fi
set_ephemeral.sh 1
echo "Configuration complete, vSensor is ready for use."
touch /etc/darktrace/.user-data-success
