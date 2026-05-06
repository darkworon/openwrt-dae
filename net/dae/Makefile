# SPDX-License-Identifier: GPL-2.0-only
#
# OpenWrt package for dae with an overridable outbound source.

include $(TOPDIR)/rules.mk

PKG_NAME:=dae
PKG_VERSION:=$(or $(DAE_PKG_VERSION),2.0.0_alpha_git)
PKG_RELEASE:=$(or $(DAE_PKG_RELEASE),1)

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=$(or $(DAE_SOURCE_URL),https://github.com/daeuniverse/dae.git)
PKG_SOURCE_VERSION:=$(or $(DAE_SOURCE_VERSION),$(or $(DAE_SOURCE_REF),main))
PKG_SOURCE_DATE:=$(or $(DAE_SOURCE_DATE),git)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_DATE).tar.xz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MIRROR_HASH:=$(or $(DAE_MIRROR_HASH),skip)

PKG_LICENSE:=AGPL-3.0-only
PKG_LICENSE_FILE:=LICENSE
PKG_MAINTAINER:=darkworon

PKG_BUILD_DEPENDS:=golang/host bpf-headers
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

OUTBOUND_REPO:=$(or $(DAE_OUTBOUND_REPO),https://github.com/darkworon/outbound.git)
OUTBOUND_REF:=$(or $(DAE_OUTBOUND_REF),stickyip-salamander)
OUTBOUND_DIR:=$(PKG_BUILD_DIR)/.openwrt-dae-outbound

GO_PKG:=github.com/daeuniverse/dae
GO_PKG_EXCLUDES:=control/kern/tests
GO_PKG_LDFLAGS_X:= \
	$(GO_PKG)/cmd.Version=$(PKG_VERSION) \
	$(GO_PKG)/common/consts.MaxMatchSetLen_=1024
GO_PKG_TAGS:=trace

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/bpf.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/dae/Default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=A lightweight and high-performance transparent proxy solution
  URL:=https://github.com/daeuniverse/dae
endef

define Package/dae
  $(call Package/dae/Default)
  DEPENDS:=$(GO_ARCH_DEPENDS) $(BPF_DEPENDS) \
    +ca-bundle +kmod-sched-core +kmod-sched-bpf +kmod-xdp-sockets-diag \
    +kmod-veth
endef

define Package/dae-geoip
  $(call Package/dae/Default)
  TITLE:=geoip for dae
  DEPENDS:=+dae +v2ray-geoip
  PKGARCH:=all
endef

define Package/dae-geosite
  $(call Package/dae/Default)
  TITLE:=geosite for dae
  DEPENDS:=+dae +v2ray-geosite
  PKGARCH:=all
endef

define Package/dae/description
  dae is a lightweight and high-performance transparent proxy solution.

  This package builds dae from git and replaces github.com/daeuniverse/outbound
  with OUTBOUND_REPO/OUTBOUND_REF so Hysteria2 Salamander support can be built
  before it is released upstream.
endef

define Package/dae/conffiles
/etc/dae/config.dae
/etc/config/dae
endef

DAE_CFLAGS:= \
	-O2 -Wall -Werror \
	-DMAX_MATCH_SET_LEN=1024 \
	-I$(BPF_HEADERS_DIR)/tools/lib \
	-I$(BPF_HEADERS_DIR)/arch/$(BPF_KARCH)/include/asm/mach-generic

define Build/Compile
	( \
		set -e; \
		rm -rf "$(OUTBOUND_DIR)"; \
		git clone "$(OUTBOUND_REPO)" "$(OUTBOUND_DIR)"; \
		git -C "$(OUTBOUND_DIR)" checkout "$(OUTBOUND_REF)"; \
		export \
		$(GO_GENERAL_BUILD_CONFIG_VARS) \
		$(GO_PKG_BUILD_CONFIG_VARS) \
		$(GO_PKG_BUILD_VARS) \
		BPF_CLANG="$(CLANG)" \
		BPF_STRIP_FLAG="-strip=$(LLVM_STRIP)" \
		BPF_CFLAGS="$(DAE_CFLAGS)" \
		BPF_TARGET="bpfel,bpfeb" \
		BPF_TRACE_TARGET="$(GO_ARCH)" ; \
		cd "$(PKG_BUILD_DIR)" ; \
		go mod edit -replace=github.com/daeuniverse/outbound="$(OUTBOUND_DIR)" ; \
		go generate "$(PKG_BUILD_DIR)/control/control.go" ; \
		go generate "$(PKG_BUILD_DIR)/trace/trace.go" ; \
		$(call GoPackage/Build/Compile) ; \
	)
endef

define Package/dae/install
	$(call GoPackage/Package/Install/Bin,$(1))

	$(INSTALL_DIR) $(1)/etc/dae/
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/example.dae $(1)/etc/dae/
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/example.dae $(1)/etc/dae/config.dae

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/files/dae.config $(1)/etc/config/dae

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/dae.init $(1)/etc/init.d/dae
endef

define Package/dae-geoip/install
	$(INSTALL_DIR) $(1)/usr/share/dae
	$(LN) ../v2ray/geoip.dat $(1)/usr/share/dae/geoip.dat
endef

define Package/dae-geosite/install
	$(INSTALL_DIR) $(1)/usr/share/dae
	$(LN) ../v2ray/geosite.dat $(1)/usr/share/dae/geosite.dat
endef

$(eval $(call GoBinPackage,dae))
$(eval $(call BuildPackage,dae))
$(eval $(call BuildPackage,dae-geoip))
$(eval $(call BuildPackage,dae-geosite))
