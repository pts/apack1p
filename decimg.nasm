;
; decimg.nasm: decompress the program image from apack.exe
; by pts@fazekas.hu at Fri Jan 24 22:11:41 CET 2025
;
; Compile with: nasm -O0 -w+orphan-labels -f bin -o decimg decimg.nasm && chmod +x decimg
; Minimum NASM version required to compile: 0.98.39
;

bits 32
cpu 386

; ELF-32 OSABI constants.
OSABI.Linux: equ 3

; Linux open(2) flags constants.
O_RDONLY equ 0
O_WRONLY equ 1
O_RDWR equ 2
O_CREAT equ 100q
O_TRUNC equ 1000q

; --- We got this info from reverse engineering (disassembly).

%define REI_FN 'apack.exe'
%define RE32_FN 'apack.re32'
rei_cfofs equ 0x2e50  ; Compressed image file offset.
rei_csize equ 0x83c9  ; Compressed image size.
rei_usize equ 0x11d08  ; Uncompressed image size (without relocations).
rei_crlimit equ 0x10000  ; Reasonable upper limit on the size of compressed relocations (after generic decompression) and also uncompressed relocations.
rei_cdata_ofs equ 0x46
rei_decompress_ofs equ 0x82c7
rei_entry_ofs equ 0xd0b0
rei_bss_size equ 0x512f8
rei_reloc_count equ 0xef0
rei_text_size equ 0x11000  ; Uncompressed.

; ---

org 0x700000
file_header:
Elf32_Ehdr:
        	db 0x7f,'ELF',1,1,1,OSABI.Linux,0,0,0,0,0,0,0,0,2,0,3,0
	        dd 1,_start,Elf32_Phdr-file_header,0,0
	        dw Elf32_Phdr-file_header,0x20,1,0x28,0,0
Elf32_Phdr:
        	dd 1,0,$$,$$,bss-$$,mem_end-$$,7,0x1000

_start:		mov ecx, msg_starting
		call fputs_stderr

		mov edi, re32_copy+1+re32_copy.udata-re32_copy
		mov esi, cdata
		call decompress  ; We execute untrusted code here, copied from file REI_FN.

		mov esi, re32_copy+1
		mov edi, re32_copy1
		mov ecx, re32_copy.udata.end-re32_copy
		rep movsb

		mov edi, re32_copy+re32_copy.udata-re32_copy
		mov esi, cdata
		call decompress  ; We execute untrusted code here, copied from file REI_FN.

diff_relocations:
		; Find relocation differences between re32_copy and re32_copy1.
		mov esi, re32_copy1+re32_copy.udata-re32_copy
		mov edi, re32_copy+re32_copy.udata-re32_copy
		mov edx, edi  ; Save for diff within the loop.
		mov ecx, rei_usize   ; Not: `mov ecx, re32_copy.udata.end-re32_copy', because we exclude the relocations and the decompressor.
		mov ebx, re32_copy.relocations
.next:		cmp ecx, ecx  ; ZF := 0.
		repe cmpsb  ; EDI := 1 + address of the first mismatch.
		je .done
		sub ecx, byte 3
		jc near fatal_endrel
		add esi, byte 3
		push edi
		dec edi
		push edx  ; Save.
		mov edx, [esi-4]
		dec edx
		cmp [edi], edx  ; Check for an offset difference of 1 between re32_copy and re32_copy1.
		jne near fatal_diffrel
		pop edx  ; Restore.
		sub [edi], edx  ; Undo the relocation.
		jc near fatal_negrel
		sub edi, edx  ; EDI := offset from re32_copy.udata.
		mov [ebx], edi
		add ebx, byte 4
		pop edi
		add edi, byte 3
		jmp short .next
.done:		sub ebx, re32_copy.relocations
		shr ebx, 2  ; Each relocation is 4 bytes.
		cmp ebx, rei_reloc_count
		jne near fatal_relcnt
		mov [re32.reloc_count], ebx

write_output_file:
		; Copy the re32 header to re32_copy.
		mov esi, re32
		mov edi, re32_copy
		mov ecx, re32.end-re32
		rep movsb

		mov eax, 5  ; SYS_open. No need to close the file, SYS_exit will close it.
		mov ebx, filename2
		mov ecx, O_WRONLY|O_CREAT|O_TRUNC
		mov edx, 666q
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		js fatal_io
		push eax  ; File descriptor (fd).

		mov eax, 4  ; SYS_write.
		pop ebx  ; File descriptor (fd).
		mov ecx, re32_copy
		mov edx, [re32.reloc_count]
		shl edx, 2  ; Each relocation is 4 bytes.
		add edx, rei_usize+(re32.end-re32)  ; Not: `add edx, re32_copy.udata.end-re32_copy', because we exclude the relocations and the decompressor.
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		js fatal_io

		mov eax, 6  ; SYS_close.
		;mov ebx, ...  ; Already contains the filehandle.
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		js fatal_io

