#!/bin/bash

set -eu -o pipefail

## Folders path
REPO_PATH=$(pwd)
WORKSPACE_PATH="${REPO_PATH}/workspace"
BUILD_PATH="${WORKSPACE_PATH}/build"
KERNEL_PATH="${BUILD_PATH}/linux-kernel"
LOG_PATH="${WORKSPACE_PATH}/log"
RELEASE_PATH="${WORKSPACE_PATH}/release"
DATETIME=$(date "+%Y.%m.%d-%H.%M.%S")

## Log all stdout and stderr to file
rm -rf "${LOG_PATH}"
mkdir -p "${LOG_PATH}"
exec > >(tee -i "${LOG_PATH}"/build-${DATETIME}.log) 2>&1

# Check Build Environment
cgroup=$(cat /proc/1/cgroup)
if ! echo $cgroup | grep -qe "/docker"; then
  echo "-----------------------------------------"
  echo "Build in main O.S."
  echo -e "-----------------------------------------"
  
  ## Dependencies
  echo "[INFO] Install Dependencies."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y build-essential fakeroot libncurses-dev bison flex libssl-dev libelf-dev \
    openssl dkms libudev-dev libpci-dev libiberty-dev autoconf wget xz-utils git \
    libcap-dev bc rsync cpio dh-modaliases debhelper kernel-wedge curl gawk dwarves zstd
else
  echo -e "-----------------------------------------"
  echo "Build in Docker."
  echo "-----------------------------------------"
fi

## Kernel version
KERNEL_VERSION="5.15.78"
PKGREL=1
CODENAME=$(lsb_release -c | cut -d ":" -f 2 | xargs)

## Reposity URL
KERNEL_REPOSITORY="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
APPLE_BCE_REPOSITORY="https://github.com/kekrby/apple-bce.git"
APPLE_IBRIDGE_REPOSITORY="https://github.com/Redecorating/apple-ib-drv.git"

## Debug commands
echo -e "\n-----------------------------------------"
echo "Kernel Version: ${KERNEL_VERSION}"
echo "Git Version: $(git --version | cut -d " " -f 3)"
echo "Workspace Path: ${WORKSPACE_PATH}"
echo "Build Path: ${BUILD_PATH}"
echo "Release Path: ${RELEASE_PATH}"
echo "Log Path: ${LOG_PATH}"
echo "Kernel Path: ${KERNEL_PATH}"
echo "Kernel Repository: ${KERNEL_REPOSITORY}"
echo "Apple BCE Repository: ${APPLE_BCE_REPOSITORY}"
echo "Apple IBridge Repository: ${APPLE_IBRIDGE_REPOSITORY}"
echo "Current Path: ${REPO_PATH}"
echo "CPU Threads: $(nproc --all)"
echo "Model Name: $(sed -n 's/^model name[[:space:]]:[[:space:]]*//p' /proc/cpuinfo | uniq)"
echo "-----------------------------------------"

get_next_version () {
  echo $PKGREL
}

## Clean up
echo -e "\n-----------------------------------------"
echo " Clean up Working folder and Copy files."
echo "-----------------------------------------"

echo "[INFO] Clean Working folder."
rm -rf "${BUILD_PATH}"
mkdir -p "${BUILD_PATH}"

echo "[INFO] Copy Patches and Template Folder."
cp -rf "${REPO_PATH}"/{patches,templates} "${BUILD_PATH}"

## Get Kernel and Drivers
echo -e "\n-----------------------------------------"
echo " Get Kernel and Drivers"
echo "-----------------------------------------"

echo "[INFO] Clone Kernel"
git clone --progress --depth 1 --single-branch --branch "v${KERNEL_VERSION}" "${KERNEL_REPOSITORY}" "${KERNEL_PATH}" 2>&1 | sed 's:.*\r::'

# echo "[INFO] Clone Apple BCE"
git clone --progress --depth 1 "${APPLE_BCE_REPOSITORY}" "${KERNEL_PATH}/drivers/staging/apple-bce" 2>&1 | sed 's:.*\r::'

# echo "[INFO] Clone Apple iBridge"
git clone --progress --depth 1 "${APPLE_IBRIDGE_REPOSITORY}" "${KERNEL_PATH}/drivers/staging/apple-ibridge" 2>&1 | sed 's:.*\r::' 

## Create patch file with custom drivers
echo -e "\n-----------------------------------------"
echo " Create patch file with custom drivers"
echo "-----------------------------------------"

