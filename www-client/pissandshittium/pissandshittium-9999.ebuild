# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
PYTHON_REQ_USE="xml(+)"

CHROMIUM_LANGS="
	af am ar bg bn ca cs da de el en-GB es es-419 et fa fi fil fr gu he hi
	hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr
	sv sw ta te th tr uk ur vi zh-CN zh-TW
"

inherit check-reqs chromium-2 desktop flag-o-matic ninja-utils pax-utils
inherit python-any-r1 readme.gentoo-r1 toolchain-funcs xdg-utils

DESCRIPTION="Pissandshittium - A Chromium fork focused on privacy"
HOMEPAGE="https://github.com/Pissandshittium/pissandshittium"

# Use depot_tools fetch method for live ebuild
if [[ ${PV} == 9999 ]]; then
	EGIT_REPO_URI="https://github.com/Pissandshittium/pissandshittium.git"
	EGIT_BRANCH="main"
	inherit git-r3
	S="${WORKDIR}/${P}"
else
	# For release versions, use git tags
	SRC_URI="https://github.com/Pissandshittium/pissandshittium/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm64"
	S="${WORKDIR}/pissandshittium-${PV}"
fi

LICENSE="BSD"
SLOT="0"
IUSE="
	+component-build cups debug gtk4 +hangouts headless kerberos libcxx
	+official pax-kernel pgo +proprietary-codecs pulseaudio qt5 qt6 screencast
	selinux +system-toolchain +vaapi +wayland +widevine +X
"

REQUIRED_USE="
	component-build? ( !official )
	pgo? ( official )
	qt5? ( !qt6 )
"

RESTRICT="
	!system-toolchain? ( strip )
	pgo? ( network-sandbox )
"

COMMON_DEPEND="
	app-arch/bzip2:=
	cups? ( >=net-print/cups-1.7.0:= )
	dev-libs/expat:=
	dev-libs/glib:2
	dev-libs/libxml2:=[icu]
	dev-libs/libxslt:=
	dev-libs/nspr:=
	>=dev-libs/nss-3.26:=
	>=dev-libs/re2-0.2019.08.01:=
	>=media-libs/alsa-lib-1.0.19:=
	media-libs/flac:=
	media-libs/fontconfig:=
	media-libs/freetype:=
	>=media-libs/harfbuzz-3.0.0:=[icu(-)]
	media-libs/libjpeg-turbo:=
	media-libs/libpng:=
	media-libs/libwebp:=
	media-libs/opus:=
	pulseaudio? ( media-libs/libpulse:= )
	sys-apps/dbus:=
	sys-apps/pciutils:=
	>=sys-libs/zlib-1.2.11:=[minizip]
	x11-libs/cairo:=
	x11-libs/gdk-pixbuf:2
	x11-libs/libdrm:=
	x11-libs/libxkbcommon:=
	x11-libs/libxshmfence:=
	x11-libs/pango:=
	kerberos? ( virtual/krb5 )
	!headless? (
		dev-libs/glib:2
		>=media-libs/alsa-lib-1.0.19:=
		pulseaudio? ( media-libs/libpulse:= )
		sys-apps/dbus:=
		x11-libs/cairo:=
		x11-libs/gdk-pixbuf:2
		x11-libs/pango:=
		x11-libs/libX11:=
		x11-libs/libXcomposite:=
		x11-libs/libXcursor:=
		x11-libs/libXdamage:=
		x11-libs/libXext:=
		x11-libs/libXfixes:=
		x11-libs/libXi:=
		x11-libs/libXrandr:=
		x11-libs/libXrender:=
		x11-libs/libXtst:=
		x11-libs/libxcb:=
		gtk4? ( gui-libs/gtk:4[X,wayland?] )
		!gtk4? ( x11-libs/gtk+:3[X,wayland?] )
		qt5? (
			dev-qt/qtcore:5
			dev-qt/qtwidgets:5
		)
		qt6? (
			dev-qt/qtbase:6[gui,widgets]
		)
		wayland? (
			dev-libs/wayland:=
			screencast? ( media-video/pipewire:= )
		)
	)
	vaapi? (
		>=media-libs/libva-2.7:=[X?,wayland?]
		x11-libs/libX11
		x11-libs/libXext
	)
"

