.SILENT:
.PHONY: all

TARGET = i686-kronos-linux-gnu
ARCH = x86

PATCHES = $(CURDIR)/patches
WORK = $(CURDIR)/work
DL = $(CURDIR)/.downloads
SRC = $(WORK)/src
BUILD_DIR = $(WORK)/build
HOST_SYSROOT = $(CURDIR)/sysroots/$(shell gcc -dumpmachine)
TARGET_SYSROOT = $(CURDIR)/sysroots/$(TARGET)

BINUTILS_VERSION = 2.21.1
BINUTILS_ARCHIVE = binutils-$(BINUTILS_VERSION).tar.bz2
BINUTILS_URL = https://ftp.gnu.org/gnu/binutils/$(BINUTILS_ARCHIVE)
BINUTILS_SRC = $(SRC)/binutils-$(BINUTILS_VERSION)
BINUTILS_BUILD = $(BUILD_DIR)/binutils

GCC_VERSION = 4.5.0
GCC_ARCHIVE = gcc-$(GCC_VERSION).tar.bz2
GCC_URL = https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/$(GCC_ARCHIVE)
GCC_SRC = $(SRC)/gcc-$(GCC_VERSION)
GCC_INITIAL_BUILD = $(BUILD_DIR)/gcc-initial
GCC_INTERMEDIATE_BUILD = $(BUILD_DIR)/gcc-intermediate
GCC_BUILD = $(BUILD_DIR)/gcc

GLIBC_VERSION = 2.13
GLIBC_ARCHIVE = glibc-$(GLIBC_VERSION).tar.bz2
GLIBC_URL = https://ftp.gnu.org/gnu/glibc/$(GLIBC_ARCHIVE)
GLIBC_SRC = $(SRC)/glibc-$(GLIBC_VERSION)
GLIBC_INITIAL_BUILD = $(BUILD_DIR)/glibc-initial
GLIBC_BUILD = $(BUILD_DIR)/glibc

KERNEL_SRC = $(SRC)/linux-kronos
KERNEL_REPO = https://github.com/cgudrian/linux-kronos.git


all: $(HOST_SYSROOT)/.gcc

%/.dir:
	mkdir -p $$(dirname $@)
	touch $@

# Newer versions of makeinfo choke on the outdated GCC documentation.
# GCC builds fine with a dummy makeinfo.
$(HOST_SYSROOT)/bin/makeinfo: $(HOST_SYSROOT)/bin/.dir
	ln -sf $$(which true) $(HOST_SYSROOT)/bin/makeinfo

#####################################################################
# Binutils
#####################################################################

binutils: $(HOST_SYSROOT)/.binutils

# binutils: download
$(DL)/$(BINUTILS_ARCHIVE): $(DL)/.dir
	echo "Downloading Binutils"
	wget --quiet -O $(DL)/$(BINUTILS_ARCHIVE) "$(BINUTILS_URL)"
	touch $@

# binutils: extract
$(BINUTILS_SRC): $(DL)/$(BINUTILS_ARCHIVE) $(SRC)/.dir
	echo "Extracting Binutils"
	(cd $(SRC) && tar xvf $<) > /dev/null
	touch $@

# binutils: configure
$(BINUTILS_BUILD)/.configured: $(BINUTILS_BUILD)/.dir $(BINUTILS_SRC)
	echo "Configuring Binutils"
	cd $(BINUTILS_BUILD) && \
	$(BINUTILS_SRC)/configure \
		--disable-werror \
		--target=$(TARGET) \
		--prefix=$(HOST_SYSROOT) \
		--with-sysroot=$(TARGET_SYSROOT) \
	> /dev/null
	touch $@

# binutils: build
$(BINUTILS_BUILD)/.built: $(BINUTILS_BUILD)/.configured
	echo "Building Binutils"
	cd $(BINUTILS_BUILD) && $(MAKE) > build.log 2>&1
	touch $@

# binutils: install
$(HOST_SYSROOT)/.binutils: $(BINUTILS_BUILD)/.built
	echo "Installing Binutils"
	cd $(BINUTILS_BUILD) && make install > /dev/null
	touch $@

binutils-clean:
	rm -rf $(BINUTILS_BUILD)


#####################################################################
# GCC
#####################################################################

gcc-intermediate: $(HOST_SYSROOT)/.gcc-intermediate

# GCC: download
$(DL)/$(GCC_ARCHIVE): $(DL)/.dir
	echo "Downloading GCC"
	wget --quiet -O $(DL)/$(GCC_ARCHIVE) "$(GCC_URL)"
	touch $@

# GCC: extract
$(GCC_SRC): $(DL)/$(GCC_ARCHIVE) $(SRC)/.dir
	echo "Extracting GCC"
	cd $(SRC) && tar xvf $< > /dev/null
	touch $@

