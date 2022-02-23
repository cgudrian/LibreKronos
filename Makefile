.SILENT:
.PHONY: all gcc-initial binutils

TARGET = i686-kronos-linux-gnu
ARCH = x86

PATCH_DIR = $(CURDIR)/patches
WORK_DIR = $(CURDIR)/work
DL_DIR = $(WORK_DIR)/downloads
SRC_DIR = $(WORK_DIR)/src
BUILD_DIR = $(WORK_DIR)/build
TOOLS_DIR = $(WORK_DIR)/tools
SYSROOT = $(WORK_DIR)/sysroot

BINUTILS_VERSION = 2.21.1
BINUTILS_ARCHIVE = binutils-$(BINUTILS_VERSION).tar.bz2
BINUTILS_URL = https://ftp.gnu.org/gnu/binutils/$(BINUTILS_ARCHIVE)
BINUTILS_SRC = $(SRC_DIR)/binutils-$(BINUTILS_VERSION)
BINUTILS_BUILD = $(BUILD_DIR)/binutils

GCC_VERSION = 4.5.0
GCC_ARCHIVE = gcc-$(GCC_VERSION).tar.bz2
GCC_URL = https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/$(GCC_ARCHIVE)
GCC_SRC = $(SRC_DIR)/gcc-$(GCC_VERSION)
GCC_INITIAL_BUILD = $(BUILD_DIR)/gcc-initial

GLIBC_VERSION = 2.13
GLIBC_ARCHIVE = glibc-$(GLIBC_VERSION).tar.bz2
GLIBC_URL = https://ftp.gnu.org/gnu/glibc/$(GLIBC_ARCHIVE)
GLIBC_SRC = $(SRC_DIR)/glibc-$(GLIBC_VERSION)
GLIBC_INITIAL_BUILD = $(BUILD_DIR)/glibc-initial

KERNEL_SRC = $(SRC_DIR)/linux-kronos
KERNEL_REPO = https://github.com/cgudrian/linux-kronos.git


all: binutils gcc-initial $(SYSROOT)/.linux-headers


%/.dir:
	mkdir -p $$(dirname $@)
	touch $@

# Newer versions of makeinfo choke on the outdated GCC documentation.
# GCC builds fine with a dummy makeinfo.
$(TOOLS_DIR)/bin/makeinfo: $(TOOLS_DIR)/bin/.dir
	ln -sf $$(which true) $(TOOLS_DIR)/bin/makeinfo

#####################################################################
# Binutils
#####################################################################

binutils: $(TOOLS_DIR)/.binutils

# binutils: download
$(DL_DIR)/$(BINUTILS_ARCHIVE): $(DL_DIR)/.dir
	echo "Downloading Binutils"
	wget --quiet -O $(DL_DIR)/$(BINUTILS_ARCHIVE) "$(BINUTILS_URL)"
	touch $@

# binutils: extract
$(BINUTILS_SRC): $(DL_DIR)/$(BINUTILS_ARCHIVE) $(SRC_DIR)/.dir
	echo "Extracting Binutils"
	(cd $(SRC_DIR) && tar xvf $<) > /dev/null
	touch $@

# binutils: configure
$(BINUTILS_BUILD)/.configured: $(BINUTILS_BUILD)/.dir $(BINUTILS_SRC)
	echo "Configuring Binutils"
	cd $(BINUTILS_BUILD) && \
	$(BINUTILS_SRC)/configure \
		--disable-werror \
		--target=$(TARGET) \
		--prefix=$(TOOLS_DIR) \
		--with-sysroot=$(SYSROOT) \
	> /dev/null
	touch $@

# binutils: build
$(BINUTILS_BUILD)/.built: $(BINUTILS_BUILD)/.configured
	echo "Building Binutils"
	cd $(BINUTILS_BUILD) && $(MAKE) > build.log 2>&1
	touch $@

# binutils: install
$(TOOLS_DIR)/.binutils: $(BINUTILS_BUILD)/.built
	echo "Installing Binutils"
	cd $(BINUTILS_BUILD) && make install > /dev/null
	touch $@

binutils-clean:
	rm -rf $(BINUTILS_BUILD)


#####################################################################
# GCC
#####################################################################

gcc-initial: $(TOOLS_DIR)/.gcc-initial

