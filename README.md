# apack1p: port of aPACK 1.00 to Linux and Windows

apack1p is a binary port of the aPACK 1.00 16-bit DOS .com and .exe
executable compressor (packer) to Linux i386 and amd64 and Win32 (Windows
i386, also runs on amd64). apack1p provides ports of the aPACK executable
program which run on Linux i386 and amd64, Win32 and 32-bit DOS. (The
original aPACK 1.00 runs only on 32-bit DOS.) All of these can compress
16-bit DOS .com and .exe programs, and their output is identical (to each
other and to the original aPACK 1.00) on the same input.

See the program files within the
[releases](https://github.com/pts/apack1b/releases). *apack1b* is the Linux
i386 executable, *apack1b.exe* is the Win32 executable, and *apack1bd.exe*
is the 32-bit DOS executable (using and containing the PMODE/W 1.33 DOS
extender).

aPACK 1.00 is able to compress 16-bit DOS (8086, 186 and 286) .com and .exe
executable programs. The output of aPACK is a compressed executable which
decompresses itself in-memory upon each start. According [to its
author](https://web.archive.org/web/20240424153415/https://ibsensoftware.com/download.html),
*aPACK has ranked as one of the best 16-bit DOS executable packers for
years.* aPACK 1.00 was released as freeware on 2012.11.12a. It creates
smaller (better compressed) executables than the most recent release of
[UPX](https://upx.github.io/) in 2024.

The most important limitation of aPACK is that it can only compress DOS
16-bit .com and .exe executable programs. Use [UPX](https://upx.github.io/)
to get support for more file formats (such as Win32 PE .exe) and
architectures (e.g. 32-bit i386 and 64-bit amd64). The author of aPACK also
was a main contributor to
[32LiTE](https://www.softpedia.com/get/Compression-tools/32LiTE.shtml),
which can compress 32-bit DOS programs.

## How to build it

You can find the prebuilt executable program files within the
[releases](https://github.com/pts/apack1b/releases). *apack1b* is the Linux
i386 executable, *apack1b.exe* is the Win32 executable, and *apack1bd.exe*
is the 32-bit DOS executable (using and containing the PMODE/W 1.33 DOS
extender).

To rebuild these from sources (except for apack.exe, from which binary code
and data is extracted and reused), you need a Linux i386 or amd64 system.
(In the future, maybe a build system will be provided for Win32 as well.)
Emulation (such as WSL2) and containers also work fine. The Linux
distribution doesn't matter, because the build tool programs are provided as
statically linked Linux i386 executables.

apack1p is written in i386 assembly language, NASM dialect. The build is
automated in shell scripts, BusyBox syntax. (Some optional targets are built
using Perl scripts.) The two main tools used the during the build is
[NASM](https://nasm.us/), the Netwide Assembler, and the
*wlink* linker from [OpenWatcom
v2](https://github.com/open-watcom/open-watcom-v2) and BusyBox. A copy of
these build tool programs is provided in the pack1p repostory, there is no
need to install anything manually.

To build apack1p, clone the repository and run compile.sh. More
specifically, run these commands in a Linux i368 or amd64 terminal
(command-line) window (each line without the leading `$`):

```
$ git clone https://github.com/pts/apack1p
$ cd apack1p
$ ./compile.sh
```

This will download
[apack-1.00.zip](https://web.archive.org/web/20240424153415/https://ibsensoftware.com/files/apack-1.00.zip)
containing apack.exe, extract apack.exe and build *apack1b*, *apack1b.exe*
and *apack1bd.exe*.

An alterative way of running compile.sh is `tools/busybox sh compile.sh`.

## How apack1p was built

Porting isn't as easy as compiling the system-independent C sources to the
desired host systems and architectures, because the source code of aPACK is
not available. The original aPACK 1.00 apack.exe is a 32-bit DOS program,
thus it runs in i386, Intel x86 32-bit protected mode. So the plan became
taking the original executble program (including i386 code and data), and
identifying and replacing the system-dependent parts (such as calls to the
file *open(2)*, *read(2)*, *write(2)* and *close(2)*). It was decided that
the first two systems will be Linux i386 (also runs in Docker) and Win32.

Also with this plan it's not possible to build for 16-bit Intel (8086, 186
and 286) systems or 64-bit Intel (amd64) systems (such as macOS) or
non-Intel architectures (such as ARM).

The Linux *file* tool was used to detect the file format, revealing this: LE
executable for MS-DOS, PMODE/W DOS extender, 32LiTE compressed. This hint
that the programming language is C, C++ and/or assembly, and it was compiled
with Watcom or OpenWatcom.

There is no decompressor available for 32LiTE, so as part of the porting the
compression has been reverse engineered. The details are in the file
[apack_32lite.ndisasm.txt](apack_32lite.ndisasm.txt). The reverse
engineering started by running the OpenWatcom v2 *wdump* tool to dump the
file headers, and then running the NASM *ndisasm* disassembler to
disassemble the relevant i386 parts (offsets and lengths reported by
*wdump*). The disassembly contains no symbols or debug info. Then a manual
* look was taken at the raw disassembly, slowly annotating it with comments
* and adding symbols.

The 32LiTE-compressed i386 program image consists of:

* Initial code to make an in-memory copy of the compressed data and the
  decompressor, and jump to the copy.

* The compressed data (.text and .data sections and relocations combined).

* The decompressor code to decompress the compressed data (back to the
  in-memory location of the original compressed data), apply the inverse of
  call filtering, process the relocations, clear the .bss section with NUL
  bytes, and jump to the entry point.

Call filtering is a size-preserving code transformation which makes the
subsequent compression step produce shorter output. In the case of 32LiTE,
the 32-bit offsets in the i386 *call* instructions are converted from
relative to absolute, thus if a function is called from multiple location,
the call offsets will become identical, thus compression will find more
repetitions.

The disassembly has confirmed that general-purpose compression algortihm
used in 32LiTE is
[aPLib](https://web.archive.org/web/20240121055802/http://www.ibsensoftware.com/products_aPLib.html),
by the author of aPACK and 32LiTE. In fact, it's almost identical to
*depack.asm*, the open-source aPLib decompressor for i386. (Get it from file
*src/32bit/depack.asm* within
[aPLib-1.1.1.zip](https://web.archive.org/web/20240424153415/https://ibsensoftware.com/files/aPLib-1.1.1.zip).)
However, the inverse of call filtering and relocation processing are
additional components, which are not open sourced.

Having relocations accompanying the code and the data makes it possible to
load the program to any memory address. The simplest case when a relocation
is useful is when global variable A is a pointer to global variable C or
function F. In the program binary image, the value of A is hardcoded to some
value. But that value is only correct if the program image is loaded to a
specific (correct) memory address determined at compile time. Each
relocation is an offset where pointers need to be patched. In this case, the
relocation is the offset (location) of global variable A (there is no need
for a relocation in B or F). Having and applying this relocation makes the
pointer in A work no matter where the program is loaded into memory. This is
possible, because the pointers relative to the program image base address
are always the same, so by applying the relocation only the base address is
added.

After all this reverse engineering, the uncompressed data (.text and .data
sections and relocations) was dumped to a separate file (*apack.re32*),
converted first a Linux i386 ELF-32 object file using NASM, and that to
Linux i386 ELF-32 statically linked executable program using GNU ld(1). All
these steps are automated in the script
[compile_debug.sh](compile_debug.sh).

The code above to do decompression, inverse filtering and the applying of
relocations was simply reused (they are part of the decompressor code) and
called. They were called twice, each time writing to a different base
address in memory, and the differences (i.e. locations of the differing
bytes) between to two outputs were analyzed to figure out where the
relocations need to be put. This is automated in the
[decimg.nasm](decimg.nasm) program written in NASM for Linux i386.

Please note that the Linux executable doesn't work, because it still
contains its I/O code (e.g. *open(2)*, *read(2)*, *write(2)*, *close(2)*
calls and *malloc(3)* implementation) for 32-bit DOS. So the next step was
discovering the internal structure of the program code and data using IDA
(using its interactive disassembler features). The free edition of IDA is
able to load Linux i386 ELF-32 executable programs, so the output of the
previous step was used here. The discovery took about 20 hours spent in the
graphical user interface of IDA, and its output was an assembly listing file
containing symbols discovered. These symbols identified the boundaries of
the parts of the program, and also all individual functions and most global
variables.

The following parts were identified (with their locations) manually, with
the help of IDA:

* Each program function. Of course we don't know the function name.

* Each C library function (part of the OpenWatcom v2 libc), and also the
  names of these functions. Getting the names was a manual process in which
  the call graph and inputs were analyzed. For example, a short function
  taking a NUL-terminated string containing `%d` as its first argument,
  reading a global variable, delegating the rest of the work to another
  function is likely *printf*, reading the address of *stdout*, and calling
  *vfprintf*. Identifying all this was a manual process relying on
  intuition, but the results could be (and were) confirmed by comparing
  them to the sources of the most recent OpenWatcom v2 libc (and also of
  earlier versions).

* The *main* function. (It is called indirectly by *\_cstart\_*, which is
  the entry point, identified by the entry point address.)

* Global variables (both in .data and .bss) part of the program. This also
  includes constants such as NUL-terminated string literals.

* Global variables part of the C library.

* Padding bytes dictated by the file format (such as aligning some sections
  to 4096 bytes, within the file), which can be removed or shortened.

The listing file created by IDA was used to add the symbols to the assembly
source file *apackr.nasm* autogenerated by a Perl script run from
[compile_debug.sh](compile_debug.sh). Then this file was copied to
[apack1b.nasm](apack1b.nasm), and all further development was by modifying
and extending this file.

Some functionality had to be modified or removed (e.g. removing the DOS *int
10h* calls to change the cursor shape, because this only works on DOS.) All
the libc functions and data have been removed: it was as easy as deleting
the unwanted lines from *apack1p.nasm*. This worked, because the pointers
were already emitted by the Perl script as symbol-relative, so removing some
code and data didn't ruin the addresses and pointers used by other parts.
Also all libc function calls were emitted symbolically, e.g. `call
libcu_printf`. Removing the implementation of these libc functions produced
undefined symbols. Each libc function was written from scratch in i386
assembly, first targeting Linux i386, and once done, separately targeting
Win32.

These were the original OpenWatcom libc functions: *\_cstart\_*,
*printf\_*, *cprintf\_*, *kbhit\_*, *getch\_*,
*close\_*, *exit\_*, *filelength\_*, *lseek\_*, malloc\_*, *open\_*, *read\_*,
*remove\_*, *rename\_*, *write\_*, *dos\_getftime\_*, *dos\_setftime\_*. The
trailing underscore indicates the \_\_watcall calling convention (which
passes the first few arguments in EAX, EDX, then EBX). All of them had been
identified and reimplemented (as new code in *apack1b.nasm*) using the same
calling convention, for Linux i386 and Win32. Some of these functions have
been replaced with dummies, such as the dummy *kbhit\_* which always
indicates that no key was pressed. Also, for simplicity, *dos\_getftime\_*
and *dos\_setftime\_* were replaced with no-op, which makes apack1p keep the
last-modification time of the output as new, rather than a copy of the time
of the input file. When needed, the assembly listing output of IDA was
consulted on how the program uses these libc functions, and what
simplifications can be made in the implementation.

*db* and *dd* directives have been added to the beginning of *apack1p.nasm*,
to generate the Linux i386 ELF-32 execuable program headers. Thus running
*nasm* and then `chmod +x apack1p` directly produces a working program
(port of aPACK 1.00) for Linux i386. See the full command lines in
[compile.sh](compile.sh).

The Win32 and 32-bit DOS program files were not generated by NASM directly,
because it would be cumbersome to make NASM generate relocations, which are
needed by the relevant file formats. (For Win32 the relocations are not
strictly needed, but they make the program more compatbile, such as with
Win32 emulators running on DOS.) Instead of tha, the OMF .obj output of NASM
was fed to *wlink*, the OpenWatcom linker, which can generate such
executable files with relocations. Again, all these *nasm* and *wlink*
invocations have been automated, and full command lines are in
[compile.sh](compile.sh).

## Possible future work

* Make it reentrant in the same directory by making it choose a different
  temporary filename (rather than *APACKTMP.$$$*) for each invocation.

* Add back the output file timestamping functionality.

* Make the 32-bit DOS port shorter by writing a custom libc (which is
  smaller than the currently used OpenWatcom libc).

* Port the build system to Win32.

* Port it to FreeBSD i386 and other i386 on other popular BSDs.

* Port it to macOS i386. The last release of macOS which supports i386
  (*32-bit apps*) is macOS 10.14 Mojave released on 2018-09-24.

* Write a (limited) lightweight i386 emulator in ANSI C, and run it the
  emulator.
