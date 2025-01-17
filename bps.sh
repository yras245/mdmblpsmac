#!/bin/bash

# Global constants
readonly DEFAULT_SYSTEM_VOLUME="Macintosh HD"
readonly DEFAULT_DATA_VOLUME="Macintosh HD - Data"

# Text formating
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Checks if a volume with the given name exists
checkVolumeExistence() {
	local volumeLabel="$*"
	diskutil info "$volumeLabel" >/dev/null 2>&1
}

# Returns the name of a volume with the given type
getVolumeName() {
	local volumeType="$1"

	# Getting the APFS Container Disk Identifier
	apfsContainer=$(diskutil list internal physical | grep 'Container' | awk -F'Container ' '{print $2}' | awk '{print $1}')
	# Getting the Volume Information
	volumeInfo=$(diskutil ap list "$apfsContainer" | grep -A 5 "($volumeType)")
	# Extracting the Volume Name from the Volume Information
	volumeNameLine=$(echo "$volumeInfo" | grep 'Name:')
	# Removing unnecessary characters to get the clean Volume Name
	volumeName=$(echo "$volumeNameLine" | cut -d':' -f2 | cut -d'(' -f1 | xargs)

	echo "$volumeName"
}

# Defines the path to a volume with the given default name and volume type
defineVolumePath() {
	local defaultVolume=$1
	local volumeType=$2

	if checkVolumeExistence "$defaultVolume"; then
		echo "/Volumes/$defaultVolume"
	else
		local volumeName
		volumeName="$(getVolumeName "$volumeType")"
		echo "/Volumes/$volumeName"
	fi
}

# Mounts a volume at the given path
mountVolume() {
	local volumePath=$1

	if [ ! -d "$volumePath" ]; then
		diskutil mount "$volumePath"
	fi
}

echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo -e "${YELLOW}*         Обход MDM на Mac          *${NC}"
echo -e "${RED}*             UO5OQ.COM                 *${NC}"
echo -e "${RED}*              wins94                    *${NC}"
echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo -e "${RED}*Перед работой с скриптом убедитесь что ваш диск переименован в Macintosh HD а раздел с данными в Macintosh HD - Data*${NC}"
echo ""
echo ""
PS3='Please enter your choice: '
options=("Обход" "Перезагрузить ПК" "Выход")

select opt in "${options[@]}"; do
	case $opt in
	"Обход")
		echo -e "\n\t${GREEN}Обход${NC}\n"

		# Mount Volumes
		echo -e "${BLUE}Монтирование разделов...${NC}"
		# Mount System Volume
		systemVolumePath=$(defineVolumePath "$DEFAULT_SYSTEM_VOLUME" "System")
		mountVolume "$systemVolumePath"

		# Mount Data Volume
		dataVolumePath=$(defineVolumePath "$DEFAULT_DATA_VOLUME" "Data")
		mountVolume "$dataVolumePath"

		echo -e "${GREEN}Монтирование разделов завершено${NC}\n"

		# Create User
		echo -e "${BLUE}Проверка на наличие учетных записей пользователей${NC}"
		dscl_path="$dataVolumePath/private/var/db/dslocal/nodes/Default"
		localUserDirPath="/Local/Default/Users"
		defaultUID="501"
		if ! dscl -f "$dscl_path" localhost -list "$localUserDirPath" UniqueID | grep -q "\<$defaultUID\>"; then
			echo -e "${CYAN}Создайте нового пользователя${NC}"
			echo -e "${CYAN}Нажмите enter чтобы продолжить${NC}"
			echo -e "${CYAN}Введите полное имя (если оставить пустым то именем будет: Apple)${NC}"
			read -rp "Full name: " fullName
			fullName="${fullName:=Apple}"

			echo -e "${CYAN}Введите имя пользователя${NC} ${RED}ПИСАТЬ БЕЗ ПРОБЕЛОВ И НА АНГЛИЙСКОМ${NC} ${GREEN}Стандартное: Apple${NC}"
			read -rp "Username: " username
			username="${username:=Apple}"

			echo -e "${CYAN}Придумайте пароль (стандартный: 1234)${NC}"
			read -rsp "Password: " userPassword
			userPassword="${userPassword:=1234}"

			echo -e "\n${BLUE}Добавляем учетную запись${NC}"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UserShell "/bin/zsh"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" RealName "$fullName"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UniqueID "$defaultUID"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" PrimaryGroupID "20"
			mkdir "$dataVolumePath/Users/$username"
			dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" NFSHomeDirectory "/Users/$username"
			dscl -f "$dscl_path" localhost -passwd "$localUserDirPath/$username" "$userPassword"
			dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"
			echo -e "${GREEN}Учетная запись добавлена${NC}\n"
		else
			echo -e "${BLUE}Учетная запись уже была добавлена${NC}\n"
		fi

		# Block MDM hosts
		echo -e "${BLUE}Обход 30%...${NC}"
		hostsPath="$systemVolumePath/etc/hosts"
		blockedDomains=("deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com")
		for domain in "${blockedDomains[@]}"; do
			echo "0.0.0.0 $domain" >>"$hostsPath"
		done
		echo -e "${GREEN}Обход 40%....${NC}\n"

		# Remove config profiles
		echo -e "${BLUE}Обход 70%.......${NC}"
		configProfilesSettingsPath="$systemVolumePath/var/db/ConfigurationProfiles/Settings"
		touch "$dataVolumePath/private/var/db/.AppleSetupDone"
		rm -rf "$configProfilesSettingsPath/.cloudConfigHasActivationRecord"
		rm -rf "$configProfilesSettingsPath/.cloudConfigRecordFound"
		touch "$configProfilesSettingsPath/.cloudConfigProfileInstalled"
		touch "$configProfilesSettingsPath/.cloudConfigRecordNotFound"
		echo -e "${GREEN}Обход 100%..........${NC}\n"

		echo -e "${GREEN}------ Обход произведен успешно! ------${NC}"
		echo -e "${CYAN}------ Закройте терминал перезагрузите мак и пользуйтесь ------${NC}"
		break
		;;

	"Check MDM Enrollment")
		if [ ! -f /usr/bin/profiles ]; then
			echo -e "\n\t${RED}Don't use this option in recovery${NC}\n"
			continue
		fi

		if ! sudo profiles show -type enrollment >/dev/null 2>&1; then
			echo -e "\n\t${GREEN}Success${NC}\n"
		else
			echo -e "\n\t${RED}Failure${NC}\n"
		fi
		;;

	"Reboot")
		echo -e "\n\t${BLUE}Rebooting...${NC}\n"
		reboot
		;;

	"Exit")
		echo -e "\n\t${BLUE}Exiting...${NC}\n"
		exit
		;;

	*)
		echo "Invalid option $REPLY"
		;;
	esac
done
