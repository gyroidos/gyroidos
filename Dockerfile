FROM debian:buster


# Essentials
RUN apt-get update && apt-get install -y gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat cpio python python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping libsdl1.2-dev xterm lsb-release libprotobuf-c1 libprotobuf-c-dev protobuf-compiler protobuf-c-compiler autoconf libtool libtool-bin re2c check rsync lz4 zstd


# CI
RUN apt-get install -y libssl-dev libcap-dev libselinux-dev apt-transport-https
#
# clang-9 toolchain for debian stretch
# maybe even 11 would be good
RUN echo "deb http://apt.llvm.org/buster/ llvm-toolchain-buster-10 main" >> /etc/apt/sources.list
RUN echo "deb-src http://apt.llvm.org/buster/ llvm-toolchain-buster-10 main" >> /etc/apt/sources.list
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN apt-get update && apt-get install -y clang-10 clang-tools-10 clang-10-doc libclang-common-10-dev libclang-10-dev libclang1-10 clang-format-10 python3-clang-10 clangd-10 lld-10 lldb-10 libfuzzer-10-dev
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-10 100
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-10 100
RUN update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-10 100
RUN update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-10 100
#
# protobuf-c-text library
# https://github.com/protobuf-c/protobuf-c-text
RUN cd /opt && git clone https://github.com/gyroidos/external_protobuf-c-text.git && cd /opt/external_protobuf-c-text && ./autogen.sh
RUN cd /opt/external_protobuf-c-text && ./configure && make && make install

# Image signing
RUN apt-get update && apt-get install -y python-protobuf python3-protobuf

# Qemu
RUN apt-get update && apt-get install -y qemu-kvm ovmf

# Bootable medium
RUN apt-get update && apt-get install -y util-linux btrfs-progs gdisk parted

RUN apt-get update && apt-get install -y libssl-dev libtar-dev screen locales ca-certificates gosu locales
RUN dpkg-reconfigure locales
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8

RUN apt-get update && apt-get install -y kmod procps curl

# trusted-connector build dependencies
# for new yarn based build of trusted-connector core compartment
RUN curl -sL https://deb.nodesource.com/setup_11.x | bash - \
	&& apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
	&& apt-get update \
	&& apt-get install -y vim openjdk-11-jdk-headless openjdk-11-jre-headless yarn

# optee python dependings
RUN apt-get update && apt-get install -y python-crypto python3-crypto

WORKDIR "/opt/ws-yocto/"

#COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

#ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

