VERSION:=snapshot

OUTPUT=output
HOST=x86_64-w64-mingw32
SYSROOT=$(shell readlink -m $(OUTPUT)/sysroot)

MAKE_JOBS:=4

WGET=wget -q
PKG_CONFIG=$(HOST)-pkg-config
PKG_CONFIG_PATH=$(SYSROOT)/lib/pkgconfig
PKG_CONFIG_LIBDIR=$(SYSROOT)/lib/pkgconfig

LIBUSB1_VER=1.0.24
LIBUSB1_URL="https://github.com/libusb/libusb/releases/download/v$(LIBUSB1_VER)/libusb-$(LIBUSB1_VER).tar.bz2"
LIBUSB1_TAR=$(OUTPUT)/libusb-$(LIBUSB1_VER).tar.bz2
LIBUSB1_DIR=$(OUTPUT)/libusb-$(LIBUSB1_VER)

HIDAPI_VER=0.10.1
HIDAPI_URL="https://github.com/libusb/hidapi/archive/hidapi-$(HIDAPI_VER).tar.gz"
HIDAPI_TAR=$(OUTPUT)/hidapi-$(HIDAPI_VER).tar.gz
HIDAPI_DIR=$(OUTPUT)/hidapi-hidapi-$(HIDAPI_VER)

LIBFTDI_VER=1.5
LIBFTDI_URL="https://www.intra2net.com/en/developer/libftdi/download/libftdi1-$(LIBFTDI_VER).tar.bz2"
LIBFTDI_TAR=$(OUTPUT)/libftdi1-$(LIBFTDI_VER).tar.bz2
LIBFTDI_DIR=$(OUTPUT)/libftdi1-$(LIBFTDI_VER)

CAPSTONE_VER=4.0.2
CAPSTONE_URL="https://github.com/aquynh/capstone/archive/${CAPSTONE_VER}.tar.gz"
CAPSTONE_TAR=$(OUTPUT)/capstone-${CAPSTONE_VER}.tar.gz
CAPSTONE_DIR=$(OUTPUT)/capstone-$(CAPSTONE_VER)

OPENOCD_VER=8488e4e
OPENOCD_URL="https://github.com/riscv/riscv-openocd.git"
OPENOCD_DIR=$(OUTPUT)/riscv-openocd-$(OPENOCD_VER)

PACKAGE=openocd-$(VERSION).zip

.PHONY: dep clean dist-clean all

all: $(OUTPUT)/$(PACKAGE)

dep:
	sudo apt install binutils-mingw-w64-x86-64 g++-mingw-w64-x86-64 gcc-mingw-w64-base gcc-mingw-w64-x86-64 \
		gfortran-mingw-w64-x86-64 mingw-w64-common mingw-w64-x86-64-dev gdb-mingw-w64 gdb-mingw-w64-target \
		pkg-config mingw-w64-tools autotools-dev automake autoconf m4 libtool texinfo unzip cmake zip

# =========== download & extarct ==========

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

$(CAPSTONE_DIR).stamp: $(CAPSTONE_TAR)
	cd $(OUTPUT) && tar zxvf ../$<
	touch $@

$(OPENOCD_DIR).stamp:
	git clone --recursive $(OPENOCD_URL) $(OPENOCD_DIR)
	cd $(OPENOCD_DIR) && git reset --hard $(OPENOCD_VER) 
	touch $@

download: $(LIBUSB1_TAR) $(HIDAPI_TAR) $(LIBFTDI_TAR)
extract: $(LIBUSB1_DIR).stamp $(HIDAPI_DIR).stamp $(LIBFTDI_DIR).stamp $(OPENOCD_DIR).stamp

# =========== build dependency ===========
$(LIBUSB1_DIR).build.stamp: $(LIBUSB1_DIR).stamp
	mkdir -p $(LIBUSB1_DIR)/build
	cd $(LIBUSB1_DIR)/build && ../configure --host=$(HOST) --build=`../config.guess` --with-sysroot=$(SYSROOT) --prefix=/ \
		--enable-shared --disable-static
	cd $(LIBUSB1_DIR)/build && make -j$(MAKE_JOBS) && make install DESTDIR=$(SYSROOT)
	touch $@

$(HIDAPI_DIR).build.stamp: $(HIDAPI_DIR).stamp
	# 补丁: 注释第二个AC_CONFIG_MACRO_DIR
	sed -i 'N; s/)\nAC_CONFIG_MACRO_DIR/)\n# AC_CONFIG_MACRO_DIR/' $(HIDAPI_DIR)/configure.ac
	cd $(HIDAPI_DIR) && ./bootstrap
	mkdir -p $(HIDAPI_DIR)/build
	cd $(HIDAPI_DIR)/build && ../configure --host=$(HOST) --build=`../config.guess` --with-sysroot=$(SYSROOT)  --prefix=/ \
		--enable-shared --disable-static --disable-testgui
	cd $(HIDAPI_DIR)/build && make -j$(MAKE_JOBS) && make install DESTDIR=$(SYSROOT)
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
	cd $(LIBFTDI_DIR)/build && make -j$(MAKE_JOBS) && make install
	touch $@

