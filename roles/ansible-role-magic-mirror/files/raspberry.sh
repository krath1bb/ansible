#!/bin/bash
# This is an installer script for MagicMirror2. It works well enough
# that it can detect if you have Node installed, run a binary script
# and then download and run MagicMirror2.

if [ $USER == 'root' ]; then
	 echo Please login as a user to execute the MagicMirror installation,  not root
	 exit 1
fi

echo -e "\e[0m"
echo '$$\      $$\                     $$\           $$\      $$\ $$\                                          $$$$$$\'
echo '$$$\    $$$ |                    \__|          $$$\    $$$ |\__|                                        $$  __$$\'
echo '$$$$\  $$$$ | $$$$$$\   $$$$$$\  $$\  $$$$$$$\ $$$$\  $$$$ |$$\  $$$$$$\   $$$$$$\   $$$$$$\   $$$$$$\  \__/  $$ |'
echo '$$\$$\$$ $$ | \____$$\ $$  __$$\ $$ |$$  _____|$$\$$\$$ $$ |$$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\  $$$$$$  |'
echo '$$ \$$$  $$ | $$$$$$$ |$$ /  $$ |$$ |$$ /      $$ \$$$  $$ |$$ |$$ |  \__|$$ |  \__|$$ /  $$ |$$ |  \__|$$  ____/'
echo '$$ |\$  /$$ |$$  __$$ |$$ |  $$ |$$ |$$ |      $$ |\$  /$$ |$$ |$$ |      $$ |      $$ |  $$ |$$ |      $$ |'
echo '$$ | \_/ $$ |\$$$$$$$ |\$$$$$$$ |$$ |\$$$$$$$\ $$ | \_/ $$ |$$ |$$ |      $$ |      \$$$$$$  |$$ |      $$$$$$$$\'
echo '\__|     \__| \_______| \____$$ |\__| \_______|\__|     \__|\__|\__|      \__|       \______/ \__|      \________|'
echo '                       $$\   $$ |'
echo '                       \$$$$$$  |'
echo '                        \______/'
echo -e "\e[0m"

doInstall=1
true=1
false=0
# Define the tested version of Node.js.
NODE_TESTED="v20.8.0" # "v16.13.0"
NPM_TESTED="V10.1.0" # "V7.11.2"
NODE_STABLE_BRANCH="${NODE_TESTED:1:2}.x"
USER=`whoami`
PM2_FILE=pm2_MagicMirror.json
forced_arch=
pm2setup=$false
JustProd="--only=prod"

trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}
beginswith() { case $2 in "$1"*) true;; *) false;; esac; }

cd $HOME

mac=$(uname -s)
if [ 0 -eq 1 ]; then
	if [ "$0" == "bash" ]; then
		logdir=.
	else
		if [ $mac == 'Darwin' ]; then
			echo this is a mac >> $logfile
			logdir=$(dirname "$0")
		else
			# put the log where the script is located
				logdir=$(dirname $(readlink -f "$0"))
		fi
	fi

	# if the script was execute from the web
	if [[ $logdir != *"MagicMirror/installers"* ]]; then
		# use the MagicMirror/installers folder, if setup
		if [ -d MagicMirror ]; then
			cd ~/MagicMirror/installers >/dev/null
				logdir=$(pwd)
			cd - >/dev/null
		else
			# use the users home folder if initial install
			logdir=$HOME
		fi
	fi
fi
logfile=$HOME/install.log
echo install log being saved to $logfile

# Determine which Pi is running.
date +"install starting  - %a %b %e %H:%M:%S %Z %Y" >>$logfile
ARM=$(uname -m)
echo installing on $ARM processor system >>$logfile
lsb_info=$(lsb_release -a 2>/dev/null)
echo the os is $lsb_info >> $logfile
OS=$(echo $lsb_info  | awk -F: '{print $NF}' | awk '{print $1}')
#if [ $OS == "buster" ]; then
#	echo install on buster is broken, ending install
#	exit 4
#fi
if [ $ARM == "armv6ll" ]; then
	echo -e "nodejs version required for MagicMirror is no longer available for armv6l (pi0w) devices\ninstallation aborted" | tee -a $logfile
	date +"install ended - %a %b %e %H:%M:%S %Z %Y" >>$logfile
	exit 3
fi

if [ $OS = "buster" ]; then
	NODE_TESTED="v18.18.0" # "v16.13.1"
	NPM_TESTED="V9.8.1" # "V7.11.2"
	NODE_MAJOR=18
	NODE_STABLE_BRANCH="${NODE_TESTED:1:2}.x"
	#OS=$(lsb_release -a 2>/dev/null | grep name: | awk '{print $2}')
	#if [ $OS == "buster" ]; then
	#	NODE_MAJOR=18
	#fi
	:
fi
if [ "$(echo $lsb_info | grep -i raspbian)." != '.' ]; then
	# file only exists on raspian
	#ostype=$(cat /boot/issue.txt)
	#echo issue.txt info $ostype >>$logfile
	#if [ "$(echo $ostype | grep stage4)." == '.' ]; then
	#	echo wrong operating system type, need full desktop version | tee -a $logfile
	#	date +"install completed - %a %b %e %H:%M:%S %Z %Y" >>$logfile
	#	exit 1
	#fi
	# is system in grpahical mode
	if [ $(systemctl get-default | grep -i Graphical | wc -l) -ne 1 ]; then
		# no
		# is Xorg installed?
		if [ "$(type Xorg)." == "." ]; then
			# no
			echo wrong operating system type, need full desktop version | tee -a $logfile
		else
			# yes, but running in text mode
			echo system running in command line mode, need graphical desktop, see raspi-config | tee -a $logfile
		fi
		date +"install completed - %a %b %e %H:%M:%S %Z %Y" >>$logfile
		exit 1
	else
		# graphical mode, is X running?
		if [ "$(pidof Xorg)." == "." -a "$(pidof wayfire)." == "." ]; then
			echo system running in command line mode, configured for graphical desktop, please reboot | tee -a $logfile
			date +"install completed - %a %b %e %H:%M:%S %Z %Y" >>$logfile
			exit 2
		fi
	fi