# GCC: download
$(DL_DIR)/$(GCC_ARCHIVE): $(DL_DIR)/.dir
	echo "Downloading GCC"
	wget --quiet -O $(DL_DIR)/$(GCC_ARCHIVE) "$(GCC_URL)"
	touch $@

# GCC: extract
$(GCC_SRC): $(DL_DIR)/$(GCC_ARCHIVE) $(SRC_DIR)/.dir
	echo "Extracting GCC"
	cd $(SRC_DIR) && tar xvf $< > /dev/null
	touch $@

# Initial GCC: configure
$(GCC_INITIAL_BUILD)/.configured: $(GCC_INITIAL_BUILD)/.dir $(GCC_SRC) $(TOOLS_DIR)/.binutils $(TOOLS_DIR)/bin/makeinfo
	echo "Configuring GCC"
	cd $(GCC_INITIAL_BUILD) && \
	$(GCC_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(TOOLS_DIR) \
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
	PATH=$(TOOLS_DIR)/bin:$$PATH \
	$(MAKE) \
	> build.log 2>&1
	touch $@

# Initial GCC: install
$(TOOLS_DIR)/.gcc-initial: $(GCC_INITIAL_BUILD)/.built
	echo "Installing Initial GCC"
	cd $(GCC_INITIAL_BUILD) && \
	PATH=$(TOOLS_DIR)/bin:$$PATH \
	$(MAKE) install \
	> /dev/null
	touch $@


#####################################################################
# Linux
#####################################################################

# Kernel: download
$(DL_DIR)/linux-kronos.git/HEAD: $(DL_DIR)/.dir
	echo "Cloning Linux repository"
	git clone --bare --quiet $(KERNEL_REPO) $(DL_DIR)/linux-kronos.git

# Kernel: clone to src
$(KERNEL_SRC)/.git/HEAD: $(DL_DIR)/linux-kronos.git/HEAD
	echo "Checking out Kernel sources"
	git clone --quiet $(DL_DIR)/linux-kronos.git $(KERNEL_SRC)

# Kernel install
$(SYSROOT)/.linux-headers: $(KERNEL_SRC)/.git/HEAD
	echo "Installing Linux headers"
	cd $(KERNEL_SRC) && \
	PATH=$(TOOLS_DIR)/bin:$$PATH \
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

glibc-initial: $(SYSROOT)/.glibc-headers $(SYSROOT)/.glibc-startup-files $(SYSROOT)/.dummy-libc # $(TOOLS_DIR)/.glibc-initial

# glibc: download
$(DL_DIR)/$(GLIBC_ARCHIVE): $(DL_DIR)/.dir
	echo "Downloading glibc"
	wget --quiet -O $(DL_DIR)/$(GLIBC_ARCHIVE) "$(GLIBC_URL)"
	touch $@

# glibc: extract
$(GLIBC_SRC)/.dir: $(DL_DIR)/$(GLIBC_ARCHIVE) $(SRC_DIR)/.dir
	echo "Extracting glibc"
	cd $(SRC_DIR) && tar xvf $< > /dev/null
	touch $@

# glibc: patch
$(GLIBC_SRC)/.patched: $(GLIBC_SRC)/.dir
	echo "Patching glibc"
	cd $(GLIBC_SRC) && \
	QUILT_PATCHES=$(PATCH_DIR)/glibc \
	quilt push -aq \
	> /dev/null
	touch $@

# Initial glibc: configure
$(GLIBC_INITIAL_BUILD)/.configured: $(GLIBC_INITIAL_BUILD)/.dir $(GLIBC_SRC)/.patched $(TOOLS_DIR)/.binutils $(TOOLS_DIR)/bin/makeinfo
	echo "Configuring glibc"
	cd $(GLIBC_INITIAL_BUILD) && \
	BUILD_CC=gcc \
	CC=$(TOOLS_DIR)/bin/$(TARGET)-gcc \
	CXX=$(TOOLS_DIR)/bin/$(TARGET)-g++ \
	AR=$(TOOLS_DIR)/bin/$(TARGET)-ar \
	RANLIB=$(TOOLS_DIR)/bin/$(TARGET)-ranlib \
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
	$(TOOLS_DIR)/bin/$(TARGET)-gcc -nostdlib -nostartfiles -shared -x c /dev/null \
		-o $(SYSROOT)/usr/lib/libc.so
	touch $@

clean: binutils-clean gcc-initial-clean

cleanall:
	rm -rf $(WORK_DIR)

