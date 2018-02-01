#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
gitdir=$PWD

##Logging setup
logfile=/var/log/vmcloak_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

##Functions
function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y --allow-unauthenticated ${@} &>> $logfile
error_check 'Package installation completed'

}

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

############################################################################################################################
############################################################################################################################
############################################################################################################################
############################################################################################################################

dir_check /mnt/windows_ISOs &>> $logfile

interface="eth0"
user="cuckoo"
ip="192.168.56.100"
distro="win7x86"
name="win7x86"

echo -e "${RED}Active interfaces${NC}"
for iface in $(ifconfig | cut -d ' ' -f1| tr '\n' ' ')
do 
  addr=$(ip -o -4 addr list $iface | awk '{print $4}' | cut -d/ -f1)
  printf "$iface\t$addr\n"
done
echo -e "${YELLOW}What is the name of the interface which has an internet connection?(ex: eth0)${NC}"
read interface
echo -e "${YELLOW}What is the name for the Cuckoo user on this machine?${NC}"
read user
echo -e "${YELLOW}What is the IP you would like to use for this machine (must be between 192.168.56.100-200)?${NC}"
read ip
echo -e "${YELLOW}How much RAM would you like to allocate for this machine?${NC}"
read ram
echo -e "${YELLOW}How many CPU cores would you like to allocate for this machine?${NC}"
read cpu
echo -e "${YELLOW}What is the distro? (winxp, win7x86, win7x64, win81x86, win81x64, win10x86, win10x64)${NC}"
read distro
echo -e "${YELLOW}Enter in a serial key now if you would like to be legit, otherwise you can skip this for now.${NC}"
read serial
echo -e "${YELLOW}What is the name for this machine?${NC}"
read name
echo
read -n 1 -s -p "Please place your Windows ISO in the folder under /mnt/windows_ISOs and press any key to continue"
echo
print_status "${YELLOW}Mounting ISO if needed${NC}"
mkdir  /mnt/$name &>> $logfile
mount -o loop,ro /mnt/windows_ISOs/* /mnt/$name &>> $logfile
error_check 'Mounted ISO'

print_status "${YELLOW}Installing genisoimage${NC}"
apt-get install mkisofs genisoimage libffi-dev python-pip libssl-dev python-dev -y &>> $logfile
error_check 'Prereqs installed'

if [ ! -d "/usr/local/bin/vmcloak" ]; then
print_status "${YELLOW}Installing vmcloak${NC}"
pip install vmcloak  &>> $logfile
pip install -U pytest pytest-xdist &>> $logfile
error_check 'Installed vmcloak'
fi

print_status "${YELLOW}Checking for host only interface${NC}"
sudo -i -u $user VBoxManage hostonlyif create
#sudo -i -u $user VBoxManage hostonlyif ipconfig vboxnet0 --ip 10.1.1.254
sudo -i -u $user VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1
#vmcloak-iptables 10.1.1.0/24 $interface
vmcloak-iptables 192.168.56.0/24 $interface

echo -e "${YELLOW}Creating VM, some interaction may be required${NC}"
#if [ -z "$serial" ]
#then
#sudo -i -u $user VBoxManage hostonlyif ipconfig vboxnet0 --ip 10.1.1.254
su - $user -c "vmcloak init --$distro --vm-visible --ramsize $ram --cpus $cpu --iso-mount /mnt/$name $name" &>> $logfile
#su - $user "vmcloak init --$distro --vm-visible --ip $ip --gateway 10.1.1.254 --netmask 255.255.255.0 --ramsize $ram pus $cpu --iso-mount /mnt/$name $name" &>> $logfile
#su - $user "vmcloak init --$distro --vm-visible --ip $ip --gateway 192.168.56.1 --netmask 255.255.255.0 --ramsize $ram pus $cpu --iso-mount /mnt/$name $name" &>> $logfile
error_check 'Created VM'
#else
#su - $user "vmcloak init --$distro --serial-key $serial --vm-visible --ip $ip --gateway 10.1.1.254 --netmask 255.255.255.0 --ramsize $ram pus $cpu --iso-mount /mnt/$name $name" &>> $logfile
#error_check 'Created VM'
#fi
#sudo -i -u $user VBoxManage hostonlyif ipconfig vboxnet0 --ip 10.1.1.254

echo -e "${YELLOW}Installing programs on VM, some interaciton may be required${NC}"
su - $user -c "vmcloak install $name --vm-visible adobe9 dotnet cuteftp firefox flash wic python27 pillow java removetooltips wallpaper chrome winrar" 
#flash wic pillow java adobe11010 cuteftp dotnet461 firefox chrome winrar
#error_check 'Installed adobe9 wic pillow dotnet40 java7 removetooltips on VMs'

echo -e "${YELLOW}Modifying VM Hardware${NC}"
'0019eC'
hexchars="0123456789ABCDEF"
end=$( for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/-\1/g' )
macadd="00-19-EC$end"

 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBIOSFirmwareMajor	'0'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBIOSFirmwareMinor	'0'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBIOSReleaseDate	'07/02/2015'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBIOSReleaseMajor	'4'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBIOSReleaseMinor	'6'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBIOSVendor	'Hewlett-Packard'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBIOSVersion	'F.49'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBoardAssetTag	'Base Board Asset Tag'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBoardBoardType	'10'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBoardLocInChass	'Base Board Chassis Location'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBoardProduct	'string:30FB'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBoardSerial	'1CADF91932'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBoardVendor	'Compal'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiBoardVersion	'01.9A'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiChassisAssetTag	'ems013463'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiChassisSerial	'string:A74E'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiChassisType	'10'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiChassisVendor	'Compal'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiChassisVersion	'N/A'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiOEMVBoxRev	'ABA'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiOEMVBoxVer	'ABS 70/71 79 7A 7B 7C'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiProcManufacturer	'AMD processor'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiProcVersion	'AMD Turion(tm) X2 Dual-core Mobile RM-74'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiSystemFamily	'103C_5335KV'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiSystemProduct	'HP EliteBook Folio'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiSystemSKU	'HP Pavilion dv4 Notebook PC'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiSystemSerial	'5EFF05DA4E474DBBA373BB4E6F96BE9D'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiSystemUuid	'7059D844-1CF3-4BBF-B347-1EE644F1D969'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiSystemVendor	'Hewlett-Packard'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/pcbios/0/Config/DmiSystemVersion	'string:1'

controller=`sudo -i -u $user VBoxManage showvminfo $name --machinereadable | grep SATA`
if [[ -z "$controller" ]]; then
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/piix3ide/0/Config/PrimaryMaster/ModelNumber	'HITACHI HTD723216L9SA60'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/piix3ide/0/Config/PrimaryMaster/SerialNumber	'379E6F6659874FC2B0AE'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/piix3ide/0/Config/PrimaryMaster/FirmwareRevision	'FC2ZF50B'
else
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/ahci/0/Config/Port0/ModelNumber	'HITACHI HTD723216L9SA60'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/ahci/0/Config/Port0/SerialNumber	'379E6F6659874FC2B0AE'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/ahci/0/Config/Port0/FirmwareRevision	'FC2ZF50B'
fi
if [[ -z "$controller" ]]; then
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/piix3ide/0/Config/PrimarySlave/ATAPIVendorId	'HITACHI'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/piix3ide/0/Config/PrimarySlave/ATAPIRevision	'B504'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/piix3ide/0/Config/PrimarySlave/ATAPIProductId	'M2764AFI'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/piix3ide/0/Config/PrimarySlave/ATAPISerialNumber	'2727F3EA983D458AAB19'
else
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/ahci/0/Config/Port1/ATAPIVendorId	'HITACHI'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/ahci/0/Config/Port1/ATAPIRevision	'B504'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/ahci/0/Config/Port1/ATAPIProductId	'M2764AFI'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/ahci/0/Config/Port1/ATAPISerialNumber	'2727F3EA983D458AAB19'
fi

 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/acpi/0/Config/AcpiOemId	'PTLTD'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/acpi/0/Config/AcpiCreatorId	'MSFT'
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/Devices/acpi/0/Config/AcpiCreatorRev	'03000001'
 sudo -i -u $user VBoxManage modifyvm $name --macaddress1	$macadd

 sudo -i -u $user VBoxManage modifyvm $name --cpuidset 00000001 000306a9 04100800 7fbae3ff bfebfbff
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000002/eax  0x20444d41	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000002/ebx  0x69727554	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000002/ecx  0x74286e6f	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000002/edx  0x5820296d	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000003/eax  0x75442032	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000003/ebx  0x432d6c61	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000003/ecx  0x2065726f	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000003/edx  0x69626f4d	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000004/eax  0x5220656c	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000004/ebx  0x34372d4d	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000004/ecx  0x20202020	
 sudo -i -u $user VBoxManage setextradata $name VBoxInternal/CPUM/HostCPUID/80000004/edx  0x00202020
 sudo -i -u $user VBoxManage modifyvm $name --paravirtprovider legacy  


echo -e "${YELLOW}Starting VM and creating a running snapshot...Please wait.${NC}"  
su - $user -c "vmcloak snapshot $name $name" &>> $logfile
error_check 'Created snapshot'

echo
echo -e "${YELLOW}The VM is located under your user $user home folder under .vmcloak, you will need to register this with Virtualbox on your cuckoo account.${NC}"  

