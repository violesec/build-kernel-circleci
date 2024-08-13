#!/usr/bin/env bash
# Copyright (C) 2022-2023 Neebe3289 <neebexd@gmail.com>
# Copyright (C) 2023-2024 MrErenK <akbaseren4751@gmail.com>
# Copyright (C) 2024-2025 Viole403 <masaliefm@gmail.com>
# SPDX-License-Identifier: Apache-2.0

# A bash script to build Android Kernel
# Inspired from Panchajanya1999's script

# Load variables from config.env
export $(grep -v '^#' config.env | xargs)

# Date and time for log and zip name
DATE=$(TZ=Asia/Jakarta date +"%d-%m-%Y")
DATE_ZIP=$(TZ=Asia/Jakarta date +"d%m%y")
DATE_LOG=$(TZ=Asia/Jakarta date +"d%m%y-%H%M")

# Path
MAIN_PATH="$(readlink -f -- $(pwd))"
MAIN_CLANG_PATH="${MAIN_PATH}/clang"
ANYKERNEL_PATH="${MAIN_PATH}/anykernel"
CROSS_COMPILE_FLAG_TRIPLE="aarch64-linux-gnu-"
CROSS_COMPILE_FLAG_64="aarch64-linux-gnu-"
CROSS_COMPILE_FLAG_32="arm-linux-gnueabi-"

# Clone or update toolchain
function clone_clang() {
  local CLANG_TYPE=$1
  local CLANG_PATH="${MAIN_CLANG_PATH}-${CLANG_TYPE}"
  local GIT_REPO=""
  local GIT_BRANCH=""
  local GCC_REPO_32=""
  local GCC_REPO_64=""

  case $CLANG_TYPE in
    "aosp" | "gcc" ) # todo: add gcc repo for aosp
      GIT_REPO="https://gitlab.com/Neebe3289/android_prebuilts_clang_host_linux-x86.git"
      GIT_BRANCH="clang-r498229"
      GCC_REPO_32=""
      GCC_REPO_64=""
      ;;
    "azure")
      GIT_REPO="https://gitlab.com/Panchajanya1999/azure-clang"
      ;;
    "neutron")
      GIT_REPO="https://github.com/Neutron-Toolchains/clang"
      ;;
    "proton")
      GIT_REPO="https://github.com/kdrag0n/proton-clang"
      ;;
    "lilium")
      GIT_REPO="https://github.com/liliumproject/clang"
      ;;
    "yuki") # todo: add gcc repo for yuki
      GIT_REPO="https://gitlab.com/TheXPerienceProject/yuki_clang.git"
      GCC_REPO_32="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
      GCC_REPO_64="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
      ;;
    "zyc")
      GIT_REPO="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null)"
      ;;
    *)
      echo "[!] Incorrect clang name. Check config.env for clang names."
      exit 1
      ;;
  esac

  if [ ! -f "${CLANG_PATH}/bin/clang" ]; then
    echo "[!] Clang is set to ${CLANG_TYPE}, cloning it..."
    git clone "${GIT_REPO}" "${CLANG_PATH}" --depth=1
    cd "${CLANG_PATH}"
    curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman --patch=glibc
    cd ..
  else
    echo "[!] Clang already exists. Skipping..."
  fi

  export PATH="${CLANG_PATH}/bin:${PATH}"

  if [ ! -f "${CLANG_PATH}/bin/clang" ]; then
    export KBUILD_COMPILER_STRING="$(${CLANG_PATH}/bin/clang --version | head -n 1)"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi
}

# Update Clang
function update_clang() {
  local CLANG_TYPE=$1
  local CLANG_PATH="${MAIN_CLANG_PATH}-${CLANG_TYPE}"

  cd "${CLANG_PATH}"
  git fetch -q origin main
  git pull origin main
  cd ..
}

# Set defconfig
function set_defconfig() {
  if [ -f "${MAIN_PATH}/arch/$ARCH/configs/${DEVICE_DEFCONFIG}" ]; then
    echo "[!] Using ${DEVICE_DEFCONFIG} as defconfig..."
  else
    echo "[!] ${DEVICE_DEFCONFIG} not found. Check config.env for correct defconfig."
    exit 1
  fi
}

# Set KernelSU
function kernelsu() {
  if [ "$KERNELSU" = "yes" ];then
    KERNEL_VARIANT="${KERNEL_VARIANT}-KernelSU"
    if [ ! -f "${MAIN_PATH}/KernelSU/README.md" ]; then
      cd ${MAIN_PATH}
      curl -LSsk "https://raw.githubusercontent.com/orkunergun/KernelSU/main/kernel/setup.sh" | bash -s v0.9.6
      sed -i "s/CONFIG_KSU=n/CONFIG_KSU=y/g" arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
    fi
    KERNELSU_VERSION="$((10000 + $(cd KernelSU && git rev-list --count HEAD) + 200))"
    git submodule update --init; cd ${MAIN_PATH}/KernelSU; git pull origin main; cd ..
  fi
}

