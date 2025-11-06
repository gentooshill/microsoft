# Copyright 2025
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Extensible, minimal, predictable fetch tool written in Crystal"
HOMEPAGE="https://codeberg.org/Izder456/exfetch"
SRC_URI="https://codeberg.org/Izder456/exfetch/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="static mt"

# Crystal must be reasonably up-to-date
DEPEND="
	dev-lang/crystal
	dev-util/shards
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

src_configure() {
	# prepare Makefile args
	myemakeargs=()

	use static && myemakeargs+=( STATIC=on )
	use mt     && myemakeargs+=( MULTITHREADED=on )
}

src_compile() {
	emake "${myemakeargs[@]}"
}

src_install() {
	emake DESTDIR="${D}" PREFIX="/usr" install

	# upstream ships docs + examples
	dodoc README.md

	# if there is a man page shipped:
	if [[ -f docs/exfetch.1 ]]; then
		doman docs/exfetch.1
	fi
}

pkg_postinst() {
	elog "Exfetch installed. Remember: no auto-detection magic."
	elog "If you want static or multithreaded behaviour, enable USE flags:"
	elog "  USE=\"static mt\" emerge -1 sys-apps/exfetch"
}
