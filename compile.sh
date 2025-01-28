#! /bin/sh --
#
# compile.sh: short and portable compile script
# by pts@fazekas.hu at Mon Jan 27 21:55:59 CET 2025
#
# Run it on Linux i386 or amd64: tools/busybox sh compile.sh
#

test "$0" = "${0%/*}" || cd "${0%/*}"
export LC_ALL=C  # For deterministic output. Typically not needed. Is it too late for Perl?
export TZ=GMT  # For deterministic output. Typically not needed. Perl respects it immediately.
if test "$1" != --sh-script; then export OPATH="$PATH" export PATH=/dev/null/missing; exec tools/busybox sh "${0##*/}" --sh-script "$@"; exit 1; fi
shift
test "$ZSH_VERSION" && set -y 2>/dev/null  # SH_WORD_SPLIT for zsh(1). It's an invalid option in bash(1), and it's harmful (prevents echo) in ash(1).
set -ex

nasm=tools/nasm-0.98.39.upx
#perl=tools/miniperl-5.004.04.upx  # Unused here.
wlink=tools/wlink-ow2023-03-04.upx
wlink=tools/wlink-ow1.8.upx
unset INCLUDE WATCOM WLINK WLINK_LNK LIB LIBDIR  # To prevent wlink(1) from searching in other directories.

if ! test -f apack.exe; then
  if ! test -f apack-1.00.zip; then
    # Try to find the non-BusyBox wget(1) on PATH.
    wget="$(set +ex; IFS=: ; for dir in ${OPATH:-$PATH}; do p="$dir/wget" && test -f "$p" && test -x "$p" && printf '%s' "$p" && break; done; :)"
    wget_flags="-nv -O"
    if test -z "$wget"; then  # If wget(1) not found, try curl(1).
      wget="$(set +ex; IFS=: ; for dir in ${OPATH:-$PATH}; do p="$dir/curl" && test -f "$p" && test -x "$p" && printf '%s' "$p" && break; done; :)"
      wget_flags=-sSLfo
    fi
    "$wget" $wget_flags apack-1.00.zip.tmp https://web.archive.org/web/20240424153415/https://ibsensoftware.com/files/apack-1.00.zip
    mv apack-1.00.zip.tmp apack-1.00.zip
  fi
  test "$(sha256sum apack-1.00.zip)" = "9210882561bc4e159b9f811171ac15418a6c765b8d87bc969139de9c328acdd5  apack-1.00.zip"
  unzip apack-1.00.zip apack.exe
fi

test "$(sha256sum apack.exe)" = "c26f95ef305399bcd9ba659cc5e6ff65bf17dedc360aa80a94b4084a30f9de60  apack.exe"

"$nasm" -O0 -w+orphan-labels -f bin -o decimg decimg.nasm
chmod +x decimg
./decimg  # This works only on Linux i386 and amd64 systems. Input file: apack.exe; output file: apack.re32.

"$nasm" -O0 -w+orphan-labels -f bin -DT_LI3 -o apack1p apack1p.nasm  # Additional input file: apack.re32.
chmod +x apack1p

# Correct output by wlink-ow1.8 and later, incorrect output by wlink-ow1.7 and wlink-ow1.4.
"$nasm" -O0 -w+orphan-labels -f obj -DT_WIN32 -o apack1p.obj  apack1p.nasm # Additional input file: apack.re32.
"$wlink" op q op start=_start op noext op nou op nored op d form win nt ru con=3.10 op h=4K com h=0 op st=16K com st=16K f apack1p.obj n apack1pwl.exe >wlink.err 2>&1 || echo "exit code: $?" >>wlink.err
cat wlink.err >&2
! test -s wlink.err || exit 1
"$nasm" -O0 -w+orphan-labels -f bin -DINFN="'apack1pwl.exe'" -o apack1p.exe fixpe.nasm

# Correct output by wlink-ow1.4 and later (possibly also earlier).
"$nasm" -O0 -w+orphan-labels -f obj -DT_DOS32 -o apack1pd.obj apack1p.nasm  # Additional input file: apack.re32.
"$wlink" op q op noext op nou op nored op d form os2 le op stub=pmodew133.exe op h=1 op st=16K l apackdos f apack1pd.obj n apack1pdl.exe >wlink.err 2>&1 || echo "exit code: $?" >>wlink.err
cat wlink.err >&2
! test -s wlink.err || exit 1
"$nasm" -O0 -w+orphan-labels -f bin -DINFN="'apack1pdl.exe'" -o apack1pd.exe fixle.nasm

: "$0" OK.
