#! /bin/sh --
# by pts@fazekas.hu at Sat Jan 25 00:54:21 CET 2025
set -ex
test "$0" = "${0%/*}" || cd "${0%/*}"
export LC_ALL=C  # For deterministic output. Typically not needed. Is it too late for Perl?
export TZ=GMT  # For deterministic output. Typically not needed. Perl respects it immediately.
unset INCLUDE WATCOM WLINK WLINK_LNK LIB LIBDIR  # To prevent wlink(1) from searching in other directories.

nasm=tools/nasm-0.98.39.upx
perl=tools/miniperl-5.004.04.upx
wlink=tools/wlink-ow1.8.upx
elfxfix=tools/elfxfix

test "$(sha256sum apack.exe)" = "c26f95ef305399bcd9ba659cc5e6ff65bf17dedc360aa80a94b4084a30f9de60  apack.exe"

"$nasm" -O0 -w+orphan-labels -f bin -o decimg decimg.nasm
chmod +x decimg
./decimg  # This works only on Linux i386 and amd64 systems. Input file: apack.exe; output file: apack.re32.
test -f apack2ida.lst || : >>apack2ida.lst  # It works even without symbols.
"$perl" -x gensyms_apack.pl  # Generates apack.syms. Not running it here, because we don't have its input file apack2ida.lst.
"$perl" -x re2nasm.pl apack.re32 apack.syms apackr.nasm
"$nasm" -O0 -w+orphan-labels -f elf -o apackr.o apackr.nasm
"$nasm" -O0 -w+orphan-labels -f obj -o apackr.obj apackr.nasm
strings apackr.o >apack.strings
ld -m elf_i386 -static -nostdlib --fatal-warnings -N -q --section-start=.text=0x700000 -o apackr2 apackr.o  # Better for IDA. IDA doesn't like object files.

"$nasm" -O0 -w+orphan-labels -f obj -DT_WIN32 -o apack1p.obj  apack1p.nasm  # Additional input file: apack.re32.
"$nasm" -O0 -w+orphan-labels -f obj -DT_DOS32 -o apack1pd.obj apack1p.nasm  # Additional input file: apack.re32.
"$nasm" -O0 -w+orphan-labels -f elf -DT_LI3 -o apack1p.o apack1p.nasm       # Additional input file: apack.re32.
"$nasm" -O0 -w+orphan-labels -f bin -DT_LI3 -o apack1p apack1p.nasm         # Additional input file: apack.re32.

chmod +x apack1p

# Correct output by wlink-ow1.8 and later, incorrect output by wlink-ow1.7 and wlink-ow1.4.
# wlink only displays a warning on duplicate symbols. The only way to check for this es checking stderr.
#owcc -bwin32 -Wl,runtime -Wl,console=3.10 -Wl,library -Wl,clib3r -fd=t.lnk -W -Wall -Wextra -Werror -march=i386 -fno-stack-check -Os -s -o apack1p.exe apack1p.obj >wlink.err 2>&1 || echo "exit code: $?" >>wlink.err
# wlink doesn't seem to use the exported $LIB by default, but yes link this LIB=tools wlink libpath "'%LIB%'"
# wlink would set the heaps reserve size to 0 even with `op h=4K'; that's fine
"$wlink" op q op start=_start op noext op nou op nored op d form win nt ru con=3.10 op h=4K com h=0 op st=16K com st=16K f apack1p.obj n apack1pwl.exe >wlink.err 2>&1 || echo "exit code: $?" >>wlink.err
cat wlink.err >&2
! test -s wlink.err || exit 1
"$nasm" -O0 -w+orphan-labels -f bin -DINFN="'apack1pwl.exe'" -o apack1p.exe fixpe.nasm

# Correct output by wlink-ow1.4 and later (possibly also earlier).
# owcc -bpmodew -Wl,op -Wl,stub=pmodew133.exe -Wl,library -Wl,clib3r -fd=t.lnk -W -Wall -Wextra -Werror -march=i386 -fno-stack-check -Os -s -o apack1pd.exe apack1pd.obj >wlink.err 2>&1 || echo "exit code: $?" >>wlink.err
# !! apackdos.lib was created using OpenWatcom v2 (2023-03-04) from https://github.com/open-watcom/open-watcom-v2
#    extract the libc: $ binl/wlib -x lib386/dos/clib3r.lib
#    without the I/O: $ binl/wlib -q -c -fo -s -t -zld -n apackdos.lib +cstart.o +cmain386.o +crwdata.o +argcv.o +___argc.o +dosseg.o +uselfn.o +initrtns.o +initargv.o +cinit.o +sgdef086.o +dpmihost.o +exit.o +nmalloc.o +nfree.o +histsplt.o +mem.o +nmemneed.o +grownear.o +heapen.o +nheapmin.o +nheapunl.o +minreal.o +amblksiz.o +sbrk.o +errno.o
#    full: $ binl/wlib -q -c -fo -s -t -zld -n apackdos.lib +cstart.o +cmain386.o +crwdata.o +argcv.o +___argc.o +dosseg.o +uselfn.o +initrtns.o +initargv.o +cinit.o +sgdef086.o +dpmihost.o +exit.o +nmalloc.o +nfree.o +histsplt.o +mem.o +nmemneed.o +grownear.o +heapen.o +nheapmin.o +nheapunl.o +minreal.o +amblksiz.o +sbrk.o +errno.o +remove.o +unlnk.o +lseek.o +_iflelen.o +filelen.o +read.o +write.o +error386.o +__lseek.o +stk386.o +stack386.o +dosret.o +xmsg.o +enterdb.o +doserrno.o +iomode.o +memset.o +__stos.o +iomodtty.o +isatt.o +renam.o +close.o +_clse.o +open.o +opendos.o +umaskval.o +creatdos.o +stiomode.o +textmode.o +nrealloc.o +nmsize.o +nexpand.o +_expand.o
"$wlink" op q op noext op nou op nored op d form os2 le op stub=pmodew133.exe op h=1 op st=16K l apackdos f apack1pd.obj n apack1pdl.exe >wlink.err 2>&1 || echo "exit code: $?" >>wlink.err
cat wlink.err >&2
! test -s wlink.err || exit 1
"$nasm" -O0 -w+orphan-labels -f bin -DINFN="'apack1pdl.exe'" -o apack1pd.exe fixle.nasm

ld -m elf_i386 -static -nostdlib --fatal-warnings -N -q --section-start=.text=0x700054 -o apack1pd apack1p.o
# -s would be sstrip. we need -a to fix the alignment in the PD_LOAD header (change it from 4 to 0x1000).
"$elfxfix" -l -a apack1pd
cp -a apack1pd apack1ps
"$elfxfix" -l -a -s apack1ps
cmp apack1ps apack1p  # The output must be the same with or without GNU ld(1).

: "$0" OK.
