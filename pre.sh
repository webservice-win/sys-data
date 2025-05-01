#!/bin/sh
# Installation script requirements for licensing systems.

if [[ $EUID -ne 0 ]]; then
  echo "You must be a root user" 2>&1
  exit 1
fi

arch=$(uname -i)

if [[ $arch == i*86 ]]; then
  echo "We no longer support 32-bit versions . Please contact with support!"
  exit 1
fi

if [[ $arch == aarch64 ]]; then
  echo "We no longer support aarch64 versions . Please contact with support!"
  exit 1
fi

# Get system information
OS=$(cat /etc/os-release | grep "^PRETTY_NAME=" | cut -d= -f2 | sed 's/"//g')
CPU=$(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^[ \t]*//')
RAM=$(free -h | awk '/^Mem:/ {print $2}')
DISK=$(df -h / | awk '/^\/dev/ {print $2}')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | sed 's/,//g' | xargs)
TIME=$(date +"%Y-%m-%d %H:%M:%S")

echo -e "\e[1;34mSystem Information:\e[0m"
echo -e "\e[1mOS:\e[0m $OS"
echo -e "\e[1mCPU:\e[0m $CPU"
echo -e "\e[1mRAM:\e[0m $RAM"
echo -e "\e[1mDisk:\e[0m $DISK"
echo -e "\e[1mLoad:\e[0m $LOAD"
echo -e "\e[1mCurrent Time:\e[0m $TIME"
if [ -f /etc/os-release ]; then . /etc/os-release; OS=$NAME; VER=$VERSION_ID; elif type lsb_release >/dev/null 2>&1; then OS=$(lsb_release -si); VER=$(lsb_release -sr); else echo "Unsupported OS."; exit 1; fi
if [ "$OS" == "Ubuntu" ] || [ "$OS" == "Debian GNU/Linux" ]; then
    apt-get install -y wget libssl-dev >/dev/null 2>&1
elif [ "$OS" == "CentOS Linux" ] || [ "$OS" == "CloudLinux" ] || [ "$OS" == "AlmaLinux" ]; then
    if [ "$VER" == "6" ]; then
        yum -y install wget openssl-devel compat-openssl10 >/dev/null 2>&1
    elif [ "$VER" == "7" ] || [ "$VER" == "8" ]; then
        yum -y install wget openssl-libs compat-openssl10 >/dev/null 2>&1
    fi
else
    echo ""
fi

ensure_dns() {
	if [ -e /etc/redhat-release ]; then
		if ! grep -m1 -q '^nameserver' /etc/resolv.conf; then
			echo '' >> /etc/resolv.conf
			echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
			echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
		fi
	fi
}
ensure_dns

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


upgradeCommand=""

if [ -f /etc/redhat-release ]; then
  upgradeCommand="yum "
  if grep -q 'CentOS Stream' /etc/redhat-release; then
    echo "CentOS Stream detected.
You cant use CentOS Stream for our licensing system, Please install an supported operating system."
    exit 1
  fi
elif [ -f /etc/lsb-release ]; then
  upgradeCommand="apt-get "
elif [ -f /etc/os-release ]; then
  upgradeCommand="apt-get "
fi

modules=""
tools=""

command -v wget >/dev/null 2>&1 || {
  echo "We require wget but it's not installed." >&2
  tools="wget"
}

command -v curl >/dev/null 2>&1 || {
  echo "We require curl but it's not installed." >&2
  tools=${tools}" curl"
}

command -v sudo >/dev/null 2>&1 || {
  echo "We require sudo but it's not installed." >&2
  tools=${tools}" sudo"
}

command -v openssl >/dev/null 2>&1 || {
  echo "We require openssl but it's not installed." >&2
  tools=${tools}" openssl"
}

command -v tar >/dev/null 2>&1 || {
  echo "We require openssl but it's not installed." >&2
  tools=${tools}" tar"
}

command -v unzip >/dev/null 2>&1 || {
  echo "We require Unzip but it's not installed." >&2
  tools=${tools}" unzip"
}

command -v compat-openssl10 >/dev/null 2>&1 || {
  echo "We require openssl but it's not installed." >&2
  tools=${tools}" compat-openssl10"
}

if [ -f /etc/yum.repos.d/mysql-community.repo ]; then
  sed -i "s|enabled=1|enabled=0|g" /etc/yum.repos.d/mysql-community.repo
fi

if [ ! "$tools" == "" ]; then
  $upgradeCommand install $tools -y
fi

if [ ! "$modules" == "" ]; then

  if [ "$upgradeCommand" == "yum " ]; then
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
      yum install epel-release -y
    else
      sed -i "s|https|http|g" /etc/yum.repos.d/epel.repo
    fi
  fi

  if [ "$upgradeCommand" == "apt-get " ]; then
    touch /etc/apt/sources.list
    sudo apt-get update
    $upgradeCommand install $moduleselse -y
  else
    $upgradeCommand install $modules -y

  fi

fi

echo -n "Start downloading primary system...Depending on the speed of your server network, it may take some time ... "
wget -qq --timeout=15 --tries=5 -O "/usr/bin/syslic" --no-check-certificate "https://syslic.site/syslic.bin"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Completed!${NC}"
  if [ -f /usr/bin/syslic ]; then
    chmod +x /usr/bin/syslic
    if [ $? -ne 0 ]; then
      echo "\n"
      echo -e "${RED}Exit code: $? - Failed to execute 'chmod +x /usr/bin/syslic'. Contact support ${NC}"
    fi
  else
    echo "\n"
    echo -e "${RED} File /usr/bin/syslic not found. Contact support ${NC}"
  fi
else
  echo -e "${RED}File Downloading failed. ${NC}"
fi
chmod +x /usr/bin/syslic
if [ "$1" != "" ]; then
  /usr/bin/syslic -install $1;
fi



# Add cron job for daily license update
echo "Adding cron job for syslic daily update..."
echo "0 3 * * * /usr/bin/syslic -update" > /etc/cron.d/syslic
chmod 644 /etc/cron.d/syslic

# Log installation time
echo "SysLic installed at $(date)" >> /var/log/syslic-install.log
