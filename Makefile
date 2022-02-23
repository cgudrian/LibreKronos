.SILENT:
.PHONY: all gcc-initial binutils

TARGET = i686-kronos-linux-gnu
ARCH = x86

PATCHES = $(CURDIR)/patches
WORK = $(CURDIR)/work
DL = $(WORK)/downloads
SRC = $(WORK)/src
BUILD_DIR = $(WORK)/build
TOOLS = $(WORK)/tools
SYSROOT = $(WORK)/sysroot

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

GLIBC_VERSION = 2.13
GLIBC_ARCHIVE = glibc-$(GLIBC_VERSION).tar.bz2
GLIBC_URL = https://ftp.gnu.org/gnu/glibc/$(GLIBC_ARCHIVE)
GLIBC_SRC = $(SRC)/glibc-$(GLIBC_VERSION)
GLIBC_INITIAL_BUILD = $(BUILD_DIR)/glibc-initial

KERNEL_SRC = $(SRC)/linux-kronos
KERNEL_REPO = https://github.com/cgudrian/linux-kronos.git


all: binutils gcc-initial $(SYSROOT)/.linux-headers


%/.dir:
	mkdir -p $$(dirname $@)
	touch $@

# Newer versions of makeinfo choke on the outdated GCC documentation.
# GCC builds fine with a dummy makeinfo.
$(TOOLS)/bin/makeinfo: $(TOOLS)/bin/.dir
	ln -sf $$(which true) $(TOOLS)/bin/makeinfo

#####################################################################
# Binutils
#####################################################################

binutils: $(TOOLS)/.binutils

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
		--prefix=$(TOOLS) \
		--with-sysroot=$(SYSROOT) \
	> /dev/null
	touch $@

# binutils: build
$(BINUTILS_BUILD)/.built: $(BINUTILS_BUILD)/.configured
	echo "Building Binutils"
	cd $(BINUTILS_BUILD) && $(MAKE) > build.log 2>&1
	touch $@

# binutils: install
$(TOOLS)/.binutils: $(BINUTILS_BUILD)/.built
	echo "Installing Binutils"
	cd $(BINUTILS_BUILD) && make install > /dev/null
	touch $@

binutils-clean:
	rm -rf $(BINUTILS_BUILD)


#####################################################################
# GCC
#####################################################################

