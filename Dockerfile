FROM debian:bookworm

# Essentials
RUN apt-get update -y
RUN apt-get install -y \
	gawk \
	wget \
	git-core \
	diffstat \
	unzip \
	texinfo \
	gcc-multilib \
	build-essential \
	chrpath \
	socat \
	cpio \
	python3 \
	python3-pip \
	python3-pexpect \
	xz-utils \
	debianutils \
	iputils-ping \
	libsdl1.2-dev \
	xterm \
	lsb-release \
	libprotobuf-c1 \
	libprotobuf-c-dev \
	protobuf-compiler \
	protobuf-c-compiler \
	autoconf \
	libtool \
	libtool-bin \
	re2c \
	check \
	rsync \
	lz4 \
	zstd \
	fdisk

# CI
RUN apt-get install -y \
	libssl-dev \
	libcap-dev \
	libselinux-dev \
	apt-transport-https

RUN apt-get install -y \
	clang-16 \
	clang-tools-16 \
	clang-16-doc \
	libclang-16-dev \
	clang-format-16 \
	python3-clang-16 \
	clangd-16 \
	lld-16 \
	lldb-16 \
	libfuzzer-16-dev

RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-16 100
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-16 100
RUN update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-16 100
RUN update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-16 100

# protobuf-c-text library
# https://github.com/protobuf-c/protobuf-c-text
RUN cd /opt && git clone https://github.com/gyroidos/external_protobuf-c-text.git && cd /opt/external_protobuf-c-text && ./autogen.sh
RUN cd /opt/external_protobuf-c-text && ./configure && make && make install

# Image signing
RUN apt-get update -y && apt-get install -y python3-protobuf

# Qemu
RUN apt-get update -y && apt-get install -y qemu-kvm ovmf

# Bootable medium
RUN apt-get update -y && apt-get install -y util-linux btrfs-progs gdisk parted e2tools

RUN apt-get update -y && apt-get install -y libssl-dev libtar-dev screen locales ca-certificates gosu locales
RUN dpkg-reconfigure locales
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8

RUN apt-get update -y && apt-get install -y kmod procps curl

# optee python dependings
RUN apt-get update -y && apt-get install -y python3-pycryptodome

WORKDIR "/opt/ws-yocto/"

ARG BUILDUSER

RUN if ! [ -z "${BUILDUSER}" ];then echo "Preparing container home directory for user ${BUILDUSER}" && adduser builder --disabled-password --uid "${BUILDUSER}" --gecos ""; else echo "Docker build argument BUILDUSER not supplied, leaving unconfigured...";fi

#COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

#ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