echo >&2 "[INFO] Creating patch files. "
cd "${KERNEL_PATH}" || exit
KERNEL_VERSION="${KERNEL_VERSION}" BUILD_PATH="${BUILD_PATH}" "${REPO_PATH}/patch-driver.sh"

## Apply patches
echo -e "\n-----------------------------------------"
echo " Apply patches."
echo "-----------------------------------------"

cd "${KERNEL_PATH}" || exit

[ ! -d "${BUILD_PATH}/patches" ] && {
  echo '[ERROR] Patches directory not found!'
  exit 1
}

while IFS= read -r file; do
  echo "[INFO] Patch ${file}"
  patch -p1 <"$file"
done < <(find "${BUILD_PATH}/patches" -maxdepth 1 -type f -name "*.patch" | sort)

## Build SRC
echo -e "\n-----------------------------------------"
echo " Build SRC"
echo "-----------------------------------------"

echo >&2 "[INFO] Compile Kernel"
cd "${KERNEL_PATH}"
make clean

## Make config friendly with vanilla kernel
sed -i 's/CONFIG_VERSION_SIGNATURE=.*/CONFIG_VERSION_SIGNATURE=""/g' "${BUILD_PATH}/templates/default-config"
sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' "${BUILD_PATH}/templates/default-config"
sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' "${BUILD_PATH}/templates/default-config"
sed -i 's/CONFIG_DEBUG_INFO=y/# CONFIG_DEBUG_INFO is not set/g' "${BUILD_PATH}/templates/default-config"

## I want silent boot
sed -i 's/CONFIG_CONSOLE_LOGLEVEL_DEFAULT=.*/CONFIG_CONSOLE_LOGLEVEL_DEFAULT=4/g' "${BUILD_PATH}/templates/default-config"
sed -i 's/CONFIG_CONSOLE_LOGLEVEL_QUIET=.*/CONFIG_CONSOLE_LOGLEVEL_QUIET=1/g' "${BUILD_PATH}/templates/default-config"
sed -i 's/CONFIG_MESSAGE_LOGLEVEL_DEFAULT=.*/CONFIG_MESSAGE_LOGLEVEL_DEFAULT=4/g' "${BUILD_PATH}/templates/default-config"

## Copy the modified config
cp "${BUILD_PATH}/templates/default-config" "${KERNEL_PATH}/.config"
make olddefconfig

## Get rid of the dirty tag
echo "" >"${KERNEL_PATH}"/.scmversion

## Build Deb packages
echo >&2 "[INFO] Build Deb packages."
make -j "$(getconf _NPROCESSORS_ONLN)" deb-pkg LOCALVERSION=-t2-"${CODENAME}" KDEB_PKGVERSION="$(make kernelversion)-$(get_next_version)"

## Copy .deb and calculating SHA256
echo -e "\n-----------------------------------------"
echo " Copy .deb and calculating SHA256"
echo "-----------------------------------------"

mkdir -p "${RELEASE_PATH}"

echo >&2 "[INFO] Copy .config."
mv -fv "${KERNEL_PATH}/.config" "${RELEASE_PATH}/kernel_config_${KERNEL_VERSION}-t2-${CODENAME}"

echo >&2 "[INFO] Copy .deb to release folder."
mv -fv "${BUILD_PATH}/linux-libc-dev_${KERNEL_VERSION}-${PKGREL}_amd64.deb" "${RELEASE_PATH}/linux-libc-dev_${KERNEL_VERSION}-${PKGREL}-${CODENAME}_amd64.deb"
mv -fv "${BUILD_PATH}"/*.deb "${RELEASE_PATH}"

echo >&2 "[INFO] Calculate SHA256."
cd "${RELEASE_PATH}"
sha256sum *.deb >"sha256sum_${KERNEL_VERSION}-t2-${CODENAME}"

echo -e "\n-----------------------------------------"
echo " Copy log and clean Working folder"
echo "-----------------------------------------"

echo "[INFO] Copy log. and Clean"
mv -fv "${LOG_PATH}/build-${DATETIME}.log" "${RELEASE_PATH}/build-${KERNEL_VERSION}-t2-${CODENAME}-${DATETIME}.log"
rm -rf "${LOG_PATH}"

echo "[INFO] Clean Workspace and Log folder."
rm -rf "${BUILD_PATH}"
rm -rf "${LOG_PATH}"