EAPI=8

inherit git-r3

DESCRIPTION="Extensible, predictable fetch tool written in Crystal"
HOMEPAGE="https://codeberg.org/Izder456/exfetch"
EGIT_REPO_URI="https://codeberg.org/Izder456/exfetch.git"

LICENSE="ISC"
SLOT="0"
KEYWORDS=""
IUSE="static mt"

DEPEND="
	dev-lang/crystal
	dev-util/shards
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

src_configure() {
	myemakeargs=()

	use static && myemakeargs+=( STATIC=on )
	use mt && myemakeargs+=( MULTITHREADED=on )
}

src_compile() {
	emake "${myemakeargs[@]}"
}

src_install() {
	emake DESTDIR="${D}" PREFIX="/usr" install
	dodoc README.md

	if [[ -f docs/exfetch.1 ]]; then
		doman docs/exfetch.1
	fi
}

pkg_postinst() {
	elog "Exfetch installed from live Git HEAD."
	elog "If you want static or multithreaded support:"
	elog "  USE=\"static mt\" emerge -1 exfetch"
}
