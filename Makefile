V := snapshot

PWD = $(shell pwd)
OUTPUT=output
PACKAGE=$(OUTPUT)/openocd.zip
HOST=x86_64-w64-mingw32
SYSROOT=$(shell readlink -m $(OUTPUT)/sysroot)

MAKE_JOBS := $(shell grep -c ^processor /proc/cpuinfo 2>/dev/null)

WGET=wget -q

LIBUSB1_VER=1.0.23
LIBUSB1_URL="https://github.com/libusb/libusb/releases/download/v$(LIBUSB1_VER)/libusb-$(LIBUSB1_VER).tar.bz2"
LIBUSB1_TAR=$(OUTPUT)/libusb-$(LIBUSB1_VER).tar.bz2
LIBUSB1_DIR=$(OUTPUT)/libusb-$(LIBUSB1_VER)

HIDAPI_VER=0.9.0
HIDAPI_URL="https://github.com/libusb/hidapi/archive/hidapi-$(HIDAPI_VER).tar.gz"
HIDAPI_TAR=$(OUTPUT)/hidapi-$(HIDAPI_VER).tar.gz
HIDAPI_DIR=$(OUTPUT)/hidapi-hidapi-$(HIDAPI_VER)

LIBFTDI_VER=1.4
LIBFTDI_URL="https://www.intra2net.com/en/developer/libftdi/download/libftdi1-$(LIBFTDI_VER).tar.bz2"
LIBFTDI_TAR=$(OUTPUT)/libftdi1-$(LIBFTDI_VER).tar.bz2
LIBFTDI_DIR=$(OUTPUT)/libftdi1-$(LIBFTDI_VER)

OPENOCD_VER=1ba1b87
OPENOCD_URL="https://github.com/riscv/riscv-openocd.git"
OPENOCD_DIR=$(OUTPUT)/riscv-openocd-$(OPENOCD_VER)


.PHONY: all dep download extract clean dist-clean help

all: $(PACKAGE)

dep:
	sudo apt install binutils-mingw-w64-x86-64 g++-mingw-w64-x86-64 gcc-mingw-w64-base gcc-mingw-w64-x86-64 \
		gfortran-mingw-w64-x86-64 mingw-w64-common mingw-w64-x86-64-dev gdb-mingw-w64 gdb-mingw-w64-target \
		pkg-config mingw-w64-tools autotools-dev automake autoconf m4 libtool texinfo unzip cmake zip

# ==================  下载解压 ==================

$(LIBUSB1_TAR):
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(LIBUSB1_URL)

$(HIDAPI_TAR):
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(HIDAPI_URL)

$(LIBFTDI_TAR):
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(LIBFTDI_URL)

$(CAPSTONE_TAR):
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(CAPSTONE_URL)

$(LIBUSB1_DIR).stamp: $(LIBUSB1_TAR)
	cd $(OUTPUT) && tar jxvf ../$<
	touch $@

$(HIDAPI_DIR).stamp: $(HIDAPI_TAR)
	cd $(OUTPUT) && tar xvf ../$<
	touch $@

$(LIBFTDI_DIR).stamp: $(LIBFTDI_TAR)
	cd $(OUTPUT) && tar jxvf ../$<
	touch $@

$(OPENOCD_DIR).stamp:
	git clone --recursive $(OPENOCD_URL) $(OPENOCD_DIR)
	cd $(OPENOCD_DIR) && git reset --hard $(OPENOCD_VER) 
	touch $@

download: $(LIBUSB1_TAR) $(HIDAPI_TAR) $(LIBFTDI_TAR)
extract: $(LIBUSB1_DIR).stamp $(HIDAPI_DIR).stamp $(LIBFTDI_DIR).stamp $(OPENOCD_DIR).stamp

# =========== 编译依赖包 ===========
$(LIBUSB1_DIR).build.stamp: $(LIBUSB1_DIR).stamp
	mkdir -p $(LIBUSB1_DIR)/build
	cd $(LIBUSB1_DIR)/build && ../configure --host=$(HOST) --build=`../config.guess` --with-sysroot=$(SYSROOT) --prefix=/ \
		--enable-shared --disable-static
	cd $(LIBUSB1_DIR)/build && make -j$(MAKE_JOBS) && make install-strip DESTDIR=$(SYSROOT)
	touch $@

$(HIDAPI_DIR).build.stamp: $(HIDAPI_DIR).stamp
	# 补丁: 注释第二个AC_CONFIG_MACRO_DIR
	perl -i -0pe 's/(AM_INIT_AUTOMAKE.*)AC_CONFIG_MACRO_DIR[^\n]*/\1/gms' $(HIDAPI_DIR)/configure.ac
	cd $(HIDAPI_DIR) && ./bootstrap
	mkdir -p $(HIDAPI_DIR)/build
	cd $(HIDAPI_DIR)/build && ../configure --host=$(HOST) --build=`../config.guess` --with-sysroot=$(SYSROOT)  --prefix=/ \
		--enable-shared --disable-static --disable-testgui
	cd $(HIDAPI_DIR)/build && make -j$(MAKE_JOBS) && make install-strip DESTDIR=$(SYSROOT)
	touch $@