# Compile kernel
function compile_kernel() {
  local CORES=$(nproc --all)

  if [ "$CLANG_TYPE" = "proton" ]; then
    sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' "${MAIN_PATH}/arch/$ARCH/configs/$DEVICE_DEFCONFIG" || echo ""
  else
    sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' "${MAIN_PATH}/arch/$ARCH/configs/$DEVICE_DEFCONFIG" || echo ""
  fi

  make O=out ARCH=$ARCH $DEVICE_DEFCONFIG
  make -j"$CORES" ARCH=$ARCH O=out \
    CC=clang \
    LD=ld.lld \
    LLVM=1 \
    LLVM_IAS=1 \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CLANG_TRIPLE=${CROSS_COMPILE_FLAG_TRIPLE} \
    CROSS_COMPILE=${CROSS_COMPILE_FLAG_64} \
    CROSS_COMPILE_ARM32=${CROSS_COMPILE_FLAG_32}
}

# Get AnyKernel
function get_anykernel() {
  if [[ -f "$KERNEL_IMAGE" ]]; then
    cd ${MAIN_PATH}
    git clone --depth=1 ${ANYKERNEL_REPO} -b ${ANYKERNEL_BRANCH} ${ANYKERNEL_PATH}
    cp $KERNEL_IMAGE ${ANYKERNEL_PATH}
  else
    echo "❌ Compile Kernel for $DEVICE_CODENAME failed, Check console log to fix it!"
    if [ "$CLEANUP" = "yes" ];then
      cleanup
    fi
    exit 1
  fi
}

# Zip kernel
function zip_kernel() {
  cd "${ANYKERNEL_PATH}" || exit 1

  if [ "$KERNELSU" = "yes" ];then
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${KERNEL_VERSION} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME}) | KernelSU Version: ${KERNELSU_VERSION}/g" anykernel.sh
  else
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${KERNEL_VERSION} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME})/g" anykernel.sh
  fi

  zip -r9 "[${KERNEL_VARIANT}]"-${KERNEL_NAME}-${KERNEL_VERSION}-${DEVICE_CODENAME}.zip * -x .git README.md *placeholder
  cd ..
  mkdir -p builds
  ZIPNAME="$(basename $(echo ${ANYKERNEL_PATH}/*.zip | sed "s/.zip//g"))"
  cp "${ANYKERNEL_PATH}"/*.zip "./builds/${ZIPNAME}-$DATE.zip"
}

# todo: upload build
# function upload_build() {
#   if [ "$UPLOAD" = "sourceforge" ];then
#     echo "Uploading to Sourceforge..."
#     cd builds
#     rsync -avz -e "ssh -p 22" ./* ${
#       SF_USER
#     }@frs.sourceforge.net:/home/frs/project/$SF_PROJECT/$DEVICE_CODENAME/$DEVICE_CODENAME-$DATE/
#   elif [ "$UPLOAD" = "github" ];then
#     echo "Uploading to Github..."
#     cd builds
#     gh release create $DEVICE_CODENAME-$DATE -t $DEVICE_CODENAME-$DATE -F $DEVICE_CODENAME-$DATE.md
#   elif [ "$UPLOAD" = "gitlab" ];then
#     echo "Uploading to Gitlab..."
#     cd builds
#     curl --request POST --header "PRIVATE-TOKEN : $GITLAB_TOKEN " --form "file=@$DEVICE_CODENAME-$DATE.zip" "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/uploads"
#   elif [ "$UPLOAD" = "transfer" ];then
#     echo "Uploading to Transfer.sh..."
#     cd builds
#     curl --upload-file $DEVICE_CODENAME-$DATE.zip https://transfer.sh/$DEVICE_CODENAME-$DATE.zip
#   elif [ "$UPLOAD" = "anonfiles" ];then
#     echo "Uploading to Anonfiles..."
#     cd builds
#     curl -F "file=@$DEVICE_CODENAME-$DATE.zip" https://api.anonfiles.com/upload
#   elif [ "$UPLOAD" = "gdrive" ];then
#     echo "Uploading to Google Drive..."
#     cd builds
#     gdrive upload $DEVICE_CODENAME-$DATE.zip
#   elif [ "$UPLOAD" = "mega" ];then
#     echo "Uploading to Mega..."
#     cd builds
#     megaput $DEVICE_CODENAME-$DATE.zip
#   elif [ "$UPLOAD" = "sourcehut" ];then
#     echo "Uploading to Sourcehut..."
#     cd builds
#   fi
# }

# Cleanup function
function cleanup() {
  cd "${MAIN_PATH}"
  sudo rm -rf "${ANYKERNEL_PATH}"
  sudo rm -rf out/
}

# Main script
function main() {
  clone_clang "$CLANG_TYPE"
  update_clang "$CLANG_TYPE"
  set_defconfig
  kernelsu
  compile_kernel
  get_anykernel
  zip_kernel
  cleanup
}

main
