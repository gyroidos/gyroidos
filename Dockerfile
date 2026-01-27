FROM debian:trixie

RUN sed -i 's/Components: main/Components: main contrib/' /etc/apt/sources.list.d/debian.sources

# Essentials
RUN apt-get update -y && apt-get install -y \
	apt-utils \
	passwd \
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
# repotool
	repo \
# CML dependencies
	libprotobuf-c1 \
	libprotobuf-c-dev \
	protobuf-compiler \
	protobuf-c-compiler \
	libcap-dev \
# CI
	libssl-dev \
	libcap-dev \
	libselinux-dev \
	apt-transport-https \
	e2fsprogs \
# LLVM
	clang \
	clang-tools \
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
# TPM simulator for test
	swtpm \
# Bootable medium
	util-linux \
	btrfs-progs \
	gdisk \
	parted \
	e2tools \
# user interaction
	screen \
	locales \
	ca-certificates \
	gosu \
	locales \
# optee python dependings
	python3-cryptography \
# Yocto requirements
	python3-distutils-extra

# protobuf-c-text library
ADD https://github.com/gyroidos/external_protobuf-c-text/archive/refs/heads/master.zip /opt/external_protobuf-c-text-master.zip

RUN cd /opt && unzip external_protobuf-c-text-master.zip

RUN cd /opt/external_protobuf-c-text-master && ./autogen.sh && ./configure && make && make install

RUN dpkg-reconfigure locales
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8

# set image label
ARG CML_BUILDER=jenkins
ARG BUILDUSER=9001
ARG KVM_GID

RUN if ! [ -z "${BUILDUSER}" ];then \
	echo "Preparing container home directory for user ${BUILDUSER}" && \
	adduser builder --disabled-password --uid "${BUILDUSER}" --gecos "" && \
	mkdir /home/builder/.ssh && \
	chown builder:builder /home/builder/.ssh && \
	chmod 700 /home/builder/.ssh && \
	groupadd --gid ${KVM_GID} kvm && \
	usermod -a -G kvm builder; \
else \
	echo "Docker build argument BUILDUSER not supplied, leaving unconfigured..."; \
fi

LABEL "com.gyroidos.builder"="${CML_BUILDER}"

RUN bash -c "echo \"Building as user $(id), BUILDUSER: ${BUILDUSER}, KVM_GID: ${KVM_GID}\""

# Set workdir
WORKDIR "/opt/ws-yocto/"