$(LIBFTDI_DIR).build.stamp: $(LIBFTDI_DIR).stamp $(LIBUSB1_DIR).build.stamp 
	mkdir -p $(LIBFTDI_DIR)/build
	cd $(LIBFTDI_DIR)/build && \
		cmake -DCMAKE_TOOLCHAIN_FILE=../cmake/Toolchain-x86_64-w64-mingw32.cmake \
		-DCMAKE_INSTALL_PREFIX=${SYSROOT} \
		-DLIBUSB_INCLUDE_DIR=$(SYSROOT)/include/libusb-1.0 \
		-DLIBUSB_LIBRARIES=$(SYSROOT)/lib/libusb-1.0.dll.a \
		-DEXAMPLES=OFF -DFTDI_EEPROM=OFF \
    	..
	cd $(LIBFTDI_DIR)/build && make -j$(MAKE_JOBS) && make install/strip
	touch $@

# ========== 补丁 ===========
$(OUTPUT)/patch.stamp: $(OPENOCD_DIR).stamp
	cp -rf patch/* $(OPENOCD_DIR)/
	touch $@

# ========== 编译 openocd ===========
OPENOCD_CONFIG =  --disable-doxygen-html --disable-doxygen-pdf 
OPENOCD_CONFIG += --disable-internal-libjaylink
OPENOCD_CONFIG += --disable-cmsis-dap
OPENOCD_CONFIG += --disable-nulink --disable-stlink --disable-ulink --disable-rlink --disable-jlink --disable-openjtag
OPENOCD_CONFIG += --disable-usb-blaster --disable-usb-blaster-2
OPENOCD_CONFIG += --disable-zy1000-master --disable-zy1000 
OPENOCD_CONFIG += --disable-parport
OPENOCD_CONFIG += --disable-bcm2835gpio --disable-imx_gpio --disable-sysfsgpio 
OPENOCD_CONFIG += --disable-rshim  --disable-xlnx-pcie-xvc
OPENOCD_CONFIG += --disable-ti-icdi --disable-ft232r --disable-vsllink 
OPENOCD_CONFIG += --disable-xds110 --disable-osbdm --disable-opendous --disable-aice --disable-usbprog --disable-armjtagew
OPENOCD_CONFIG += --disable-kitprog --disable-presto --disable-amtjtagaccel
OPENOCD_CONFIG += --disable-ep93xx --disable-at91rm9200 --disable-gw16012 --disable-buspirate 
OPENOCD_CONFIG += --disable-remote-bitbang


$(OPENOCD_DIR).build.stamp: $(OPENOCD_DIR).stamp $(HIDAPI_DIR).build.stamp $(LIBFTDI_DIR).build.stamp $(OUTPUT)/patch.stamp
	cd $(OPENOCD_DIR) && ./bootstrap
	cd $(OPENOCD_DIR) && chmod -x guess-rev.sh
	mkdir -p $(OPENOCD_DIR)/build
	cd $(OPENOCD_DIR)/build && \
	LIBUSB1_CFLAGS="-I$(SYSROOT)/include/libusb-1.0" LIBUSB1_LIBS="-L$(SYSROOT)/lib -llibusb-1.0" \
	HIDAPI_CFLAGS="-I$(SYSROOT)/include/hidapi" HIDAPI_LIBS="-L$(SYSROOT)/lib -lhidapi" \
	LIBFTDI_CFLAGS="-I$(SYSROOT)/include" LIBFTDI_LIBS="-L$(SYSROOT)/lib -lftdi1" \
	../configure --host=$(HOST) --build=`../config.guess` --with-sysroot=$(SYSROOT)  --prefix=/ \
		$(OPENOCD_CONFIG)
	perl -p -i -e 's/\+dev/\ (S-Link$(V)) /g' $(OPENOCD_DIR)/build/config.h		
	cd $(OPENOCD_DIR)/build && make -j$(MAKE_JOBS) && make install-strip DESTDIR=$(SYSROOT)
	touch $@

# ========== 打包 ==========
$(PACKAGE): $(OPENOCD_DIR).build.stamp
	cp README.md $(SYSROOT)
	cp package.json.in $(SYSROOT)/package.json
	perl -p -i -e 's/\@VERSION\@/$(V)/' $(SYSROOT)/package.json
	cd $(SYSROOT) && zip -r `basename $(PACKAGE)` \
		bin/openocd.exe \
		bin/libftdi1.dll \
		bin/libhidapi-0.dll \
		bin/libusb-1.0.dll \
		share/openocd/scripts/interface/ftdi/openocd-usb.cfg \
		share/openocd/scripts/target/phoenix*.cfg \
		share/openocd/scripts/baord/phoenix*.cfg \
		README.md package.json

clean: 
	rm -fr $(LIBUSB1_DIR) $(HIDAPI_DIR) $(LIBFTDI_DIR) $(CAPSTONE_DIR) $(OPENOCD_DIR)
	rm -fr $(OUTPUT)/*.stamp
	rm -fr $(OUTPUT)/sysroot

dist-clean:
	rm -fr $(OUTPUT)

help :
	@echo "make V=x.x.x"
	@echo "OTHER TARGETS:"
	@echo "dep               - 安装系统依赖"
	@echo "download          - 下载依赖包"
	@echo "extract           - 解压依赖包"
	@echo "clean             - 清除中间文件"
	@echo "dist-clean        - 清除中间文件和下载的依赖包"
