FROM debian:bookworm

RUN sed -i 's/Components: main/Components: main contrib/' /etc/apt/sources.list.d/debian.sources

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

# Backport openssl 3.3 from debian trixie to make unit tests with openssl provider API work
RUN echo "deb http://deb.debian.org/debian trixie main" > /etc/apt/sources.list.d/trixie.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    -t trixie openssl

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

LABEL "com.gyroidos.builder"="${CML_BUILDER}"

# Set workdir
WORKDIR "/opt/ws-yocto/"

ARG BUILDUSER

RUN if ! [ -z "${BUILDUSER}" ];then \
	echo "Preparing container home directory for user ${BUILDUSER}" && \
	adduser builder --disabled-password --uid "${BUILDUSER}" --gecos "" && \
	mkdir /home/builder/.ssh && \
	chown builder:builder /home/builder/.ssh && \
	chmod 700 /home/builder/.ssh; \
else \
	echo "Docker build argument BUILDUSER not supplied, leaving unconfigured..."; \
fi

#COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

#ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