RDEPEND="
	${COMMON_DEPEND}
	x11-misc/xdg-utils
	virtual/opengl
	virtual/ttf-fonts
	selinux? ( sec-policy/selinux-chromium )
"

DEPEND="
	${COMMON_DEPEND}
"

BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/setuptools[${PYTHON_USEDEP}]
	')
	>=app-arch/gzip-1.7
	dev-lang/perl
	>=dev-util/gn-0.2131
	>=dev-util/gperf-3.0.3
	dev-util/ninja
	>=net-libs/nodejs-20.11[inspector]
	>=sys-devel/bison-2.4.3
	sys-devel/clang:=
	sys-devel/flex
	>=sys-devel/lld-17
	virtual/pkgconfig
"

if [[ ${PV} == 9999 ]]; then
	BDEPEND+="
		dev-vcs/git
	"
fi

# Based on Chromium build requirements from build_instructions.md
# Set defaults outside of functions
pre_build_checks() {
	if has component-build ${IUSE} && use component-build; then
		CHECKREQS_DISK_BUILD="10G"
	else
		CHECKREQS_DISK_BUILD="12G"
	fi
	CHECKREQS_DISK_USR="500M"
}

python_check_deps() {
	python_has_version "dev-python/setuptools[${PYTHON_USEDEP}]"
}

needs_clang() {
	[[ ${CHOST} == armv7a* ]] || use libcxx || tc-is-clang
}

pkg_pretend() {
	pre_build_checks
	check-reqs_pkg_pretend

	if use headless; then
		local headless_unused_flags=("cups" "kerberos" "pulseaudio" "qt5" "qt6" "vaapi" "wayland")
		for myiuse in "${headless_unused_flags[@]}"; do
			use ${myiuse} && ewarn "Ignoring USE=${myiuse} since USE=headless is set."
		done
	fi

	if use pgo && [[ ! -d /var/cache/pgo-chromium ]]; then
		eerror "PGO data not found. Please run 'pgo-chromium' first."
		die "Missing PGO data"
	fi
}

pkg_setup() {
	pre_build_checks
	check-reqs_pkg_setup

	chromium_suid_sandbox_check_kernel_config

	python-any-r1_pkg_setup
}

src_unpack() {
	if [[ ${PV} == 9999 ]]; then
		git-r3_src_unpack
	else
		default
	fi
}

