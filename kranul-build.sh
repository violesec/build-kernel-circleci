#!/usr/bin/env bash

# Load variables from config.env
export $(grep -v '^#' config.env | xargs)

# Path
MainPath="$(readlink -f -- $(pwd))"
MainClangPath="${MainPath}/clang"
AnyKernelPath="${MainPath}/anykernel"
CrossCompileFlagTriple="aarch64-linux-gnu-"
CrossCompileFlag64="aarch64-linux-gnu-"
CrossCompileFlag32="arm-linux-gnueabi-"

# Clone or update toolchain
function clone_or_update_clang() {
  local CLANG_NAME=$1
  local clang_path="${MainClangPath}-${CLANG_NAME}"
  local git_repo=""

  case $CLANG_NAME in
    "azure")
      git_repo="https://gitlab.com/Panchajanya1999/azure-clang"
      ;;
    "neutron"|"")
      git_repo="https://github.com/Neutron-Toolchains/clang"
      ;;
    "proton")
      git_repo="https://github.com/kdrag0n/proton-clang"
      ;;
    "lilium")
      git_repo="https://github.com/liliumproject/clang"
      ;;
    "zyc")
      git_repo="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null)"
      ;;
    *)
      echo "[!] Incorrect clang name. Check config.env for clang names."
      exit 1
      ;;
  esac

  if [ ! -f "${clang_path}/bin/clang" ]; then
    echo "[!] Clang is set to ${CLANG_NAME}, cloning it..."
    git clone "${git_repo}" "${clang_path}" --depth=1
    cd "${clang_path}"
    curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman --patch=glibc
    cd ..
  else
    echo "[!] Clang already exists. Skipping..."
  fi

  export PATH="${clang_path}/bin:${PATH}"

  if [ ! -f "${clang_path}/bin/clang" ]; then
    export KBUILD_COMPILER_STRING="$(${clang_path}/bin/clang --version | head -n 1)"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi
}

# Update Clang
function update_clang() {
  local CLANG_NAME=$1
  local clang_path="${MainClangPath}-${CLANG_NAME}"

  cd "${clang_path}"
  git fetch -q origin main
  git pull origin main
  cd ..
}

# Set defconfig
function set_defconfig() {
  if [ -f "${MainPath}/arch/$ARCH/configs/${DEVICE_DEFCONFIG}" ]; then
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
    if [ ! -f "${MainPath}/KernelSU/README.md" ]; then
      cd ${MainPath}
      curl -LSsk "https://raw.githubusercontent.com/orkunergun/KernelSU/main/kernel/setup.sh" | bash -s v0.9.6
      sed -i "s/CONFIG_KSU=n/CONFIG_KSU=y/g" arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
    fi
    KERNELSU_VERSION="$((10000 + $(cd KernelSU && git rev-list --count HEAD) + 200))"
    git submodule update --init; cd ${MainPath}/KernelSU; git pull origin main; cd ..
  fi
}

# Compile kernel
function compile_kernel() {
  local cores=$(nproc --all)

  if [ "$CLANG_NAME" = "proton" ]; then
    sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' "${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG" || echo ""
  else
    sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' "${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG" || echo ""
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
    CLANG_TRIPLE=${CrossCompileFlagTriple} \
    CROSS_COMPILE=${CrossCompileFlag64} \
    CROSS_COMPILE_ARM32=${CrossCompileFlag32}

  if [[ -f "$IMAGE" ]]; then
    cd "${MainPath}"
    cp out/.config "arch/${ARCH}/configs/${DEVICE_DEFCONFIG}" && git add "arch/${ARCH}/configs/${DEVICE_DEFCONFIG}" && git commit -m "defconfig: Regenerate"
    git clone --depth=1 "${AnyKernelRepo}" -b "${AnyKernelBranch}" "${AnyKernelPath}"
    cp "$IMAGE" "${AnyKernelPath}"
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
  cd "${AnyKernelPath}" || exit 1

  if [ "$KERNELSU" = "yes" ];then
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME}) | KernelSU Version: ${KERNELSU_VERSION}/g" anykernel.sh
  else
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME})/g" anykernel.sh
  fi

  zip -r9 "[${KERNEL_VARIANT}]"-${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}.zip * -x .git README.md *placeholder
  cd ..
  mkdir -p builds
  zipname="$(basename $(echo ${AnyKernelPath}/*.zip | sed "s/.zip//g"))"
  cp "${AnyKernelPath}"/*.zip "./builds/${zipname}-$DATE.zip"
}

# Cleanup function
function cleanup() {
  cd "${MainPath}"
  sudo rm -rf "${AnyKernelPath}"
  sudo rm -rf out/
}

# Main script
function main() {
  clone_or_update_clang "$CLANG_NAME"
  update_clang "$CLANG_NAME"
  set_defconfig
  kernelsu
  compile_kernel
  zip_kernel
  cleanup
}

main