fi

# Define helper methods.
function command_exists () { type "$1" &> /dev/null ;}
function verlte() {  [ "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ];}
function verlt() { [ "$1" = "$2" ] && return 1 || verlte $1 $2 ;}

# Update before first apt-get
if [ $mac != 'Darwin' ]; then
	# clear the command hash
   hash -r
	echo -e "\e[96mUpdating packages ...\e[0m" | tee -a $logfile
	upgrade=$false
	update=$(LC_ALL=C  sudo apt-get update --allow-releaseinfo-change>&1)

	# save return code before any other command is issued
	update_rc=$?
	echo $update >> $logfile
    if [ $(echo $update | grep -i "is not valid yet" | wc -l) -ne 0 ]; then
       echo -e "\e[91mSystem date/time is in the past, please correct ...\e[0m" | tee -a $logfile
       exit 1
    fi
    # if we had  a problem with update
	if [ $update_rc -ne 0 ]; then

        echo -e "\e[91mUpdate failed, retrying installation ...\e[0m" | tee -a $logfile
        if [ $(echo $update | grep -e "apt-secure" -e "oldstable" | wc -l) -eq 1 ]; then
	        update=$(sudo apt-get update --allow-releaseinfo-change 2>&1)
	        update_rc=$?
	        echo $update >> $logfile
	        if [ $update_rc -ne 0 ]; then
		        echo "second apt-get update failed" $update | tee -a $logfile
		        exit 1
	        else
		        echo "second apt-get update completed ok" >> $logfile
		        upgrade=$true
	        fi
        fi
	else
		echo "apt-get update  completed ok" >> $logfile
		upgrade=$true
	fi
	if [ $upgrade -eq $true ]; then
	   sudo apt-get install pv -y >>$logfile
	   echo "apt-get upgrade  started" >> $logfile
	   upgrade_result=$(sudo apt-get --assume-yes upgrade  2>&1 | pv -l -p)
		 upgrade_rc=$?
		 echo apt-get upgrade result ="rc=$upgrade_rc $upgrade_result" >> $logfile
	fi
	# Installing helper tools
	echo -e "\e[96mInstalling helper tools ...\e[0m" | tee -a $logfile
	sudo apt-get --assume-yes   install  curl wget git build-essential unzip >>$logfile
fi

if [ $(LC_ALL=C free -m | grep Mem | awk '{print $2}') -le 512 ]; then
	echo " this should be a raspberry pi 02w" >>$logfile
	export NODE_OPTIONS="--max-old-space-size=1024"
	# if the swap space is small
	if [ $(LC_ALL=C free -m | grep Swap | awk '{print $2}') -lt 512 ]; then
		echo "increasing swap space" >>$logfile
		sudo dphys-swapfile swapoff >>$logfile
		sudo sed '/SWAPSIZE=100/ c \SWAPSIZE=1024' -i /etc/dphys-swapfile
		#sudo nano /etc/dphys-swapfile
		sudo dphys-swapfile setup >>$logfile
		sudo dphys-swapfile swapon >>$logfile
	fi 
fi

npminstalled=$false


#if [ 
# ($OS == "bullseye" -o $OS == "bookworm") -a 
if [ $ARM != "armv6l" ]; then
	# check for node installed
	nv=$(node -v 2>/dev/null)
	t=$(dpkg --print-architecture| grep armhf)
	if [ "$t." != "." ]; then
		t=":armv7l"
	fi 
	# if not
	if [ "$nv." == "." ]; then
		echo node not installed, trying via apt-get >>$logfile
		# install the default
		sudo apt-get update >/dev/null
		ni=$(sudo apt-get install "nodejs$t" "npm$t" -y 2>&1)
		# log it
		echo $ni >>$logfile
		# if npm not installed
		echo npm not installed, trying via apt-get >>$logfile
		if [ "$(npm -v 2>/dev/null)." == "." ]; then
			echo npm installed now, install n >>$logfile
			# install it too
			ni=$(sudo apt-get install npm -y 2>&1)
			echo $ni >>$logfile
			npminstalled=$true
		fi
	fi
	# if n is not installed
	NODE_MAJOR=20
	# if n is not installed
	if [ "$(which n)." == "." ]; then
		# install it globally
		sudo npm i n -g  >>$logfile 2>&1

	fi
	arch=
	# is npm installed?
	echo "installing on $OS" >>$logfile
	npm=$(which npm)
	if [ "$npm". != "." ]; then
		npminstalled=$true
		# yes
		# check if node is already at the right level
		# get node version
		v=$(node -v)
		if [ "$v." != "." ]; then
			if [ ${v:1:2} -lt ${NODE_TESTED:1:2} ]; then
				echo -e "\e[96minstalling correct version of node and npm, please wait\e[0m" | tee -a $logfile
				#nr=$(sudo npm install -g n)
				if [ "$t." != "." ]; then
					t="--arch armv7l"
				fi 
				sudo n ${NODE_TESTED:1} $t  >> $logfile
				PATH="$PATH"
				nodev=$(node -v)
				if [ "${nodev:0:3}" != ${NODE_TESTED:0:3} ]; then
					echo node failed to install, exiting | tee -a $logfile
					exit
				fi
			fi
		else
			echo -e "\e[92mnode failed to execute, please check the error message and resolve before trying again\e[0m" | tee -a $logfile
			date +"install aborted - %a %b %e %H:%M:%S %Z %Y" >>$logfile
			exit 2
		fi
	fi
fi
if [ $npminstalled == $false ]; then
	# Check if we need to install or upgrade Node.js.
	echo -e "\e[96mCheck current Node installation ...\e[0m" | tee -a $logfile
	NODE_INSTALL=false
	if command_exists node; then
		echo -e "\e[0mNode currently installed. Checking version number." | tee -a $logfile
		NODE_CURRENT=$(node -v)
		if [ "$NODE_CURRENT." == "." ]; then
		   NODE_CURRENT="V1.0.0"
			 echo forcing low Node version  >> $logfile
		fi
		echo -e "\e[0mMinimum Node version: \e[1m$NODE_TESTED\e[0m" | tee -a $logfile
		echo -e "\e[0mInstalled Node version: \e[1m$NODE_CURRENT\e[0m" | tee -a $logfile
		if verlt $NODE_CURRENT $NODE_TESTED; then
			echo -e "\e[96mNode should be upgraded.\e[0m" | tee -a $logfile
			NODE_INSTALL=true

			# Check if a node process is currenlty running.
			# If so abort installation.
			node_running=$(ps -ef | grep node | grep -v grep)
			if [ "$node_running." != "." ]; then
				echo -e "\e[91mA Node process is currently running. Can't upgrade." | tee -a $logfile
				echo "Please quit all Node processes and restart the installer." | tee -a $logfile
				echo
				echo $node_running | tee -a $logfile
				exit;
			fi

		else
			echo -e "\e[92mNo Node.js upgrade necessary.\e[0m" | tee -a $logfile
		fi

	else
		echo -e "\e[93mNode.js is not installed.\e[0m" | tee -a $logfile
		NODE_INSTALL=true
	fi
	# Install or upgrade node if necessary.
	if $NODE_INSTALL; then

		echo -e "\e[96mInstalling Node.js ...\e[0m" | tee -a $logfile

		# Fetch the latest version of Node.js from the selected branch
		# The NODE_STABLE_BRANCH variable will need to be manually adjusted when a new branch is released. (e.g. 7.x)
		# Only tested (stable) versions are recommended as newer versions could break MagicMirror.
		if [ $mac == 'Darwin' ]; then
		  brew install node
		else
			if [ $OS == 'bullseye' ]; then
				if [ -e /usr/share/doc/nodejs/api/embedding.json.gz ]; then
					sudo chmod 666 /usr/share/doc/nodejs/api/embedding.json.gz
				fi
			fi
			
			# sudo apt-get install --only-upgrade libstdc++6
			node_info=$(curl -sL https://deb.nodesource.com/setup_$NODE_STABLE_BRANCH | sudo -E bash - )
			echo Node release info = $node_info >> $logfile
			#sudo apt-get install -y nodejs
			if [ "$(echo $node_info | grep -i "Unsupported architecture")." == "." -a $ARM != "armv6l" ]; then
				sudo apt-get install -y nodejs
			else
				echo node $NODE_STABLE_BRANCH version installer not available, doing manually >>$logfile
				# no longer supported install
				sudo apt-get install -y --only-upgrade libstdc++6  >> $logfile
				# have to do it manually
				ARM1=$ARM
				if [ $ARM == 'armv6l' ]; then 
					export NODE_OPTIONS="--max-old-space-size=1024"
					if [ $(LC_ALL=C free -m | grep Swap | awk '{print $2}') -lt 512 ]; then
						echo "increasing swap space" >>$logfile
						sudo dphys-swapfile swapoff
						sudo sed '/SWAPSIZE=100/ c \SWAPSIZE=1024' -i /etc/dphys-swapfile
						#sudo nano /etc/dphys-swapfile
						sudo dphys-swapfile setup
						sudo dphys-swapfile swapon
					fi 
					curl -sL https://unofficial-builds.nodejs.org/download/release/${NODE_TESTED}/node-${NODE_TESTED}-linux-armv6l.tar.gz >node_release-${NODE_TESTED}.tar.gz
					node_ver=$NODE_TESTED
				else
					node_vnum=$(echo $NODE_STABLE_BRANCH | awk -F. '{print $1}')
					if [ $ARM == 'x86_64' ]; then
						ARM1= x64
					fi
					# get the highest release number in the stable branch line for this processor architecture
					node_ver=$(curl -sL https://nodejs.org/download/release/index.tab | grep $ARM1 | grep -m 1 v$node_vnum | awk '{print $1}')
					echo "latest release in the $NODE_STABLE_BRANCH family for $ARM is $node_ver" >> $logfile
					# download that file
					curl -sL https://nodejs.org/download/release/v$node_ver/node-v$node_ver-linux-$ARM1.tar.gz >node_release-$node_ver.tar.gz
				fi
				cd /usr/local
				echo using release tar file = node_release-$node_ver.tar.gz >> $logfile
				sudo tar --strip-components 1 -xzf  $HOME/node_release-$node_ver.tar.gz
				cd - >/dev/null
				rm ./node_release-$node_ver.tar.gz
			fi
			# get the new node version number
			new_ver=$(LC_ALL=C node -v 2>&1)
			# if there is a failure to get it due to a missing library
			if [ $(echo $new_ver | grep "not found" | wc -l) -ne 0 ]; then
			  #
				sudo apt-get install -y --only-upgrade libstdc++6  >> $logfile
			fi
			echo node version is $(node -v 2>&1) >>$logfile
		fi
		echo -e "\e[92mNode.js installation Done! version=$(node -v)\e[0m" | tee -a $logfile
	fi
	# Check if we need to install or upgrade npm.
	echo -e "\e[96mCheck current NPM installation ...\e[0m" | tee -a $logfile
	NPM_INSTALL=false
	if command_exists npm; then
		echo -e "\e[0mNPM currently installed. Checking version number." | tee -a $logfile
		NPM_CURRENT='V'$(npm -v)
		echo -e "\e[0mMinimum npm version: \e[1m$NPM_TESTED\e[0m" | tee -a $logfile
		echo -e "\e[0mInstalled npm version: \e[1m$NPM_CURRENT\e[0m" | tee -a $logfile
		if verlt $NPM_CURRENT $NPM_TESTED; then
			echo -e "\e[96mnpm should be upgraded.\e[0m" | tee -a $logfile
			NPM_INSTALL=true

			# Check if a node process is currently running.
			# If so abort installation.
			if pgrep "npm" > /dev/null; then
				echo -e "\e[91mA npm process is currently running. Can\'t upgrade." | tee -a $logfile
				echo "Please quit all npm processes and restart the installer." | tee -a $logfile
				exit;
			fi
		else
			echo -e "\e[92mNo npm upgrade necessary.\e[0m" | tee -a $logfile
		fi
	else
		echo -e "\e[93mnpm is not installed.\e[0m" | tee -a $logfile
		NPM_INSTALL=true
	fi

	# Install or upgrade node if necessary.
	if $NPM_INSTALL; then

		echo -e "\e[96mInstalling npm ...\e[0m" | tee -a $logfile

		# Fetch the latest version of npm from the selected branch
		# The NODE_STABLE_BRANCH variable will need to be manually adjusted when a new branch is released. (e.g. 7.x)
		# Only tested (stable) versions are recommended as newer versions could break MagicMirror.

		#NODE_STABLE_BRANCH="9.x"
		#curl -sL https://deb.nodesource.com/setup_$NODE_STABLE_BRANCH | sudo -E bash -
	  #
		# if this is a mac, npm was installed with node
		if [ $mac != 'Darwin' ]; then
			sudo apt-get install -y npm  >>$logfile
		fi
		# update to the latest.
		echo upgrading npm to latest >> $logfile
		sudo npm i -g npm@${NPM_TESTED:1:1}  >>$logfile
		NPM_CURRENT='V'$(npm -v)
		echo -e "\e[92mnpm installation Done! version=$NPM_CURRENT\e[0m" | tee -a $logfile
	fi
else
		NPM_CURRENT='V'$(npm -v)
fi
#exit
# Install MagicMirror
cd ~
if [ $doInstall == 1 ]; then
	if [ -d "$HOME/MagicMirror" ] ; then
		echo -e "\e[93mIt seems like MagicMirror is already installed." | tee -a $logfile
		echo -e "To prevent overwriting, the installer will be aborted." | tee -a $logfile
		echo -e "Please rename the \e[1m~/MagicMirror\e[0m\e[93m folder and try again.\e[0m" | tee -a $logfile
		echo ""
		#echo -e "If you want to upgrade your installation run \e[1m\e[97mupgrade-script\e[0m from the ~/MagicMirror/installers directory." | tee -a $logfile
		echo ""
		exit;
	fi

	echo -e "\e[96mCloning MagicMirror ...\e[0m" | tee -a $logfile
	if git clone --depth=1 https://github.com/MagicMirrorOrg/MagicMirror.git; then
		echo -e "\e[92mCloning MagicMirror Done!\e[0m" | tee -a $logfile
		# replace faulty run-start.sh
		curl -sL https://raw.githubusercontent.com/sdetweil/MagicMirror_scripts/master/run-start.sh >MagicMirror/run-start.sh
		chmod +x MagicMirror/run-start.sh
		sudo touch /etc/chromium-browser/customizations/01-disable-update-check 2>/dev/null;echo CHROMIUM_FLAGS=\"\$\{CHROMIUM_FLAGS\} --check-for-update-interval=31536000\" | sudo tee /etc/chromium-browser/customizations/01-disable-update-check >/dev/null 2>&1
	else
		echo -e "\e[91mUnable to clone MagicMirror. \e[0m" | tee -a $logfile
		exit;
	fi

	cd ~/MagicMirror  || exit
	if [ $(grep version package.json | awk -F: '{print $2}') == '"2.11.0",' -a $ARM == 'x86_64' ]; then
	    git fetch https://github.com/MagicMirrorOrg/MagicMirror.git develop >/dev/null 2>&1
		git branch develop FETCH_HEAD > /dev/null 2>&1
		git checkout develop > /dev/null 2>&1
	fi
	# if this is v 2.11 or higher
	newver=$(grep -i version package.json | awk -F\" '{ print $4 }')
	if verlte "2.11.0" $newver; then

	  # add fix to disable chromium update checks for a year from time started
	  # sudo touch /etc/chromium-browser/customizations/01-disable-update-check;echo CHROMIUM_FLAGS=\"\$\{CHROMIUM_FLAGS\} --check-for-update-interval=31536000\" | sudo tee /etc/chromium-browser/customizations/01-disable-update-check >/dev/null
	  if [ "$ARM" == "x86_64" -a "$OS" == 'buster' ]; then
	  	cd fonts
	  	   sed '/roboto-fontface/ c \    "roboto-fontface": "latest"' < package.json 	>new_package.json
	  	   if [ -s new_package.json ]; then
		  	cp new_package.json package.json
		  	rm new_package.json
		  	echo "package.json update for x86 fontface completed ok" >>$logfile
		  fi
	  	cd -
	  elif [ $mac == 'Darwin' ]; then
	  	   rm vendor/package-lock.json
	  	   echo "erase vendor package-lock.json to allow later nan/fsevents install on mac" >>$logfile
	  fi
	fi
    if [ ! -e css/custom.css ]; then
       touch css/custom.css
    fi
    if [ $newver == '2.13.0' ]; then
      # fix downlevel node-ical
      sed '/node-ical/ c \         "node-ical\"\:\"^0.12.1\",' < package.json >new_package.json
      rm package.json
      mv new_package.json package.json
	fi
	echo -e "\e[96mInstalling dependencies ...\e[0m" | tee -a $logfile
	# check for NPM v8 or higher, changed parms for prod only on npm install
	# get just the major version  number.. watch out for single or double digits
	# remove the leading V
	TEMPV=${NPM_CURRENT:1}
	# change . to space
	TEMPV=${TEMPV/\.*/\ } 2>/dev/null
	# split get first
	NPM_MAJOR=($TEMPV)
	# strip trailing space
	NPM_MAJOR=$(echo ${NPM_MAJOR[0]} | awk '{$1=$1};1')
	# compare
	if [ $NPM_MAJOR -ge 8 ]; then
		JustProd="--no-audit --no-fund --no-update-notifier" 
	fi
	rm package-lock.json 2>/dev/null
	npm_i_r=$(LC_ALL=C  npm  $forced_arch $Justprod --omit=dev install)
    npm_i_rc=$?
    # add the npm install messages to the logfile
  	echo $npm_i_r >> $logfile
    if [ $npm_i_rc -eq 0 ]; then
		echo -e "\e[92mDependencies installation Done!\e[0m" | tee -a $logfile
	else
        if [ $(echo $npm_i_r | grep "CERT_NOT_YET_VALID" | wc -l) -ne 0 ]; then
            echo "\e[91mSystem date/time is in the past, please correct \e[0m" | tee -a $logfile
        fi
		echo -e "\e[91mUnable to install dependencies! \e[0m" | tee -a $logfile
		exit;
	fi
	# fixup permissions on sandbox file if it exists
	if [ -f node_modules/electron/dist/chrome-sandbox ]; then
		 echo "fixing sandbox permissions" >>$logfile
		 sudo chown root node_modules/electron/dist/chrome-sandbox 2>/dev/null
		 sudo chmod 4755 node_modules/electron/dist/chrome-sandbox 2>/dev/null
	fi
	# assume electron installed ok
	el_installed=$true
	# if the folder isn't there, then we have problems
	if [ ! -d node_modules/electron ]; then
		el_installed=$false
	fi
	# if one of the older devices, fix the start script to execute in serveronly mode
	if [ "$ARM" == "armv6l" -o "$ARM" == "i686" -o $el_installed == $false ]; then
	  # fixup the start script
	  sed '/start/ c \    "start\"\:\"./run-start.sh $1\",' < package.json 	>new_package.json
	  if [ -s new_package.json ]; then
	  	cp new_package.json package.json
	  	rm new_package.json
	  	echo "package.json update for $ARM or Electron missing, completed ok" >>$logfile
	  else
	  	echo "package.json update for $ARM failed " >>$logfile
	  fi
          # on armv6l, new OS's have a bug in browser support
	  # install older chromium if not present
      v=$(uname -r); v=${v:0:1}
      if [ "$(which chromium-browser)." == '.' -a ${v:0:1} -ne 4 ]; then
		sudo apt-get install -y chromium-browser >>$logfile
	  fi 
	fi

	# Use sample config for start MagicMirror
	echo setting up initial config.js | tee -a $logfile
	cp config/config.js.sample config/config.js
fi
# Check if plymouth is installed (default with PIXEL desktop environment), then install custom splashscreen.
echo -e "\e[96mCheck plymouth installation ...\e[0m" | tee -a $logfile
if command_exists plymouth; then
	THEME_DIR="/usr/share/plymouth/themes"
	echo -e "\e[96mSplashscreen: Checking themes directory.\e[0m" | tee -a $logfile
	if [ -d $THEME_DIR ]; then
		echo -e "\e[96mSplashscreen: Create theme directory if not exists.\e[0m" | tee -a $logfile
		if [ ! -d $THEME_DIR/MagicMirror ]; then
			sudo mkdir $THEME_DIR/MagicMirror
		fi

		if sudo cp ~/MagicMirror/splashscreen/splash.png $THEME_DIR/MagicMirror/splash.png && sudo cp ~/MagicMirror/splashscreen/MagicMirror.plymouth $THEME_DIR/MagicMirror/MagicMirror.plymouth && sudo cp ~/MagicMirror/splashscreen/MagicMirror.script $THEME_DIR/MagicMirror/MagicMirror.script; then
			echo
			if [ "$(which plymouth-set-default-theme)." != "." ]; then
				if sudo plymouth-set-default-theme -R MagicMirror; then
					echo -e "\e[92mSplashscreen: Changed theme to MagicMirror successfully.\e[0m" | tee -a $logfile
				else
					echo -e "\e[91mSplashscreen: Couldn't change theme to MagicMirror!\e[0m" | tee -a $logfile
				fi
			fi
		else
			echo -e "\e[91mSplashscreen: Copying theme failed!\e[0m" | tee -a $logfile
		fi
	else
		echo -e "\e[91mSplashscreen: Themes folder doesn't exist!\e[0m" | tee -a $logfile
	fi
else
	echo -e "\e[93mplymouth is not installed.\e[0m" | tee -a $logfile
fi
# Disable Screensaver

read -p "Do you want to disable the screen saver? (y/N)?" choice
choice="${choice:-Y}"
if [[ $choice =~ ^[Yy]$ ]]; then
  # if this is a mac
	if [ $mac == 'Darwin' ]; then
	  # get the current setting
	  setting=$(defaults -currentHost read com.apple.screensaver idleTime)
		# if its on
		if [ "$setting" != 0 ] ; then
		  # turn it off
			echo disable screensaver via mac profile >> $logfile
			defaults -currentHost write com.apple.screensaver idleTime 0
		else
			echo mac profile screen saver already disabled >> $logfile
		fi
	else
	  # find out if some screen saver running

		# get just the running processes and args
		# just want the program name (1st token)
		# find the 1st with 'saver' in it (should only be one)
		# parse with path char, get the last field ( the actual pgm name)

	  screen_saver_running=$(ps -A -o args | awk '{print $1}' | grep -m1 [s]aver | awk -F\/ '{print $NF}');

		# if we found something
		if [ "$screen_saver_running." != "." ]; then
		  # some screensaver running
			case "$screen_saver_running" in
			 mate-screensaver) echo 'mate screen saver' >>$logfile
						gsettings set org.mate.screensaver lock-enabled false	 2>/dev/null
						gsettings set org.mate.screensaver idle-activation-enabled false	 2>/dev/null
						gsettings set org.mate.screensaver lock_delay 0	 2>/dev/null
				 echo " $screen_saver_running disabled" >> $logfile
				 DISPLAY=:0  mate-screensaver  >/dev/null 2>&1 &
				 ;;
			 gnome-screensaver) echo 'gnome screen saver' >>$logfile
			   gnome_screensaver-command -d >/dev/null 2>&1
				 echo " $screen_saver_running disabled" >> $logfile
			   ;;
			 xscreensaver) echo 'xscreensaver running' | tee -a $logfile
			   xsetting=$(grep -m1 'mode:' ~/.xscreensaver )
				 if [ $(echo $xsetting | awk '{print $2}') != 'off' ]; then
					 sed -i "s/$xsetting/mode: off/" "$HOME/.xscreensaver"
					 echo " xscreensaver set to off" >> $logfile
				 else
				   echo " xscreensaver already disabled" >> $logfile
				 fi
			   ;;
			 gsd-screensaver | gsd-screensaver-proxy)
					setting=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null)
					setting1=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null)
					if [ "$setting. $setting1." != '. .' ]; then
						if [ "$setting $setting1" != 'false uint32 0' ]; then
							echo "disable screensaver via gsettings was $setting and $setting1" >> $logfile
							gsettings set org.gnome.desktop.screensaver lock-enabled false
							gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
							gsettings set org.gnome.desktop.session idle-delay 0
						else
							echo "gsettings screen saver already disabled" >> $logfile
						fi
					fi
					;;
			 *) echo "some other screensaver $screen_saver_running" found | tee -a $logfile
			    echo "please configure it manually" | tee -a $logfile
			   ;;
		  esac
		fi
		if [ $(which gsettings | wc -l) == 1 ]; then
			setting=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null)
			setting1=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null)
			if [ "$setting. $setting1." != '. .' ]; then
				if [ "$setting $setting1" != 'false uint32 0' ]; then
					echo "disable screensaver via gsettings was $setting and $setting1">> $logfile
					gsettings set org.gnome.desktop.screensaver lock-enabled false
					gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
					gsettings set org.gnome.desktop.session idle-delay 0
				else
					echo "gsettings screen saver already disabled" >> $logfile
				fi
			fi
		fi
		if [ -e "/etc/lightdm/lightdm.conf" ]; then
		  # if screen saver NOT already disabled?
			if [ $(grep 'xserver-command=X -s 0 -dpms' /etc/lightdm/lightdm.conf | wc -l) == 0 ]; then
			  echo "disable screensaver via lightdm.conf" >> $logfile
			  sudo sed -i '/^\[Seat:/a xserver-command=X -s 0 -dpms' /etc/lightdm/lightdm.conf
			else
				if [ $(grep 'xserver-command=X -s 0' /etc/lightdm/lightdm.conf | wc -l) == 0 ]; then
					echo disable screensaver via lightdm.conf >> $logfile
					sudo sed -i '/^\[Seat:/a xserver-command=X -s 0' /etc/lightdm/lightdm.conf
				else
					echo "screensaver via lightdm already disabled" >> $logfile
				fi
			fi
		fi
		if [ -d "/etc/xdg/lxsession/LXDE-pi" ]; then
		  currently_set_old=$(grep -m1 '\-dpms' /etc/xdg/lxsession/LXDE-pi/autostart)
		  currently_set=$(grep -m1 '\-dpms' /etc/xdg/lxsession/LXDE-pi/autostart)
		  		  if [ "$currently_set_old." != "." ]; then
		    echo lxsession screen saver already disabled but need to updated >> $logfile
		    sudo sed -i "/^@xset -dpms/d" /etc/xdg/lxsession/LXDE-pi/autostart
		    export DISPLAY=:0; xset s noblank;xset s off
		  else
			if [ "$currently_set." == "." ]; then
				echo "disable screensaver via lxsession" >> $logfile
				# turn it off for the future
				sudo su -c "echo -e '@xset s noblank\n@xset s off\n@xset -dpms' >> /etc/xdg/lxsession/LXDE-pi/autostart"
				# turn it off now
				export DISPLAY=:0; xset s noblank;xset s off;xset -dpms
			else
			  echo "lxsession screen saver already disabled" >> $logfile
			fi
		  fi
		fi