src_prepare() {
	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	default

	# Create symlink to system nodejs
	mkdir -p third_party/node/linux/node-linux-x64/bin || die
	ln -s "${EPREFIX}"/usr/bin/node third_party/node/linux/node-linux-x64/bin/node || die

	# Adjust python scripts to use python3
	sed -i -e 's|\(^#!.*python\)$|\13|' $(find . -name '*.py') || die

	# Keep required third-party libraries (standard Chromium practice)
	local keeplibs=(
		base/third_party/cityhash
		base/third_party/double_conversion
		base/third_party/dynamic_annotations
		base/third_party/icu
		base/third_party/nspr
		base/third_party/superfasthash
		base/third_party/symbolize
		base/third_party/valgrind
		base/third_party/xdg_mime
		base/third_party/xdg_user_dirs
		buildtools/third_party/libc++
		buildtools/third_party/libc++abi
		chrome/third_party/mozilla_security_manager
		courgette/third_party
		net/third_party/mozilla_security_manager
		net/third_party/nss
		net/third_party/quic
		net/third_party/uri_template
		third_party/abseil-cpp
		third_party/angle
		third_party/angle/src/common/third_party/xxhash
		third_party/angle/src/third_party/ceval
		third_party/angle/src/third_party/libXNVCtrl
		third_party/angle/src/third_party/volk
		third_party/anonymous_tokens
		third_party/apple_apsl
		third_party/axe-core
		third_party/blink
		third_party/bidimapper
		third_party/boringssl
		third_party/boringssl/src/third_party/fiat
		third_party/breakpad
		third_party/breakpad/breakpad/src/third_party/curl
		third_party/brotli
		third_party/catapult
		third_party/ced
		third_party/cld_3
		third_party/content_analysis_sdk
		third_party/cpuinfo
		third_party/crashpad
		third_party/crc32c
		third_party/cros_system_api
		third_party/dav1d
		third_party/dawn
		third_party/depot_tools
		third_party/devscripts
		third_party/devtools-frontend
		third_party/distributed_point_functions
		third_party/dom_distiller_js
		third_party/eigen3
		third_party/emoji-segmenter
		third_party/farmhash
		third_party/fdlibm
		third_party/fft2d
		third_party/flatbuffers
		third_party/fp16
		third_party/freetype
		third_party/fusejs
		third_party/fxdiv
		third_party/highway
		third_party/liburlpattern
		third_party/libzip
		third_party/lit
		third_party/gemmlowp
		third_party/google_input_tools
		third_party/googletest
		third_party/harfbuzz-ng
		third_party/hunspell
		third_party/iccjpeg
		third_party/inspector_protocol
		third_party/ipcz
		third_party/jinja2
		third_party/jsoncpp
		third_party/jstemplate
		third_party/khronos
		third_party/leveldatabase
		third_party/libaddressinput
		third_party/libaom
		third_party/libavif
		third_party/nearby
		third_party/libjxl
		third_party/libphonenumber
		third_party/libsecret
		third_party/libsrtp
		third_party/libsync
		third_party/libudev
		third_party/libva_protected_content
		third_party/libvpx
		third_party/libwebm
		third_party/libx11
		third_party/libxcb-keysyms
		third_party/libxml/chromium
		third_party/libyuv
		third_party/lottie
		third_party/lss
		third_party/lzma_sdk
		third_party/mako
		third_party/maldoca
		third_party/markupsafe
		third_party/material_color_utilities
		third_party/mesa_headers
		third_party/metrics_proto
		third_party/minigbm
		third_party/modp_b64
		third_party/nasm
		third_party/neon_2_sse
		third_party/node
		third_party/one_euro_filter
		third_party/openscreen
		third_party/opus
		third_party/ots
		third_party/pdfium
		third_party/perfetto
		third_party/pffft
		third_party/ply
		third_party/polymer
		third_party/private-join-and-compute
		third_party/private_membership
		third_party/protobuf
		third_party/pthreadpool
		third_party/puffin
		third_party/pyjson5
		third_party/pyyaml
		third_party/qcms
		third_party/rnnoise
		third_party/rust
		third_party/s2cellid
		third_party/securemessage
		third_party/selenium-atoms
		third_party/shell-encryption
		third_party/simplejson
		third_party/skia
		third_party/smhasher
		third_party/snappy
		third_party/sqlite
		third_party/swiftshader
		third_party/tcmalloc
		third_party/tensorflow-text
		third_party/tflite
		third_party/ruy
		third_party/six
		third_party/ukey2
		third_party/unrar
		third_party/utf
		third_party/vulkan
		third_party/wayland
		third_party/webdriver
		third_party/webgpu-cts
		third_party/webrtc
		third_party/widevine
		third_party/woff2
		third_party/wuffs
		third_party/x11proto
		third_party/xcbproto
		third_party/xnnpack
		third_party/zxcvbn-cpp
		third_party/zlib/google
		url/third_party/mozilla
		v8/src/third_party/siphash
		v8/src/third_party/valgrind
		v8/src/third_party/utf8-decoder
		v8/third_party/glibc
		v8/third_party/inspector_protocol
		v8/third_party/v8
	)

	# Remove most bundled libraries per Chromium instructions
	python_setup
	einfo "Removing bundled libraries..."
	build/linux/unbundle/remove_bundled_libraries.py "${keeplibs[@]}" --do-remove || die

	eapply_user
}

