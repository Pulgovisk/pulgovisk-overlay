# Copyright 2017 Pulgovisk
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit toolchain-funcs flag-o-matic

DESCRIPTION="A UNIX init scheme with service supervision"
HOMEPAGE="http://smarden.org/runit/"
SRC_URI="http://smarden.org/runit/${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
IUSE="static"

S=${WORKDIR}/admin/${P}/src

src_prepare() {
	default

	# we either build everything or nothing static
	sed -i -e 's:-static: :' Makefile

	# see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=726008
	[[ ${COMPILER} == "diet" ]] &&
		use ppc &&
		filter-flags "-mpowerpc-gpopt"
}

src_configure() {
	use static && append-ldflags -static

	echo "$(tc-getCC) ${CFLAGS}"  > conf-cc
	echo "$(tc-getCC) ${LDFLAGS}" > conf-ld
}

src_install() {
	into /
	dobin $(<../package/commands)
	dodir /sbin
	mv "${ED}"/bin/{runit-init,runit,utmpset} "${ED}"/sbin/ || die "dosbin"
	dosym ../etc/runit/2 /sbin/runsvdir-start

	DOCS=( ../package/{CHANGES,README,THANKS,TODO} )
	HTML_DOCS=( ../doc/*.html )
	einstalldocs
	doman ../man/*.[18]

	dodir /etc/runit
	exeinto /etc/runit
	doexe "${FILESDIR}"/ctrlaltdel
	doexe "${FILESDIR}"/1
	doexe "${FILESDIR}"/2
	doexe "${FILESDIR}"/3

	dodir /etc/sv
	for tty in tty1 tty2 tty3 tty4 tty5 tty6; do
		exeinto /etc/sv/getty-$tty/
		newexe "${FILESDIR}"/finish.getty finish
		newexe "${FILESDIR}"/run.getty run
		for script in finish run; do
			sed -i -e "s:TTY:${tty}:g" "${ED}"/etc/sv/getty-$tty/$script
		done
	done

	# make sv command work
	cat <<-EOF > "${T}"/env.d
		#/etc/env.d/20runit
		SVDIR="/etc/service/"
	EOF
	insinto /etc/env.d
	newins "${T}"/env.d 20runit
}

default_config() {
	local sv="${EROOT}"etc/sv
	local service="${EROOT}"etc/service

	mkdir -p "${service}" || die
	for x in tty1 tty2 tty3 tty4 tty5 tty6; do
		ln -sf "${sv}"/getty-$x "${service}" || die
	done
	einfo "The links to services runit will supervise are installed"
	einfo "in $service."
	einfo "If you need multiple runlevels, please see the documentation"
	einfo "for how to set them up."
	einfo
}

pkg_postinst() {
	if [[ -z $REPLACING_VERSIONS ]]; then
		default_config
	fi

	ewarn "To make sure sv works correctly in your currently open"
	ewarn "shells, please run the following command:"
	ewarn
	ewarn "source /etc/profile"
	ewarn
	ewarn "This package dont provide the boot-scripts"
	ewarn "For default boot-scritps, you can install sys-boot/pulgovisk-boot-scripts"

	if [ -L "${EROOT}"var/service ]; then
		ewarn "Once this version of runit is active, please remove the"
		ewarn "compatibility symbolic link at ${EROOT}var/service"
		ewarn "The correct path now is ${EROOT}etc/service"
		ewarn
	fi

	if [ -L "${EROOT}"etc/runit/runsvdir/all ]; then
		ewarn "${EROOT}etc/runit/runsvdir/all has moved to"
		iewarn "${EROOT}etc/sv."
		ewarn "Any symbolic links under ${EROOT}etc/runit/runsvdir"
		ewarn "which point to services through ../all should be updated to"
		ewarn "point to them through ${EROOT}etc/sv."
		ewarn "Once that is done, ${EROOT}etc/runit/runsvdir/all should be"
		ewarn "removed."
		ewarn
	fi
}
