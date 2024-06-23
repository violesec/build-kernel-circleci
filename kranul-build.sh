#!/usr/bin/env bash
#
# Copyright (C) 2022-2023 Neebe3289 <neebexd@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Personal script for kranul compilation !!

# Load variables from config.env
export $(grep -v '^#' config.env | xargs)

# Path
MainPath="$(readlink -f -- $(pwd))"
MainClangPath="${MainPath}/clang"
AnyKernelPath="${MainPath}/anykernel"
CrossCompileFlagTriple="aarch64-linux-gnu-"
CrossCompileFlag64="aarch64-linux-gnu-"
CrossCompileFlag32="arm-linux-gnueabi-"

# Clone toolchain
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
function getclang() {
  if [ "${ClangName}" = "azure" ]; then
    if [ ! -f "${MainClangPath}-azure/bin/clang" ]; then
      echo "[!] Clang is set to azure, cloning it..."
      git clone https://gitlab.com/Panchajanya1999/azure-clang clang-azure --depth=1
      ClangPath="${MainClangPath}"-azure
      export PATH="${ClangPath}/bin:${PATH}"
      cd ${ClangPath}
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman
      ./antman --patch=glibc
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-azure
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]; then
    if [ ! -f "${MainClangPath}-neutron/bin/clang" ]; then
      echo "[!] Clang is set to neutron, cloning it..."
      mkdir -p "${MainClangPath}"-neutron
      ClangPath="${MainClangPath}"-neutron
      export PATH="${ClangPath}/bin:${PATH}"
      cd ${ClangPath}
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman && ./antman -S
      ./antman --patch=glibc
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-neutron
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "proton" ]; then
    if [ ! -f "${MainClangPath}-proton/bin/clang" ]; then
      echo "[!] Clang is set to proton, cloning it..."
      git clone https://github.com/kdrag0n/proton-clang clang-proton --depth=1
      ClangPath="${MainClangPath}"-proton
      export PATH="${ClangPath}/bin:${PATH}"
      cd ${ClangPath}
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman
      ./antman --patch=glibc
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-proton
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "lilium" ]; then
    if [ ! -f "${MainClangPath}-lilium/bin/clang" ]; then
      echo "[!] Clang is set to lilium, cloning it..."
      mkdir -p ${MainClangPath}-lilium
      cd clang-lilium
      wget https://github.com/liliumproject/clang/releases/download/20240623/lilium_clang-20240623.tar.gz
      tar -xf lilium_clang*.tar.gz
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman
      ./antman --patch=glibc
      rm -f lilium_clang*.tar.gz
      ClangPath="${MainClangPath}"-lilium
      export PATH="${ClangPath}/bin:${PATH}"
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-lilium
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "zyc" ]; then
    if [ ! -f "${MainClangPath}-zyc/bin/clang" ]; then
      echo "[!] Clang is set to zyc, cloning it..."
      mkdir -p ${MainClangPath}-zyc
      cd clang-zyc
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
      tar -xf zyc-clang.tar.gz
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman
      ./antman --patch=glibc
      rm -f zyc-clang.tar.gz
      ClangPath="${MainClangPath}"-zyc
      export PATH="${ClangPath}/bin:${PATH}"
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-zyc
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  else
    echo "[!] Incorrect clang name. Check config.env for clang names."
    exit 1
  fi
  if [ ! -f '${MainClangPath}-${ClangName}/bin/clang' ]; then
    export KBUILD_COMPILER_STRING="$(${MainClangPath}-${ClangName}/bin/clang --version | head -n 1)"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi
}

function updateclang() {
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
  if [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]; then
    echo "[!] Clang is set to neutron, checking for updates..."
    cd clang-neutron
    if [ "$(./antman -U | grep "Nothing to do")" = "" ];then
      ./antman --patch=glibc
    else
      echo "[!] No updates have been found, skipping"
    fi
    cd ..
    elif [ "${ClangName}" = "zyc" ]; then
      echo "[!] Clang is set to zyc, checking for updates..."
      cd clang-zyc
      ZycLatest="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-lastbuild.txt)"
      if [ "$(cat README.md | grep "Build Date : " | cut -d: -f2 | sed "s/ //g")" != "${ZycLatest}" ];then
        echo "[!] An update have been found, updating..."
        sudo rm -rf ./*
        wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
        tar -xf zyc-clang.tar.gz
        rm -f zyc-clang.tar.gz
      else
        echo "[!] No updates have been found, skipping..."
      fi
      cd ..
    elif [ "${ClangName}" = "azure" ]; then
      cd clang-azure
      git fetch -q origin main
      git pull origin main
      cd ..
    elif [ "${ClangName}" = "proton" ]; then
      cd clang-proton
      git fetch -q origin master
      git pull origin master
      cd ..
  fi
}

# Enviromental variable
DEVICE_MODEL="Redmi 9"
DEVICE_CODENAME="lancelot"
export DEVICE_DEFCONFIG="lancelot_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_USER="Orkun"
export KBUILD_BUILD_HOST="CI"
export KERNEL_NAME="$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )"
export SUBLEVEL="v4.14.$(cat "${MainPath}/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"
IMAGE="${MainPath}/out/arch/arm64/boot/Image.gz-dtb"
CORES="$(nproc --all)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Start Compile
START=$(date +"%s")

compile(){
if [ "$ClangName" = "proton" ]; then
  sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' ${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG || echo ""
else
  sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' ${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG || echo ""
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
    CLANG_TRIPLE=${CrossCompileFlagTriple} \
    CROSS_COMPILE=${CrossCompileFlag64} \
    CROSS_COMPILE_ARM32=${CrossCompileFlag32}

   if [[ -f "$IMAGE" ]]; then
      cd ${MainPath}
      cp out/.config arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git add arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git commit -m "defconfig: Regenerate"
      git clone --depth=1 ${AnyKernelRepo} -b ${AnyKernelBranch} ${AnyKernelPath}
      cp $IMAGE ${AnyKernelPath}
   else
      echo "❌ Compile Kernel for $DEVICE_CODENAME failed, Check console log to fix it!"
      if [ "$CLEANUP" = "yes" ];then
        cleanup
      fi
      exit 1
   fi
}

# Zipping function
function zipping() {
    cd ${AnyKernelPath} || exit 1
    if [ "$KERNELSU" = "yes" ];then
      sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME}) | KernelSU Version: ${KERNELSU_VERSION}/g" anykernel.sh
    else
      sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME})/g" anykernel.sh
    fi
    zip -r9 "[${KERNEL_VARIANT}]"-${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}.zip * -x .git README.md *placeholder
    cd ..
    mkdir -p builds
    zipname="$(basename $(echo ${AnyKernelPath}/*.zip | sed "s/.zip//g"))"
    cp ${AnyKernelPath}/*.zip ./builds/${zipname}-$DATE.zip
    cleanup
}

# Cleanup function
function cleanup() {
    cd ${MainPath}
    sudo rm -rf ${AnyKernelPath}
    sudo rm -rf out/
}

# KernelSU function
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

getclang
updateclang
kernelsu
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