# Initial GCC: configure
$(GCC_INITIAL_BUILD)/.configured: $(GCC_INITIAL_BUILD)/.dir $(GCC_SRC) $(HOST_SYSROOT)/.binutils $(HOST_SYSROOT)/bin/makeinfo
	echo "Configuring Initial GCC"
	cd $(GCC_INITIAL_BUILD) && \
	$(GCC_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(HOST_SYSROOT) \
		--disable-nls \
		--without-headers --with-newlib \
		--disable-shared --disable-threads --disable-libssp \
		--disable-libgomp --disable-libmudflap --disable-libquadmath \
		--disable-decimal-float --disable-libffi \
		--enable-languages=c \
	> /dev/null 2>&1
	touch $@

# Initial GCC: build
$(GCC_INITIAL_BUILD)/.built: $(GCC_INITIAL_BUILD)/.configured
	echo "Building Initial GCC"
	cd $(GCC_INITIAL_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) > build.log 2>&1
	touch $@

# Initial GCC: install
$(HOST_SYSROOT)/.gcc-initial: $(GCC_INITIAL_BUILD)/.built
	echo "Installing Initial GCC"
	cd $(GCC_INITIAL_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) install > /dev/null
	touch $@


# Intermediate GCC: configure
$(GCC_INTERMEDIATE_BUILD)/.configured: $(HOST_SYSROOT)/.gcc-initial $(TARGET_SYSROOT)/.glibc-initial $(GCC_INTERMEDIATE_BUILD)/.dir
	echo "Configuring Intermediate GCC"
	cd $(GCC_INTERMEDIATE_BUILD) && \
	$(GCC_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(HOST_SYSROOT) \
		--disable-nls \
		--with-sysroot=$(TARGET_SYSROOT) \
		--disable-libssp --disable-libgomp --disable-libmudflap \
		--disable-libquadmath --disable-libffi \
		--enable-languages=c \
	> /dev/null 2>&1
	touch $@

# Intermediate GCC: build
$(GCC_INTERMEDIATE_BUILD)/.built: $(GCC_INTERMEDIATE_BUILD)/.configured
	echo "Building Intermediate GCC"
	cd $(GCC_INTERMEDIATE_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) > build.log 2>&1
	touch $@

# Intermediate GCC: install
$(HOST_SYSROOT)/.gcc-intermediate: $(GCC_INTERMEDIATE_BUILD)/.built
	echo "Installing Intermediate GCC"
	cd $(GCC_INTERMEDIATE_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) install > /dev/null
	touch $@

# GCC: configure
$(GCC_BUILD)/.configured: $(HOST_SYSROOT)/.gcc-intermediate $(TARGET_SYSROOT)/.glibc $(GCC_BUILD)/.dir
	echo "Configuring GCC"
	cd $(GCC_BUILD) && \
	$(GCC_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(HOST_SYSROOT) \
		--disable-nls \
		--with-sysroot=$(TARGET_SYSROOT) \
		--enable-__cxa_atexit \
		--disable-libssp --disable-libgomp --disable-libmudflap \
		--enable-languages=c \
	> /dev/null 2>&1
	touch $@

# GCC: build
$(GCC_BUILD)/.built: $(GCC_BUILD)/.configured
	echo "Building GCC"
	cd $(GCC_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) > build.log 2>&1
	touch $@

# GCC: install
$(HOST_SYSROOT)/.gcc: $(GCC_BUILD)/.built
	echo "Installing GCC"
	cd $(GCC_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) install > /dev/null
	cp -d $(HOST_SYSROOT)/$(TARGET)/lib/libgcc_s.so* $(TARGET_SYSROOT)/lib
	# cp -d $(HOST_SYSROOT)/$(TARGET)/lib/libstdc++.so* $(TARGET_SYSROOT)/lib
	touch $@


#####################################################################
# Linux
#####################################################################

# Kernel: download
$(DL)/linux-kronos.git/HEAD: $(DL)/.dir
	echo "Cloning Linux repository"
	git clone --bare --quiet $(KERNEL_REPO) $(DL)/linux-kronos.git

# Kernel: clone to src
$(KERNEL_SRC)/.git/HEAD: $(DL)/linux-kronos.git/HEAD
	echo "Checking out Kernel sources"
	git clone --quiet $(DL)/linux-kronos.git $(KERNEL_SRC)

# Kernel install
$(TARGET_SYSROOT)/.linux-headers: $(KERNEL_SRC)/.git/HEAD
	echo "Installing Linux headers"
	cd $(KERNEL_SRC) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH \
	$(MAKE) headers_install \
		ARCH=$(ARCH) CROSS_COMPILE=$(TARGET)- \
		INSTALL_HDR_PATH=$(TARGET_SYSROOT)/usr \
	> /dev/null 2>&1
	touch $@

gcc-initial-clean:
	rm -rf $(GCC_INITIAL_BUILD)

#####################################################################
# glibc
#####################################################################

$(TARGET_SYSROOT)/.glibc-initial: $(TARGET_SYSROOT)/.glibc-headers $(TARGET_SYSROOT)/.glibc-startup-files $(TARGET_SYSROOT)/.dummy-libc
	touch $@

# glibc: download
$(DL)/$(GLIBC_ARCHIVE): $(DL)/.dir
	echo "Downloading glibc"
	wget --quiet -O $(DL)/$(GLIBC_ARCHIVE) "$(GLIBC_URL)"
	touch $@

# glibc: extract
$(GLIBC_SRC)/.dir: $(DL)/$(GLIBC_ARCHIVE) $(SRC)/.dir
	echo "Extracting glibc"
	cd $(SRC) && tar xvf $< > /dev/null
	touch $@

# glibc: patch
$(GLIBC_SRC)/.patched: $(GLIBC_SRC)/.dir
	echo "Patching glibc"
	cd $(GLIBC_SRC) && \
	QUILT_PATCHES=$(PATCHES)/glibc \
	quilt push -aq \
	> /dev/null
	touch $@

# Initial glibc: configure
$(GLIBC_INITIAL_BUILD)/.configured: $(HOST_SYSROOT)/.gcc-initial $(GLIBC_INITIAL_BUILD)/.dir $(GLIBC_SRC)/.patched
	echo "Configuring Intermediate glibc"
	cd $(GLIBC_INITIAL_BUILD) && \
	BUILD_CC=gcc \
	CC=$(HOST_SYSROOT)/bin/$(TARGET)-gcc \
	CXX=$(HOST_SYSROOT)/bin/$(TARGET)-g++ \
	AR=$(HOST_SYSROOT)/bin/$(TARGET)-ar \
	RANLIB=$(HOST_SYSROOT)/bin/$(TARGET)-ranlib \
	$(GLIBC_SRC)/configure \
		--host=$(TARGET) \
		--prefix=/usr \
		--with-headers=$(TARGET_SYSROOT)/usr/include \
		--disable-profile --without-gd --without-cvs \
		--enable-add-ons=nptl,libidn \
	> /dev/null 2>&1
	touch $@

# Initial glibc: headers
$(TARGET_SYSROOT)/.glibc-headers: $(GLIBC_INITIAL_BUILD)/.configured $(TARGET_SYSROOT)/.linux-headers
	echo "Installing glibc headers"
	cd $(GLIBC_INITIAL_BUILD) && \
	$(MAKE) install-headers install_root=$(TARGET_SYSROOT) \
		install-bootstrap-headers=yes \
	> install-headers.log 2>&1
	touch $(TARGET_SYSROOT)/usr/include/gnu/stubs.h
	cp $(GLIBC_INITIAL_BUILD)/bits/stdio_lim.h $(TARGET_SYSROOT)/usr/include/bits
	touch $@

# Initial glibc: headers
$(TARGET_SYSROOT)/.glibc-startup-files: $(TARGET_SYSROOT)/.glibc-headers $(TARGET_SYSROOT)/usr/lib/.dir
	echo "Installing glibc startup files"
	cd $(GLIBC_INITIAL_BUILD) && $(MAKE) csu/subdir_lib > make-startup-files.log 2>&1
	cp $(GLIBC_INITIAL_BUILD)/csu/crt*.o $(TARGET_SYSROOT)/usr/lib
	touch $@

# Initial glibc: dummy libc.so
$(TARGET_SYSROOT)/.dummy-libc: $(GLIBC_INITIAL_BUILD)/.configured $(TARGET_SYSROOT)/usr/lib/.dir
	echo "Creating dummy libc"
	$(HOST_SYSROOT)/bin/$(TARGET)-gcc -nostdlib -nostartfiles -shared -x c /dev/null \
		-o $(TARGET_SYSROOT)/usr/lib/libc.so
	touch $@

# glibc: configure
$(GLIBC_BUILD)/.configured: $(HOST_SYSROOT)/.gcc-initial $(GLIBC_BUILD)/.dir $(HOST_SYSROOT)/.gcc-intermediate
	echo "Configuring glibc"
	cd $(GLIBC_BUILD) && \
	BUILD_CC=gcc \
	CC="$(HOST_SYSROOT)/bin/$(TARGET)-gcc -U__i686" \
	CXX=$(HOST_SYSROOT)/bin/$(TARGET)-g++ \
	AR=$(HOST_SYSROOT)/bin/$(TARGET)-ar \
	RANLIB=$(HOST_SYSROOT)/bin/$(TARGET)-ranlib \
	$(GLIBC_SRC)/configure \
		--host=$(TARGET) \
		--prefix=/usr \
		--with-headers=$(TARGET_SYSROOT)/usr/include \
		--disable-profile --without-gd --without-cvs \
		--enable-add-ons=nptl,libidn \
	> /dev/null 2>&1
	touch $@

# glibc: build
$(GLIBC_BUILD)/.built: $(GLIBC_BUILD)/.configured
	echo "Building glibc"
	cd $(GLIBC_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) > build.log 2>&1
	touch $@

# glibc: install
$(TARGET_SYSROOT)/.glibc: $(GLIBC_BUILD)/.built
	echo "Installing glibc"
	cd $(GLIBC_BUILD) && \
	PATH=$(HOST_SYSROOT)/bin:$$PATH $(MAKE) install install_root=$(TARGET_SYSROOT) > install.log 2>&1
	touch $@


clean: binutils-clean gcc-initial-clean

cleanall:
	rm -rf $(WORK)
