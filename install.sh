#!/bin/sh
# install.sh — install the AgentScript compiler, `ags`.
#
#   curl -fsSL https://raw.githubusercontent.com/rmoralesthompson/agentscript/main/install.sh | sh
#
# Environment:
#   AGS_VERSION      version to install, without a leading "v" (default: the latest release)
#   AGS_INSTALL_DIR  where to put the binary (default: $HOME/.local/bin)
#
# It downloads one prebuilt binary and the release's SHA256SUMS manifest,
# VERIFIES the binary against it, and refuses to install if that check fails.
# It never uses sudo and never writes outside AGS_INSTALL_DIR.
#
# Note for macOS: a binary fetched with curl is not flagged with
# com.apple.quarantine (browsers set that attribute; curl does not), so this
# path does not hit Gatekeeper's "unidentified developer" prompt. These builds
# are not notarized — a browser download still will.
#
# EVERYTHING is defined inside main() and called on the last line. `curl | sh`
# executes bytes as they arrive, so a connection dropped mid-transfer would
# otherwise run half a script; written this way, a truncated download runs
# nothing at all.

set -eu

REPO="rmoralesthompson/agentscript"

main() {
	need curl

	os="$(detect_os)"
	arch="$(detect_arch)"
	version="${AGS_VERSION:-$(resolve_latest)}"
	version="${version#v}"
	dir="${AGS_INSTALL_DIR:-$HOME/.local/bin}"

	asset="ags-${version}-${os}-${arch}"
	base="https://github.com/${REPO}/releases/download/v${version}"

	say "installing ags ${version} (${os}/${arch})"

	tmp="$(mktemp -d)" || die "could not create a temporary directory"
	# shellcheck disable=SC2064
	trap "rm -rf '$tmp'" EXIT INT TERM

	fetch "${base}/${asset}"     "${tmp}/${asset}"   || die "no such asset: ${asset}
  That platform may not be published for v${version}. See
  https://github.com/${REPO}/releases/tag/v${version}"
	fetch "${base}/SHA256SUMS"   "${tmp}/SHA256SUMS" || die "could not download SHA256SUMS for v${version}"

	verify "$tmp" "$asset"

	mkdir -p "$dir" || die "could not create ${dir}"
	# Install to a temp name in the target dir, then rename: a rename within one
	# filesystem is atomic, so a running `ags` is never a half-written file.
	cp "${tmp}/${asset}" "${dir}/.ags.new" || die "could not write to ${dir}"
	chmod 0755 "${dir}/.ags.new"
	mv -f "${dir}/.ags.new" "${dir}/ags" || die "could not install into ${dir}"

	say "installed -> ${dir}/ags"
	"${dir}/ags" version 2>/dev/null | head -1 || true
	check_path "$dir"
}

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

need() {
	command -v "$1" >/dev/null 2>&1 || die "this script needs '$1' on PATH.
  Install it, or download a binary by hand from
  https://github.com/${REPO}/releases/latest"
}

detect_os() {
	case "$(uname -s)" in
		Darwin) printf 'darwin' ;;
		Linux)  printf 'linux'  ;;
		*)      die "unsupported OS: $(uname -s). Published: macOS and Linux." ;;
	esac
}

detect_arch() {
	case "$(uname -m)" in
		x86_64 | amd64)  printf 'amd64' ;;
		arm64 | aarch64) printf 'arm64' ;;
		*)               die "unsupported architecture: $(uname -m). Published: amd64 and arm64." ;;
	esac
}

# resolve_latest reads the version out of the /releases/latest redirect rather
# than the JSON API: no parsing, and no 60-requests-per-hour anonymous API cap.
resolve_latest() {
	url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest" 2>/dev/null)" \
		|| die "could not reach GitHub to resolve the latest version.
  Set AGS_VERSION=x.y.z to install a specific one."
	case "$url" in
		*/tag/v*) printf '%s' "${url##*/tag/v}" ;;
		*) die "could not determine the latest version (no release published yet?).
  Set AGS_VERSION=x.y.z to install a specific one." ;;
	esac
}

fetch() { curl -fsSL --retry 3 --retry-delay 1 -o "$2" "$1" 2>/dev/null; }

# verify checks the downloaded binary against the release manifest, and exits
# non-zero if it does not match. SHA256SUMS covers every platform's binary, so
# only the line for THIS asset is checked — feeding the whole manifest to -c
# reports the files we did not download as missing, which reads as a failure.
verify() {
	_dir="$1"; _asset="$2"
	# Exact filename match on field 2, not a substring: `grep -F " ags-1.2.3-linux-amd64"`
	# also matches a future `ags-1.2.3-linux-amd64-static` line, and two lines fed to
	# `-c` fail on the file we did not download — reported as a tamper warning.
	_line="$(awk -v a="$_asset" '$2 == a' "${_dir}/SHA256SUMS" || true)"
	[ -n "$_line" ] || die "${_asset} is not listed in SHA256SUMS — refusing to install."

	if command -v sha256sum >/dev/null 2>&1; then
		_check="sha256sum -c -"
	elif command -v shasum >/dev/null 2>&1; then
		_check="shasum -a 256 -c -"
	else
		die "no sha256sum or shasum on PATH — cannot verify the download, refusing to install."
	fi

	( cd "$_dir" && printf '%s\n' "$_line" | $_check >/dev/null 2>&1 ) \
		|| die "CHECKSUM MISMATCH for ${_asset} — refusing to install.
  The download is corrupt or has been tampered with. Do not run it."
	say "checksum ok"
}

check_path() {
	case ":${PATH}:" in
		*":$1:"*) ;;
		*) warn ""
		   warn "note: $1 is not on your PATH. Add it, e.g.:"
		   warn "  echo 'export PATH=\"$1:\$PATH\"' >> ~/.profile" ;;
	esac
}

main "$@"
