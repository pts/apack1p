#!/bin/sh --
eval 'PERL_BADLANG=x;export PERL_BADLANG;exec perl -x "$0" "$@";exit 1'
#!perl  # Start marker used by perl -x.
+0 if 0;eval("\n\n\n\n".<<'__END__');die$@if$@;__END__

#
# gensyms_apack.pl: generates apack.syms from apack2ida.lst
# by pts@fazekas.hu at Sat Jan 25 15:56:00 CET 2025
#
# This script works with Perl 5.004.04 (1997-10-15) or later.
#

BEGIN { $ENV{LC_ALL} = "C" }  # For deterministic output. Typically not needed. Is it too late for Perl?
BEGIN { $ENV{TZ} = "GMT" }  # For deterministic output. Typically not needed. Perl respects it immediately.
BEGIN { $^W = 1 }  # Enable warnings.
use integer;
use strict;

die "fatal: stdin\n" if !open(STDIN, "< apack2ida.lst");
die "fatal: stdout\n" if !open(STDOUT, "> apack.syms");

my $text_size = 0x11000;
my $td_size = 0x11d08;
while (<STDIN>) {
  chomp;
  next if m@^[.]prgend:@;
  die "fatal: no addr: $_\n" if !s@^[.](text|bss):([0-9A-F]+) *@@;
  my($section, $addr) = ($1, hex($2) - 0x700000);
  if ($section eq "text") { if ($addr >= $text_size) { $section = "data"; $addr -= $text_size } }
  else { die "bad _bss" if $addr < $td_size; $addr -= $td_size }  # _bss.
  s@;.*@@s; next if !length($_);
  s@\s+@ @g; s@ $@@;
  if (s@^(\w+)(:| proc\b| d[bwdqt] )@$2@) {
    my $label = $1;
    printf("%s equ _%s+0x%x\n", $label, $section, $addr);
    s@^ @@;
  }
  if (m@^call (\w+)$@) {
    printf("call_at _%s+0x%x, %s\n", $section, $addr, $1);
  }
  if (m@^db \x27\xfe@) {
    printf("patch_db_at _%s+0x%x, 0xfe, \x27*\x27\n", $section, $addr);
  } elsif (m@^db 0Dh,\x27\xfe@) {
    printf("patch_db_at _%s+0x%x, 0xfe, \x27*\x27\n", $section, $addr + 1);
  }
}

__END__