all_ok:		mov ecx, msg_all_ok
		call fputs_stderr

		xor eax, eax
		inc eax  ; SYS_exit == 1.
		xor ebx, ebx  ; EXIT_SUCCESS.
		int 0x80  ; Linux i386 syscall.
		; Not reached.

fputs_stderr:  ; Writes NUL-terminated message at ECX to stderr.
		push eax
		push ebx
		push edx
		mov eax, 4  ; SYS_write.
		mov ebx, 2  ; STDOUT_FILENO.
		;mov ecx, msg  ;  Already set.
		xor edx, edx
.next:		cmp [ecx+edx], ah
		je .end
		inc edx
		jmp short .next
.end:		int 0x80  ; Linux i386 syscall.
		pop edx
		pop ebx
		pop eax
		ret

fatal_diffrel:	mov ecx, fmsg_diffrel
		jmp short fatal

fatal_relcnt:	mov ecx, fmsg_relcnt
		jmp short fatal

fatal_negrel:	mov ecx, fmsg_negrel
		jmp short fatal

fatal_endrel:	mov ecx, fmsg_endrel
		jmp short fatal

fatal_io:	mov ecx, fmsg_io
		; Fall through.

fatal:		call fputs_stderr

		xor eax, eax
		inc eax  ; SYS_exit == 1.
		mov ebx, 2  ; A non-succees code.
		int 0x80  ; Linux i386 syscall.
		; Not reached.


obj1:		incbin REI_FN, rei_cfofs, rei_csize
cdata:		equ obj1+rei_cdata_ofs
decompress:	equ obj1+rei_decompress_ofs  ; Decompresses aPLib-compressed, filtered stream from ESI to EDI.
init_bss_and_start:
		ret  ; Return to the caller of decompress.

re32:
.signature:	dd 'RE32'  ; Signature: 'RE32': i386 32-bit relocated executable image.
.entry_ofs:	dd rei_entry_ofs  ; Within .text.
.bss_size:	dd rei_bss_size  ; .bss starts right dfter .data.
.text_size:	dd rei_text_size
.reloc_count:   dd 0  ; Will be changed before saving to the file.
.data_size:     dd rei_usize-rei_text_size  ; .data starts right after .text.
.padding:	times 0x20-($-.signature) db 0
.end:

msg_starting:	db 'info: starting', 10, 0

msg_all_ok:	db 'info: all OK.', 10, 0

fmsg_io:	db 'fatal: I/O error', 10, 0

fmsg_endrel:	db 'fatal: relocation near end of data', 10, 0

fmsg_negrel:	db 'fatal: negative offset in relocation', 10, 0

fmsg_relcnt:	db 'fatal: relocation count mismatch', 10, 0

fmsg_diffrel:	db 'fatal: relocation offset difference must be 1', 10, 0

filename2:	db RE32_FN, 0

bss_noalign:	absolute $
		alignb 4
bss:

re32_copy:	resb re32.end-re32
.udata:		resb rei_usize  ; uncompressed_image_size. This is the output buffer for the uncompressed program image data.
.udata.end:
.relocations:	resb rei_crlimit
		resb 1  ; In case everything is shifted by 1 byte.

re32_copy1:	resb re32.end-re32
.udata:		resb rei_usize  ; uncompressed_image_size. This is the output buffer for the uncompressed program image data.

mem_end:

; __END__.
