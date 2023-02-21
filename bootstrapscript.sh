#!/bin/bash
# 
# This script is to bootstrap a newly setup server for Ansible
#
# Author: Jasmin Schär
# Change Log:
# -> 2023-02-22: Creation


PACKAGE_INSTALL() {
	package_name=$1
	repo_list=$2
	repo_err=0

	#Check if chosen repos are configured and enabled
	for repo in $repo_list
		if $(dnf repolist $repo | grep enabled); then
			dnf in -y $package
			break
		else
			((repo_err=repo_err+1))
		fi
	end

	#Error if none of the repos are configured/enabled 
	if [[ $(echo $repo_list | wc -w) < $repo_err || $(echo $repo_list | wc -w) = $repo_err ]]; then
		echo "ERROR: No matching repository found to install $package"
		exit 1
	fi
}

CREATE_USER() {
	accountName=$1
	linkAuthPubKeys=$2
	sshPath="/home/$accountName/.ssh"

	if $(grep -i $accountName /etc/passwd); then
	echo "> User with name $accountName already exists. Skipping useradd..."
	else
		echo "> Creating user with name $accountName..."
		useradd -s /bin/bash -c "Ansible Management" -m -r $accountName
	fi

	#create folder structure for ssh
	echo "> Setting up SSH authentication for user $accountName..."

	#Copy public key into authorized keys
	{ # try
		mkdir -p $sshPath
		chmod 700 $sshPath
		chown $accountName:$accountName $sshPath
		wget $linkAuthPubKeys -q -O - >> $sshPath/authorized_keys
		chmod 600 $sshPath/authorized_keys
		chown $accountName:$accountName $sshPath/authorized_keys
	} || { # catch
		echo "ERROR: Failed setting up SSH authentication for user $accountName. Please do manually."
	}

	#add to suoders
	echo "> Adding user $accountName to sudoers..."
	echo "$accountName ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/admin
}

# ---> MAIN <---

# Root Check
if [[ "$EUID" != 0 ]]; then 
	echo 'ERROR: You are not root! Please run as root (sudo)'
	exit 1
fi

# Network Check
	if [[ $(wget -q --spider --timeout=3 https://yum.oracle.com/) != 0 ]]; then
		echo "ERROR: No network connection, please make sure you are online!"
		exit 1
	fi

# --------------------

echo ''
echo '---- INSTALLING PACKAGES ----'
echo ''

echo "> installing python3.9..."
pythonPackageName='python3.9'
pythonRepoList='ol9_baseos_latest ol9_appstream'

PACKAGE_INSTALL $pythonPackageName $pythonRepoList
echo "> done installing python3.9"

# --------------------

echo ''
echo '---- CREATING ANSIBLE USER ----'
echo ''

echo "> creating user caesar..."
# Not using an obvious admin name
ansibleAccountName='caesar'
ansibleLinkAuthPubKeys="https://link.to.git"

CREATE_USER $ansibleAccountName $ansibleLinkAuthPubKeys
echo "> done creating user caesar"

# --------------------