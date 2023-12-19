FROM debian:bookworm

# Essentials
RUN apt-get update -y && apt-get install -y \
	apt-utils \
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
	fdisk \
	curl \
	kmod \
	procps \
# CI
	libssl-dev \
	libcap-dev \
	libselinux-dev \
	apt-transport-https \
# LLVM
	clang \
	clang-tools  \
	libclang-dev \
	clang-format \
	python3-clang \
	lld \
	lldb \
# Image signing
	python3-protobuf \
# Qemu
	qemu-kvm \
	ovmf \
# Bootable medium
	util-linux \
	btrfs-progs \
	gdisk \
	parted \
	e2tools \
# user interaction
	libtar-dev \
	screen \
	locales \
	ca-certificates \
	gosu \
	locales \
# optee python dependings
	python3-cryptography

# protobuf-c-text library
# https://github.com/protobuf-c/protobuf-c-text
RUN cd /opt && git clone https://github.com/gyroidos/external_protobuf-c-text.git && cd /opt/external_protobuf-c-text && ./autogen.sh
RUN cd /opt/external_protobuf-c-text && ./configure && make && make install

RUN dpkg-reconfigure locales
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8

# set image label
ARG CML_BUILDER=jenkins

LABEL "com.gyroidos.builder"="${lbl}"

# Set workdir
WORKDIR "/opt/ws-yocto/"

ARG BUILDUSER

RUN if ! [ -z "${BUILDUSER}" ];then echo "Preparing container home directory for user ${BUILDUSER}" && adduser builder --disabled-password --uid "${BUILDUSER}" --gecos ""; else echo "Docker build argument BUILDUSER not supplied, leaving unconfigured...";fi

#COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

#ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

