.SILENT:
.PHONY: all

TARGET = i686-kronos-linux-gnu
ARCH = i368

DL_DIR = $(CURDIR)/work/downloads
SRC_DIR = $(CURDIR)/work/src
BUILD_DIR = $(CURDIR)/work/build
TOOLS_DIR = $(CURDIR)/work/tools
SYSROOT = $(CURDIR)/work/sysroot

BINUTILS_VERSION = 2.21.1
BINUTILS_ARCHIVE = binutils-$(BINUTILS_VERSION).tar.bz2
BINUTILS_URL = https://ftp.gnu.org/gnu/binutils/$(BINUTILS_ARCHIVE)
BINUTILS_SRC = $(SRC_DIR)/binutils-$(BINUTILS_VERSION)
BINUTILS_BUILD = $(BUILD_DIR)/binutils

all: binutils

$(DL_DIR) $(SRC_DIR) $(TOOLS_DIR) $(SYSROOT):
	mkdir -p $@

$(BUILD_DIR)/%:
	mkdir -p $@

binutils: $(TOOLS_DIR)/bin/$(TARGET)-ld

# binutils: download
$(DL_DIR)/$(BINUTILS_ARCHIVE): $(DL_DIR)
	echo "Downloading binutils"
	wget --quiet -O $(DL_DIR)/$(BINUTILS_ARCHIVE) "$(BINUTILS_URL)"
	touch $@

# binutils: extract
$(BINUTILS_SRC): $(DL_DIR)/$(BINUTILS_ARCHIVE) $(SRC_DIR)
	echo "Extracting binutils"
	(cd $(SRC_DIR) && tar xvf $<) > /dev/null
	touch $@

# binutils: configure
$(BINUTILS_BUILD)/Makefile: $(BINUTILS_BUILD) $(BINUTILS_SRC)
	echo "Configuring binutils"
	cd $(BINUTILS_BUILD) && \
	$(BINUTILS_SRC)/configure \
		--disable-werror \
		--target=$(TARGET) \
		--prefix=$(TOOLS_DIR) \
		--with-sysroot=$(SYSROOT) > /dev/null
	touch $@

# binutils: build
$(BINUTILS_BUILD)/ld: $(BINUTILS_BUILD)/Makefile
	echo "Building binutils"
	cd $(BINUTILS_BUILD) && $(MAKE) > build.log 2>&1

# binutils: install
$(TOOLS_DIR)/bin/$(TARGET)-ldm,: $(BINUTILS_BUILD)/ld
	echo "Installing binutils"
	cd $(BINUTILS_BUILD) && make install > /dev/null

clean:
	rm -rf work/build

cleanall:
	rm -rf work
