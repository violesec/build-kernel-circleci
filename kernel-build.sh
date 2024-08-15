#!/usr/bin/env bash

# Date and time for zip name
TZ=Asia/Jakarta
DATE=$(date +"%Y%m%d")
DATE_ZIP=$(date +"%Y%m%d")
DATE_START=$(date +"%d-%m-%Y - %H:%M:%S")
DATE_TELEGRAM=$(date +"%d-%m-%Y - %H:%M:%S")
DATE_LOG=$(date +"%Y-%m-%d %H:%M:%S")

# Path
MAIN_PATH="$(readlink -f -- $(pwd))"
MAIN_CLANG_PATH="${MAIN_PATH}/clang"
ANYKERNEL_PATH="${MAIN_PATH}/anykernel"
CROSS_COMPILE_FLAG_TRIPLE="aarch64-linux-gnu-"
CROSS_COMPILE_FLAG_64="aarch64-linux-gnu-"
CROSS_COMPILE_FLAG_32="arm-linux-gnueabi-"

# Load variables from config.env
if [ -f config.env ]; then
  source config.env
  export $(grep -v '^#' config.env | xargs)
else
  echo "config.env not found!"
  exit 1
fi

# Clone or update toolchain
function clone_clang() {
  local CLANG_NAME=$1
  local CLANG_PATH="${MAIN_CLANG_PATH}-${CLANG_NAME}"
  local GIT_REPO=""

  case $CLANG_NAME in
    "azure")
      GIT_REPO="https://gitlab.com/Panchajanya1999/azure-clang"
      ;;
    "neutron"|"")
      GIT_REPO="https://github.com/Neutron-Toolchains/clang"
      ;;
    "proton")
      GIT_REPO="https://github.com/kdrag0n/proton-clang"
      ;;
    "lilium")
      GIT_REPO="https://github.com/liliumproject/clang"
      ;;
    "weebx")
      GIT_REPO="$(curl -k https://raw.githubusercontent.com/XSans0/WeebX-Clang/main/main/link.txt 2>/dev/null)"
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
    echo "[!] Clang is set to ${CLANG_NAME}, cloning it..."
    if ["$CLANG_NAME" = "lilium"];then
      mkdir -p "${CLANG_PATH}"
      cd "${CLANG_PATH}"
      wget -q $(curl -sSL "https://api.github.com/repos/liliumproject/clang/releases/latest" | jq -r '.assets[0].browser_download_url') -O "lilium-clang.tar.gz"
      tar -xf lilium-clang.tar.gz
      rm -f lilium-clang.tar.gz
    elif [ "$CLANG_NAME" = "weebx" ];then
      mkdir -p "${CLANG_PATH}"
      cd "${CLANG_PATH}"
      wget -q $(curl -k https://raw.githubusercontent.com/XSans0/WeebX-Clang/main/main/link.txt 2>/dev/null) -O "weebx-clang.tar.gz"
      tar -xf weebx-clang.tar.gz
      rm -f weebx-clang.tar.gz
    elif [ "$CLANG_NAME" = "zyc" ];then
      mkdir -p "${CLANG_PATH}"
      cd "${CLANG_PATH}"
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
      tar -xf zyc-clang.tar.gz
      rm -f zyc-clang.tar.gz
    else
      git clone "${GIT_REPO}" "${CLANG_PATH}" --depth=1
      cd "${CLANG_PATH}"
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman
      ./antman --patch=glibc
      cd ..
    fi
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

export KERNEL_VERSION=$(make kernelversion 2>&1 | tail -n 1)
export KERNEL_IMAGE="${MAIN_PATH}/out/arch/${ARCH}/boot/Image.gz-dtb"

# Update Clang
function update_clang() {
  local CLANG_NAME=$1
  local CLANG_PATH="${MAIN_CLANG_PATH}-${CLANG_NAME}"

  if [ "$KERNEL_UPDATE" = "yes" ];then
    if [ "$CLANG_NAME" = "azure" ] || ["$CLANG_NAME" = "proton"];then
      echo "[!] Clang is set to [$CLANG_NAME], checking for updates..."
      cd "${CLANG_PATH}"
      git fetch -q origin main
      git pull origin main
      cd ..
      echo "[!] Clang is up to date..."
    elif [ "$CLANG_NAME" = "neutron"] || [ "$CLANG_NAME" = ""];then
      echo "[!] Clang is set to [$CLANG_NAME], checking for updates..."
      cd "${CLANG_PATH}"
      git fetch -q origin main
      git pull origin main
      cd ..
      echo "[!] Clang is up to date..."
    elif [ "$CLANG_NAME" = "lilium" ];then
      cd "${CLANG_PATH}"
      RELEASE_URL="https://api.github.com/repos/liliumproject/clang/releases/latest"
      RESOURCE_LINK=$(curl -sSL "$RELEASE_URL" | jq -r '.assets[0].browser_download_url')
      if [ "$(cat README.md | grep "Build Date : " | cut -d: -f2 | sed "s/ //g")" != "${RESOURCE_LINK}" ]
      then
        echo "[!] Clang is outdated, updating..."
        rm -rf ./*
        wget -q $(curl -sSL "$RELEASE_URL" | jq -r '.assets[0].browser_download_url') -O "lilium-clang.tar.gz"
        tar -xf lilium-clang.tar.gz
        rm -f lilium-clang.tar.gz
      else
        echo "[!] Clang is up to date..."
      fi
    elif [ "$CLANG_NAME" = "weebx" ];then
      echo "[!] Clang is set to [$CLANG_NAME], checking for updates..."
      # cd "${CLANG_PATH}"
      # git fetch -q origin main
      # git pull origin main
      # cd ..
    elif [ "$CLANG_NAME" = "zyc" ];then
      echo "[!] Clang is set to [$CLANG_NAME], checking for updates..."
      cd "${CLANG_PATH}"
      RESOURCE_LINK="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null)"
      if [ "$(cat README.md | grep "Build Date : " | cut -d: -f2 | sed "s/ //g")" != "${RESOURCE_LINK}" ]
      then
        echo "[!] Clang is outdated, updating..."
        rm -rf ./*
        wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
        tar -xf zyc-clang.tar.gz
        rm -f zyc-clang.tar.gz
      else
        echo "[!] Clang is up to date..."
      fi
    fi
  else
    echo "[!] Kernel update is disabled..."
  fi
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
  local cores=$(nproc --all)

  if [ "$CLANG_NAME" = "proton" ]; then
    sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' "${MAIN_PATH}/arch/$ARCH/configs/$DEVICE_DEFCONFIG" || echo ""
  else
    sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' "${MAIN_PATH}/arch/$ARCH/configs/$DEVICE_DEFCONFIG" || echo ""
  fi

  make O=out ARCH=$ARCH $DEVICE_DEFCONFIG
  make -j"$cores" ARCH=$ARCH O=out \
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
    CROSS_COMPILE_ARM32=${CROSS_COMPILE_FLAG_32} \
    2>&1 | tee build.log
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

  zip -r9 "[${KERNEL_VARIANT}]"-${KERNEL_VERSION}-${DEVICE_CODENAME}.zip * -x .git README.md *placeholder
  cd ..
  mkdir -p builds
  zipname="$(basename $(echo ${ANYKERNEL_PATH}/*.zip | sed "s/.zip//g"))"
  cp "${ANYKERNEL_PATH}"/*.zip "./builds/${zipname}-$DATE.zip"
}

# Cleanup function
function cleanup() {
  cd "${MAIN_PATH}"
  sudo rm -rf "${ANYKERNEL_PATH}"
  sudo rm -rf out/
}

# Main script
function main() {
  clone_clang "$CLANG_NAME"
  update_clang "$CLANG_NAME"
  set_defconfig
  kernelsu
  compile_kernel
  get_anykernel
  zip_kernel
  cleanup
}

main