#		if [ -e "$HOME/.config/wayfire.ini" ]; then
#		  current_set=$(grep -m1 "dpms_timeout" $HOME/.config/wayfire.ini | awk '{print $3}')
#		  if [ "$current_set" != 0 ]; then
#		    echo disable screensaver via wayfire.ini >> $logfile
#		    sed -i -r "s/^(dpms_timeout.*)$/dpms_timeout = 0/" $HOME/.config/wayfire.ini
#		  else
#		    echo wayland screen saver already disabled >> $logfile
#		  fi
#		fi
		if [ -e "$HOME/.config/wayfire.ini" ]; then
			#  current_set=$(grep -m1 "dpms_timeout" $HOME/.config/wayfire.ini | awk '{print $3}')
			#  if [ "$current_set" != 0 ]; then
			#    echo disable screensaver via wayfire.ini >> $logfile
			#    sed -i -r "s/^(dpms_timeout.*)$/dpms_timeout = 0/" $HOME/.config/wayfire.ini
			#  else
			#    echo wayland screen saver already disabled >> $logfile
			#  fi
			echo "Found: wayfire.ini" >> $logfile
			INI_PATH=$HOME/.config
			WAYFIRE_CONFIG=$INI_PATH/wayfire.ini
			IDLE='\[idle\]'
			DPMS=dpms_timeout
			IDLE_LINE=0
			DPMS_LINE=0
			DPMS_SETTING=0  # 0 = off, 1 = on
			change=0
			# get the line count
			lc=$(wc -l <$WAYFIRE_CONFIG)
			# find the idle line and its line number
			IDLE_STRING=$(grep -n $IDLE $WAYFIRE_CONFIG)
			# find the dpms line and its line number
			DPMS_STRING=$(grep -n $DPMS $WAYFIRE_CONFIG)
			# if we found the idle line
			if [ "$IDLE_STRING." != "." ]; then
				#  extract line number
				IDLE_LINE=$(echo $IDLE_STRING | awk -F: '{print $1}')
			fi
			# if we found the dpms line
			if [ "$DPMS_STRING." != "." ]; then
				# extract line number
				DPMS_LINE=$(echo $DPMS_STRING | awk -F: '{print $1}')
				# extract its value  (after = sign)
				DPMS_VALUE=$(echo $DPMS_STRING | awk -F= '{print $2}')
				# set the value to write out
				DPMS_OUT=$DPMS_SETTING
			fi

			if [ $IDLE_LINE -ne 0 -a $DPMS_LINE -ne 0 -a $DPMS_LINE -gt $IDLE_LINE ]; then
				# both found
				# if we found the DPMS_VALUE != 0
				if [ $DPMS_VALUE -ne 0 ]; then
					sed -i "s/$DPMS=.*/$DPMS=$DPMS_OUT/g" $WAYFIRE_CONFIG
					((change++))
				else
					echo "wayfire screen saver already disabled" | tee -a $logfile
				fi
			# if both NOT found
			elif [ $IDLE_LINE -eq 0 -a $DPMS_LINE -eq 0 ]; then
				# add the two lines
				echo $IDLE | tr -d '\\' >> $WAYFIRE_CONFIG
				echo $DPMS=$DPMS_SETTING >> $WAYFIRE_CONFIG
				((change++))
			# if we found the idle line, (but not dpms)
			elif [ $IDLE_LINE -ne 0 ]; then
				# IDLE was found
				if [ $DPMS_LINE -eq 0 ]; then
					# DPMS  not found
					# insert DPMS after idle
					sed -i /$IDLE/a\ $DPMS=$DPMS_SETTING $WAYFIRE_CONFIG
					((change++))
				fi
			else
				# DPMS IS found , idle not found?  weird
				# insert idle before DPMS?? is this a problem?
				# lets add both to the end, removing the old one first
				# remove the dpms line, wherever it is
				grep -v $DPMS $WAYFIRE_CONFIG>$INI_PATH/wayfire.ini.tmp
				# add the idle  line
				echo $IDLE | tr -d '\\' >>$INI_PATH/wayfire.ini.tmp
				#add the dpms line
				echo $DPMS=$DPMS_SETTING >>$INI_PATH/wayfire.ini.tmp
				# copy the current wayfire.ini to save place
				cp $WAYFIRE_CONFIG $WAYFIRE_CONFIG.old
				# coppy the work ini to the correct file
				cp $INI_PATH/wayfire.ini.tmp $WAYFIRE_CONFIG
				# remove the work file
				rm  $INI_PATH/wayfire.ini.tmp
				((change++))
			fi
			if [ $change -ne 0 ]; then 
				echo disable screensaver via $WAYFIRE_CONFIG >> $logfile
			fi
		fi		
	fi
