@echo off

set instance_name=node4
set cpu_count=2
set memory_size=2048M
set mac="52:54:00:74:d6:e4"
set network_params=name=multipassbridge,mode=manual,mac=%mac%

multipass launch --name %instance_name% -c %cpu_count% -m %memory_size% --network %network_params%
multipass exec %instance_name% -- wget https://raw.githubusercontent.com/pitchblack408/kubernetes_install_scripts/main/install_k8_base.sh
multipass exec %instance_name% -- sudo bash install_k8_base.sh %mac%