src_configure() {
	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	local myconf_gn=""

	# Make sure the build system will use the right tools
	tc-export AR CC CXX NM

	if needs_clang && ! tc-is-clang; then
		einfo "Enforcing the use of clang due to USE=libcxx or ARM"
		CC=${CHOST}-clang
		CXX=${CHOST}-clang++
		strip-unsupported-flags
	elif ! use system-toolchain && ! tc-is-clang ; then
		CC=${CHOST}-clang
		CXX=${CHOST}-clang++
		strip-unsupported-flags
	fi

	if tc-is-clang; then
		myconf_gn+=" is_clang=true clang_use_chrome_plugins=false"
	else
		myconf_gn+=" is_clang=false"
	fi

	# Define a custom toolchain for GN
	myconf_gn+=" custom_toolchain=\"//build/toolchain/linux/unbundle:default\""

	if tc-is-cross-compiler; then
		tc-export BUILD_{AR,CC,CXX,NM}
		myconf_gn+=" host_toolchain=\"//build/toolchain/linux/unbundle:host\""
		myconf_gn+=" v8_snapshot_toolchain=\"//build/toolchain/linux/unbundle:host\""
	else
		myconf_gn+=" host_toolchain=\"//build/toolchain/linux/unbundle:default\""
	fi

	# GN needs explicit config for Debug/Release
	myconf_gn+=" is_debug=$(usex debug true false)"

	# Component build
	myconf_gn+=" is_component_build=$(usex component-build true false)"

	# Disable nacl (per Chromium build instructions)
	myconf_gn+=" enable_nacl=false"

	# Use system-provided libraries
	local gn_system_libraries=(
		flac
		fontconfig
		freetype
		harfbuzz-ng
		libdrm
		libjpeg
		libpng
		libwebp
		libxml
		libxslt
		opus
		re2
		snappy
		zlib
	)
	if use system-toolchain; then
		gn_system_libraries+=(
			libvpx
		)
	fi
	build/linux/unbundle/replace_gn_files.py --system-libraries "${gn_system_libraries[@]}" || die

	# Optional dependencies
	myconf_gn+=" use_cups=$(usex cups true false)"
	myconf_gn+=" use_kerberos=$(usex kerberos true false)"
	myconf_gn+=" use_pulseaudio=$(usex pulseaudio true false)"
	myconf_gn+=" use_vaapi=$(usex vaapi true false)"
	myconf_gn+=" rtc_use_pipewire=$(usex screencast true false)"

	# Proprietary codecs
	myconf_gn+=" proprietary_codecs=$(usex proprietary-codecs true false)"
	myconf_gn+=" ffmpeg_branding=\"$(usex proprietary-codecs Chrome Chromium)\""

	# Widevine
	myconf_gn+=" enable_widevine=$(usex widevine true false)"

	# Hangouts
	myconf_gn+=" enable_hangout_services_extension=$(usex hangouts true false)"

	# Target CPU architecture
	local myarch="$(tc-arch)"
	if [[ $myarch = amd64 ]] ; then
		myconf_gn+=" target_cpu=\"x64\""
		ffmpeg_target_arch=x64
	elif [[ $myarch = x86 ]] ; then
		myconf_gn+=" target_cpu=\"x86\""
		ffmpeg_target_arch=ia32
	elif [[ $myarch = arm64 ]] ; then
		myconf_gn+=" target_cpu=\"arm64\""
		ffmpeg_target_arch=arm64
	elif [[ $myarch = arm ]] ; then
		myconf_gn+=" target_cpu=\"arm\""
		ffmpeg_target_arch=$(usex cpu_flags_arm_neon arm-neon arm)
	else
		die "Failed to determine target arch, got '$myarch'."
	fi

	# Make sure that -Werror doesn't get added to CFLAGS
	myconf_gn+=" treat_warnings_as_errors=false"

	# Disable fatal linker warnings
	myconf_gn+=" fatal_linker_warnings=false"

	# Bug 491582
	export TMPDIR="${WORKDIR}/temp"
	mkdir -p -m 755 "${TMPDIR}" || die

	# https://bugs.gentoo.org/654216
	addpredict /dev/dri/ #nowarn

	# Disable unknown warning message from clang
	if tc-is-clang; then
		append-flags -Wno-unknown-warning-option
	fi

	# ICU data file
	myconf_gn+=" icu_use_data_file=true"

	# Don't need nocompile checks
	myconf_gn+=" enable_nocompile_tests=false"

	# Enable official build optimizations
	if use official; then
		myconf_gn+=" is_official_build=true"
	else
		myconf_gn+=" is_official_build=false"
		myconf_gn+=" enable_resource_allowlist_generation=false"
		filter-flags '-f*stack-protector*'
	fi

	# Enable PGO
	if use pgo; then
		myconf_gn+=" chrome_pgo_phase=2"
		myconf_gn+=" pgo_data_path=\"/var/cache/pgo-chromium/chrome.profdata\""
	fi

	# Use lld linker
	myconf_gn+=" use_lld=true"

	# Control usage of C++ standard library
	if use libcxx; then
		myconf_gn+=" use_custom_libcxx=true"
	fi

	# Disable cfi for non-official builds
	if ! use official; then
		myconf_gn+=" is_cfi=false"
	fi

	# Headless mode
	if use headless; then
		myconf_gn+=" use_ozone=true ozone_auto_platforms=false"
		myconf_gn+=" ozone_platform=\"headless\""
		myconf_gn+=" ozone_platform_headless=true"
	else
		myconf_gn+=" use_ozone=true ozone_auto_platforms=false"
		myconf_gn+=" ozone_platform_headless=true"
		myconf_gn+=" ozone_platform_x11=true"
		if use wayland; then
			myconf_gn+=" ozone_platform_wayland=true"
			myconf_gn+=" ozone_platform=\"wayland\""
		else
			myconf_gn+=" ozone_platform_wayland=false"
			myconf_gn+=" ozone_platform=\"x11\""
		fi
	fi

	# ThinLTO optimizations
	if use pgo; then
		myconf_gn+=" thin_lto_enable_optimizations=true"
	else
		myconf_gn+=" thin_lto_enable_optimizations=false"
	fi

	# Disable Google API keys for privacy
	# Users can set their own via EXTRA_GN if needed
	myconf_gn+=" google_api_key=\"\""
	myconf_gn+=" google_default_client_id=\"\""
	myconf_gn+=" google_default_client_secret=\"\""

	einfo "Configuring Pissandshittium with GN..."
	set -- gn gen --args="${myconf_gn} ${EXTRA_GN}" out/Release
	echo "$@"
	"$@" || die "GN configuration failed"
}