gcc-intermediate: $(TOOLS)/.gcc-intermediate

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
$(GCC_INITIAL_BUILD)/.configured: $(GCC_INITIAL_BUILD)/.dir $(GCC_SRC) $(TOOLS)/.binutils $(TOOLS)/bin/makeinfo
	echo "Configuring Initial GCC"
	cd $(GCC_INITIAL_BUILD) && \
	$(GCC_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(TOOLS) \
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
	PATH=$(TOOLS)/bin:$$PATH $(MAKE) > build.log 2>&1
	touch $@

# Initial GCC: install
$(TOOLS)/.gcc-initial: $(GCC_INITIAL_BUILD)/.built
	echo "Installing Initial GCC"
	cd $(GCC_INITIAL_BUILD) && \
	PATH=$(TOOLS)/bin:$$PATH $(MAKE) install > /dev/null
	touch $@


# Intermediate GCC: configure
$(GCC_INTERMEDIATE_BUILD)/.configured: $(TOOLS)/.gcc-initial $(SYSROOT)/.glibc-initial $(GCC_INTERMEDIATE_BUILD)/.dir
	echo "Configuring Intermediate GCC"
	cd $(GCC_INTERMEDIATE_BUILD) && \
	$(GCC_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(TOOLS) \
		--disable-nls \
		--with-sysroot=$(SYSROOT) \
		--disable-libssp --disable-libgomp --disable-libmudflap \
		--disable-libquadmath --disable-libffi \
		--enable-languages=c \
	> /dev/null 2>&1
	touch $@

# Intermediate GCC: build
$(GCC_INTERMEDIATE_BUILD)/.built: $(GCC_INTERMEDIATE_BUILD)/.configured
	echo "Building Intermediate GCC"
	cd $(GCC_INTERMEDIATE_BUILD) && \
	PATH=$(TOOLS)/bin:$$PATH $(MAKE) > build.log 2>&1
	touch $@

# Intermediate GCC: install
$(TOOLS)/.gcc-intermediate: $(GCC_INTERMEDIATE_BUILD)/.built
	echo "Installing Intermediate GCC"
	cd $(GCC_INTERMEDIATE_BUILD) && \
	PATH=$(TOOLS)/bin:$$PATH $(MAKE) install > /dev/null
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
$(SYSROOT)/.linux-headers: $(KERNEL_SRC)/.git/HEAD
	echo "Installing Linux headers"
	cd $(KERNEL_SRC) && \
	PATH=$(TOOLS)/bin:$$PATH \
	$(MAKE) headers_install \
		ARCH=$(ARCH) CROSS_COMPILE=$(TARGET)- \
		INSTALL_HDR_PATH=$(SYSROOT)/usr \
	> /dev/null 2>&1
	touch $@

gcc-initial-clean:
	rm -rf $(GCC_INITIAL_BUILD)

#####################################################################
# glibc
#####################################################################

$(SYSROOT)/.glibc-initial: $(SYSROOT)/.glibc-headers $(SYSROOT)/.glibc-startup-files $(SYSROOT)/.dummy-libc
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
$(GLIBC_INITIAL_BUILD)/.configured: $(TOOLS)/.gcc-initial $(GLIBC_INITIAL_BUILD)/.dir $(GLIBC_SRC)/.patched $(TOOLS)/.binutils $(TOOLS)/bin/makeinfo
	echo "Configuring glibc"
	cd $(GLIBC_INITIAL_BUILD) && \
	BUILD_CC=gcc \
	CC=$(TOOLS)/bin/$(TARGET)-gcc \
	CXX=$(TOOLS)/bin/$(TARGET)-g++ \
	AR=$(TOOLS)/bin/$(TARGET)-ar \
	RANLIB=$(TOOLS)/bin/$(TARGET)-ranlib \
	$(GLIBC_SRC)/configure \
		--host=$(TARGET) \
		--prefix=/usr \
		--with-headers=$(SYSROOT)/usr/include \
		--disable-profile --without-gd --without-cvs \
		--enable-add-ons=nptl,libidn \
	> /dev/null 2>&1
	touch $@

# Initial glibc: headers
$(SYSROOT)/.glibc-headers: $(GLIBC_INITIAL_BUILD)/.configured $(SYSROOT)/.linux-headers
	echo "Installing glibc headers"
	cd $(GLIBC_INITIAL_BUILD) && \
	$(MAKE) install-headers install_root=$(SYSROOT) \
		install-bootstrap-headers=yes \
	> install-headers.log 2>&1
	touch $(SYSROOT)/usr/include/gnu/stubs.h
	cp $(GLIBC_INITIAL_BUILD)/bits/stdio_lim.h $(SYSROOT)/usr/include/bits
	touch $@

# Initial glibc: headers
$(SYSROOT)/.glibc-startup-files: $(SYSROOT)/.glibc-headers $(SYSROOT)/usr/lib/.dir
	echo "Installing glibc startup files"
	cd $(GLIBC_INITIAL_BUILD) && $(MAKE) csu/subdir_lib > make-startup-files.log 2>&1
	cp $(GLIBC_INITIAL_BUILD)/csu/crt*.o $(SYSROOT)/usr/lib
	touch $@

# Initial glibc: dummy libc.so
$(SYSROOT)/.dummy-libc: $(GLIBC_INITIAL_BUILD)/.configured $(SYSROOT)/usr/lib/.dir
	echo "Creating dummy libc"
	$(TOOLS)/bin/$(TARGET)-gcc -nostdlib -nostartfiles -shared -x c /dev/null \
		-o $(SYSROOT)/usr/lib/libc.so
	touch $@

clean: binutils-clean gcc-initial-clean

cleanall:
	rm -rf $(WORK)