fi

# Use pm2 control like a service MagicMirror
read -p "Do you want use pm2 for auto starting of your MagicMirror (y/N)?" choice
choice="${choice:-N}"
if [[ $choice =~ ^[Yy]$ ]]; then
      echo install and setup pm2 | tee -a $logfile
 			# assume pm2 will be found on the path
			pm2cmd=pm2
			up=""
			if [ $mac == 'Darwin' ]; then
				 up="--unsafe-perm"
				 launchctl=launchctl
				 launchctl_path=$(which $launchctl)
				 `export PATH=$PATH:${launchctl_path%/$launchctl}`
			fi
			# check to see if already installed
			pm2_installed=$(which $pm2cmd)
			if [  "$pm2_installed." != "." ]; then
			    # does it work?
					pm2_fails=$(pm2 list | grep -i -m 1 "uptime" | wc -l )
					if [ $pm2_fails != 1 ]; then
					   # uninstall it
						 echo pm2 installed, but does not work, uninstalling >> $logfile
					   sudo npm uninstall $up -g pm2 >> $logfile
						 # force reinstall
				     pm2_installed=
					fi
			fi
			# if not installed
			if [  "$pm2_installed." == "." ]; then
				# install it.
				echo pm2 not installed, installing >>$logfile
				result=$(sudo npm  $up $JustProd install -g pm2 2>&1)
				echo pm2 install result $result >>$logfile
				pm2cmd=pm2
				# if this is a mac
				if [ $mac == 'Darwin1' ]; then
					echo "this is a mac, fixup for path" >>$logfile
					# get the location of pm2 install
					# parse the npm install output to get the command
					pm2cmd=`echo $result | awk -F -  '{print $1}' | tr -d '[:space:]'`
					c='/pm2'
					# get the path only
					echo ${pm2cmd%$c} >installers/pm2path
				fi
			fi
			echo "get the pm2 platform specific startup command" >>$logfile
			# get the platform specific pm2 startup command
			v=$($pm2cmd startup | tail -n 1)
			if [ $mac != 'Darwin' ]; then
				# check to see if we can get the OS package name (Ubuntu)
				if [ $(which lsb_release| wc -l) -gt 0 ]; then
					# fix command
					# if ubuntu 18.04, pm2 startup gets something wrong
					if [ $(lsb_release  -r | grep -m1 18.04 | wc -l) -gt 0 ]; then
						 v=$(echo $v | sed 's/\/bin/\/bin:\/bin/')
					fi
				fi
			fi
			echo "startup command = $v" >>$logfile
			# execute the command returned
         bash -c "$v 2>&1" >>$logfile
         #$v 2>&1 >>$logfile 2>&1
			echo "pm2 startup command done" >>$logfile
			# is this is mac
			# need to fix pm2 startup, only on catalina
			if [ $mac == 'Darwin1' ]; then
                if [ $(sw_vers -productVersion | head -c 6) == '10.15.' ]; then
					# only do if the faulty tag is present (pm2 may fix this, before the script is fixed)
					if [ $(grep -m 1 UserName /Users/$USER/Library/LaunchAgents/pm2.$USER.plist | wc -l) -eq 1 ]; then
						# copy the pm2 startup file config
						cp  /Users/$USER/Library/LaunchAgents/pm2.$USER.plist .
						# edit out the UserName key/value strings
						sed -e '/UserName/{N;d;}' pm2.$USER.plist > pm2.$USER.plist.new
						# copy the file back
						sudo cp pm2.$USER.plist.new /Users/$USER/Library/LaunchAgents/pm2.$USER.plist
					fi
				fi
			fi
		# if the user is no pi, we have to fixup the pm2 json file
		echo "configure the pm2 config file for MagicMirror" >>$logfile
		# if the files we need aren't here, get them
		if [ ! -e installers/pm2_MagicMirror.json ]; then
			curl -sL https://raw.githubusercontent.com/sdetweil/MagicMirror_scripts/master/pm2_MagicMirror.json >installers/pm2_MagicMirror.json
			# curl -sl https://raw.githubusercontent.com/sdetweil/MagicMirror_scripts/master/mm.sh >installers/mm2.sh
			#chmod +x installers/mm2.sh
		fi
		if [ "$USER"  != "pi" ]; then
			# no need to change mm.sh now
			echo the user is not pi >>$logfile
			# go to the installers folder
			cd installers
			if [ 0 -gt 1 ]; then
				# edit the startup script for the right user
				echo change mm2.sh >>$logfile
				 if [ ! -e mm_temp.sh ]; then
				   echo save copy of mm2.sh >> $logfile
				   cp mm2.sh mm_temp.sh
				 fi
				 if [ $(grep pi mm_temp.sh | wc -l) -gt 0 ]; then
				  echo change hard coded pi username  >> $logfile
					sed 's/pi/'$USER'/g' mm_temp.sh >mm2.sh
				 else
				  echo change relative home path to hard coded path >> $logfile
				  hf=$(echo $HOME |sed 's/\//\\\//g')
				  sed 's/\~/'$hf'/g' mm_temp.sh >mm2.sh
				 fi
			fi
			# edit the pm2 config file for the right user
			echo change $PM2_FILE >>$logfile
			sed 's/pi/'$USER'/g' $PM2_FILE > pm2_MagicMirror_new.json
			# make sure to use the updated file
			PM2_FILE=pm2_MagicMirror_new.json
			# if this is a mac, home foilder is in a diffent place, fix that
			if [ $mac == 'Darwin' ]; then
				 # copy the path file to the system paths list
				 #sudo cp ./pm2path /etc/paths.d
				 # change the name of the home path for mac
				 sed 's/home/Users/g' $PM2_FILE > pm2_MagicMirror_new1.json
				 # make sure to use the updated file
				 PM2_FILE=pm2_MagicMirror_new1.json
			fi
			echo now using this config file $PM2_FILE >>$logfile
			# go back one cd level
			cd - >/dev/null
		fi
		echo start MagicMirror via pm2 now >>$logfile
		# tell pm2 to start the app defined in the config file
		$pm2cmd start $HOME/MagicMirror/installers/$PM2_FILE
		# tell pm2 to save that configuration, for start at boot
		echo save MagicMirror pm2 config now  >>$logfile
		$pm2cmd save
		echo stop MagicMirror via pm2 now >>$logfile
		#$pm2cmd stop MagicMirror
		pm2setup=$true
fi

echo " "
if [ $pm2setup -eq $true ]; then
	rmessage="pm2 start MagicMirror"
else
  rmessage="DISPLAY=:0 npm start"
fi
echo -e "\e[92mWe're ready! Run \e[1m\e[97m$rmessage\e[0m\e[92m from the ~/MagicMirror directory to start your MagicMirror.\e[0m" | tee -a $logfile

echo " "
echo " "

date +"install completed - %a %b %e %H:%M:%S %Z %Y" >>$logfile