$(CAPSTONE_DIR).build.stamp: $(CAPSTONE_DIR).stamp
	mkdir -p $(CAPSTONE_DIR)/build
	cd $(CAPSTONE_DIR) && make install DESTDIR=$(SYSROOT) CROSS=$(HOST)- \
		CAPSTONE_BUILD_CORE_ONLY=yes CAPSTONE_STATIC=yes CAPSTONE_SHARED=no
	touch $@

# ========== patch source ===========
$(OUTPUT)/patch.stamp:
	cp -rf patch/* $(OPENOCD_DIR)/
	touch $@

# ========== build openocd ===========
OPENOCD_CONFIG =  --disable-doxygen-html --disable-doxygen-pdf 
OPENOCD_CONFIG += --disable-internal-libjaylink --disable-target64  
OPENOCD_CONFIG += --disable-cmsis-dap --disable-cmsis-dap-v2 
OPENOCD_CONFIG += --disable-jtag_dpi --disable-jtag_vpi
OPENOCD_CONFIG += --disable-nulink --disable-stlink --disable-ulink --disable-rlink --disable-jlink --disable-openjtag
OPENOCD_CONFIG += --disable-usb-blaster --disable-usb-blaster-2
OPENOCD_CONFIG += --disable-zy1000-master --disable-zy1000 
OPENOCD_CONFIG += --disable-parport --disable-parport-ppdev --disable-parport-giveio 
OPENOCD_CONFIG += --disable-ioutil --disable-bcm2835gpio --disable-imx_gpio --disable-sysfsgpio 
OPENOCD_CONFIG += --disable-rshim --disable-vdebug --disable-xlnx-pcie-xvc
OPENOCD_CONFIG += --disable-ti-icdi --disable-ft232r --disable-vsllink 
OPENOCD_CONFIG += --disable-xds110 --disable-osbdm --disable-opendous --disable-aice --disable-usbprog --disable-armjtagew
OPENOCD_CONFIG += --disable-kitprog --disable-presto --disable-amtjtagaccel
OPENOCD_CONFIG += --disable-ep93xx --disable-at91rm9200 --disable-gw16012 --disable-buspirate 
OPENOCD_CONFIG += --disable-minidriver-dummy --disable-remote-bitbang

# CAPSTONE_CFLAGS="-I$(SYSROOT)/include/capstone" CAPSTONE_LIBS="-L$(SYSROOT)/lib -lcapstone" \

$(OPENOCD_DIR).build.stamp: $(OPENOCD_DIR).stamp $(HIDAPI_DIR).build.stamp $(LIBFTDI_DIR).build.stamp $(OUTPUT)/patch.stamp
	cd $(OPENOCD_DIR) && ./bootstrap
	mkdir -p $(OPENOCD_DIR)/build
	cd $(OPENOCD_DIR)/build && \
	LIBUSB1_CFLAGS="-I$(SYSROOT)/include/libusb-1.0" LIBUSB1_LIBS="-L$(SYSROOT)/lib -llibusb-1.0" \
	HIDAPI_CFLAGS="-I$(SYSROOT)/include/hidapi" HIDAPI_LIBS="-L$(SYSROOT)/lib -lhidapi" \
	LIBFTDI_CFLAGS="-I$(SYSROOT)/include" LIBFTDI_LIBS="-L$(SYSROOT)/lib -lftdi1" \
	../configure --host=$(HOST) --build=`../config.guess` --with-sysroot=$(SYSROOT)  --prefix=/ \
		$(OPENOCD_CONFIG)
	perl -p -i -e 's/\+dev/\ (S-Link$(VERSION)) /g' $(OPENOCD_DIR)/build/config.h		
	cd $(OPENOCD_DIR)/build && make -j$(MAKE_JOBS) && make install-strip DESTDIR=$(SYSROOT)
	touch $@

# ========== package ==========
$(OUTPUT)/$(PACKAGE): $(OPENOCD_DIR).build.stamp
	cp README.md $(SYSROOT)
	cp package.json.in $(SYSROOT)/package.json
	perl -p -i -e 's/\@VERSION\@/$(VERSION)/' $(SYSROOT)/package.json
	cd $(SYSROOT) && zip -r $(PACKAGE) \
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