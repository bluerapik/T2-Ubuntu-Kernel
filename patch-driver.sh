#!/bin/bash

set -eu -o pipefail

T2_PATCH_PATH="${BUILD_PATH}/patches"

## Patches
APPLE_SMC_DRIVER_GIT_URL="https://github.com/t2linux/linux-t2-patches.git"
APPLE_SMC_DRIVER_BRANCH_NAME="5.15"
# APPLE_SMC_DRIVER_COMMIT_HASH="404ec2beb452322b4a4380e1de2167cab4221cf8"
APPLE_SMC_DRIVER_COMMIT_HASH="HEAD"

# echo >&2 "[INFO] Clean up Patch folder."
# rm -rf "${T2_PATCH_PATH}"
# mkdir -p "${T2_PATCH_PATH}"

## AppleSMC and BT aunali fixes
echo "[INFO] Clone Apple SMC Driver"
cd "${T2_PATCH_PATH}" || exit
git clone --single-branch --branch ${APPLE_SMC_DRIVER_BRANCH_NAME} ${APPLE_SMC_DRIVER_GIT_URL} "linux-mbp-arch"

cd "linux-mbp-arch" || exit

echo "[INFO] Checkout Commit hash: ${APPLE_SMC_DRIVER_COMMIT_HASH}"
git checkout ${APPLE_SMC_DRIVER_COMMIT_HASH}

# Already cloned https://github.com/kekrby/apple-bce.git
rm -f 1001-Add-apple-bce-driver.patch
# Replaced with 1001-Put-apple-bce-and-apple-ibridge-in-drivers-staging.patch in patches folder
rm -f 1002-Put-apple-bce-in-drivers-staging.patch
# Replaced with 1002-add-modalias-to-apple-bce.patch folder
rm -f 1003-add-modalias-to-apple-bce.patch

# Patches changed for kernel 5.15.70 based on linux-t2-patches v6.1 HEAD
# rm -f 1001-Add-apple-bce-driver.patch
# rm -f 1002-Put-apple-bce-in-drivers-staging.patch
# rm -f 1006-Fix-for-touchbar.patch
# rm -f 1008-HID-apple-touchbar-Add-driver-for-the-Touch-Bar-on-M.patch
# rm -f 2001-fix-acpica-for-zero-arguments-acpi-calls.patch

# Patches changed for kernel v5.15.162 based on linux-t2-patches v5.15 HEAD
# rm -f 1001-Add-apple-bce-driver.patch
# rm -f 1006-Fix-for-touchbar.patch
# rm -f 1009-HID-quirks-Use-touchbar-quirks-when-touchbar-driver-.patch
# rm -f 4010-HID-apple-Add-ability-to-use-numbers-as-function-key.patch

# Already patched in kernel v5.15.162
# rm -f 8022-brcmfmac-cfg80211-Pass-the-PMK-in-binary-instead-of-.patch

while IFS= read -r file; do
  echo "[INFO] Add ${file##*/}"
  cp -rf "${file}" "${BUILD_PATH}"/patches/"${file##*/}"
done < <(find "${T2_PATCH_PATH}/linux-mbp-arch" -type f -name "*.patch" | grep -vE '000[0-9]')
