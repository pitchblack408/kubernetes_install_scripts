@echo off

set instance_name=node3
set cpu_count=2
set memory_size=2048M
set mac="52:54:00:74:d6:e3"
set network_params=name=multipassbridge,mode=manual,mac=%mac%
set static_ip=192.168.20.15

multipass launch --name %instance_name% -c %cpu_count% -m %memory_size% --network %network_params%
multipass exec %instance_name% -- wget https://raw.githubusercontent.com/pitchblack408/kubernetes_install_scripts/main/install_k8_base.sh
multipass exec %instance_name% -- sudo bash install_k8_base.sh %mac% %static_ip% &
REM timeout /t 5 /nobreak > nul
multipass exec %INSTANCE_NAME% -- kubectl version --client > nul 2>&1
if %errorlevel% neq 0 (
    echo kubectl is not installed on instance %INSTANCE_NAME%.
    rem Add your handling logic if kubectl is not installed
) else (
    echo kubectl is installed on instance %INSTANCE_NAME%.
    rem Add your handling logic if kubectl is installed
)