src_compile() {
	# Build chrome target per build_instructions.md
	eninja -C out/Release chrome chrome_sandbox chromedriver
}

src_install() {
	local CHROMIUM_HOME="/usr/$(get_libdir)/pissandshittium"
	exeinto "${CHROMIUM_HOME}"

	doexe out/Release/chrome
	doexe out/Release/chrome_sandbox
	doexe out/Release/chrome_crashpad_handler

	newexe out/Release/chrome pissandshittium

	# Install chromedriver
	doexe out/Release/chromedriver
	dosym "${CHROMIUM_HOME}/chromedriver" /usr/bin/pissandshittium-chromedriver

	# Install necessary files
	insinto "${CHROMIUM_HOME}"
	doins out/Release/*.pak
	doins out/Release/*.bin

	# Install locales
	insinto "${CHROMIUM_HOME}/locales"
	doins out/Release/locales/*.pak

	# Install resources
	insinto "${CHROMIUM_HOME}"
	doins -r out/Release/resources

	# Install libEGL, libGLESv2
	doexe out/Release/libEGL.so
	doexe out/Release/libGLESv2.so
	doexe out/Release/libvk_swiftshader.so
	doexe out/Release/libvulkan.so*

	# Install vk_swiftshader_icd.json
	insinto "${CHROMIUM_HOME}"
	doins out/Release/vk_swiftshader_icd.json

	# Install ANGLE libraries
	if [[ -f out/Release/libEGL.so ]]; then
		doexe out/Release/libEGL.so
	fi
	if [[ -f out/Release/libGLESv2.so ]]; then
		doexe out/Release/libGLESv2.so
	fi

	# Sandbox
	fperms 4755 "${CHROMIUM_HOME}/chrome_sandbox"

	# Install icons
	local size
	for size in 16 24 32 48 64 128 256 ; do
		newicon -s ${size} "chrome/app/theme/chromium/product_logo_${size}.png" pissandshittium.png
	done

	# Install desktop file
	make_desktop_entry pissandshittium "Pissandshittium" pissandshittium \
		"Network;WebBrowser" \
		"MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;x-scheme-handler/http;x-scheme-handler/https;"

	# Install wrapper script
	cat > "${T}/pissandshittium" <<-_EOF_ || die
		#!/bin/sh
		exec "${CHROMIUM_HOME}/chrome" "\$@"
	_EOF_
	dobin "${T}/pissandshittium"

	# Install man page (using chromium's)
	if [[ -f out/Release/chrome.1 ]]; then
		newman out/Release/chrome.1 pissandshittium.1
	fi
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update

	elog "Pissandshittium has been installed."
	elog "You can run it by typing: pissandshittium"
	elog
	elog "To get the most out of Pissandshittium, install additional codecs"
	elog "and enable hardware acceleration. See:"
	elog "  https://wiki.gentoo.org/wiki/Chromium"
}
