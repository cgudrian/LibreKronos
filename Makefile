.SILENT:
.PHONY: all gcc-initial binutils

TARGET = i686-kronos-linux-gnu
ARCH = i368

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


all: binutils gcc-initial


%/.dir:
	mkdir -p $$(dirname $@)
	touch $@

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
		--with-sysroot=$(SYSROOT) > /dev/null
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


gcc-initial: $(TOOLS_DIR)/.gcc-initial

# GCC: download
$(DL_DIR)/$(GCC_ARCHIVE): $(DL_DIR)/.dir
	echo "Downloading GCC"
	wget --quiet -O $(DL_DIR)/$(GCC_ARCHIVE) "$(GCC_URL)"
	touch $@

# GCC: extract
$(GCC_SRC): $(DL_DIR)/$(GCC_ARCHIVE) $(SRC_DIR)/.dir
	echo "Extracting GCC"
	(cd $(SRC_DIR) && tar xvf $<) > /dev/null
	touch $@

# Initial GCC: configure
$(GCC_INITIAL_BUILD)/.configured: $(GCC_INITIAL_BUILD)/.dir $(GCC_SRC) $(TOOLS_DIR)/.binutils
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
		$(MAKE) > build.log 2>&1
	touch $@

# Initial GCC: install
$(TOOLS_DIR)/.gcc-initial: $(GCC_INITIAL_BUILD)/.built
	echo "Installing Initial GCC"
	cd $(GCC_INITIAL_BUILD) && \
		PATH=$(TOOLS_DIR)/bin:$$PATH \
		$(MAKE) install > /dev/null
	touch $@

gcc-clean:
	rm -rf $(GCC_INITIAL_BUILD)


clean: binutils-clean gcc-clean

cleanall:
	rm -rf $(WORK_DIR)

