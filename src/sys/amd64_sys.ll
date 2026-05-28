; This file is taken from https://github.com/SheafificationOfG/QueenJewels

; x86-64 system calls
; (no error handling is being done at all)

; Note to self: use strace with the executable to debug syscalls

; read some bytes from %fd into the size-%count buffer %buf
; returns the number of bytes read from the provided %fd
define weak_odr i64 @read(i64 %fd, ptr %buf, i64 %count) alwaysinline {
  %nbytes = tail call i64 @syscall(i64 0, i64 %fd, ptr %buf, i64 %count)
  ret i64 %nbytes
}

; write up to %count bytes from the buffer %buf into %fd
; returns the number of bytes actually written to the provided fd
define weak_odr i64 @write(i64 %fd, ptr %buf, i64 %count) alwaysinline {
  %nbytes = tail call i64 @syscall(i64 1, i64 %fd, ptr %buf, i64 %count, i64 undef, i64 undef, i64 undef)
  ret i64 %nbytes
}

; returns the fd of the newly-opened file
; for flags, see /usr/include/asm-generic/fcntl.h
; e.g., O_RDONLY = 0x0000; O_WRONLY = 0x0001; O_RDWR = 0x0002
; %mode is only relevant when O_CREAT (0x0200) is set
define weak_odr i64 @open(ptr %filename, i64 %flags, i64 %mode) alwaysinline {
  %fd = tail call i64 @syscall(i64 2, ptr %filename, i64 %flags, i64 %mode, i64 undef, i64 undef, i64 undef)
  ret i64 %fd
}

; close the file with descriptor %fd
; returns 0 on success, and I don't care what happens otherwise :)
define weak_odr i64 @close(i64 %fd) alwaysinline {
  %err = tail call i64 @syscall(i64 3, i64 %fd, i64 undef, i64 undef, i64 undef, i64 undef, i64 undef)
  ret i64 %err
}

; returns the mapping obtained
; for prot / flags, see /usr/include/asm-generic/mman-common.h
; e.g., PROT_READ = 0x01; PROT_WRITE = 0x02; MAP_ANONYMOUS = 0x20
; also look at /usr/include/linux/mman.h
; anonymous mapping requires MAP_PRIVATE (0x02) or MAP_SHARED (0x01)
;
; Note. For memory maps not backed by a file, use MAP_ANONYMOUS.
; In this case, %fd and %file_offset should be ignored, but
; %fd *should* be set to -1 and %file_offset should be 0 in this case.
; (anonymous mappings are zero-initialised on Linux)
define weak_odr noalias align 4096 ptr @mmap(ptr %addr_hint, i64 %len, i64 %protection, i64 %flags, i64 %fd, i64 %file_offset) alwaysinline {
  %mapping = tail call ptr @syscall(i64 9, ptr %addr_hint, i64 %len, i64 %protection, i64 %flags, i64 %fd, i64 %file_offset)
  ret ptr %mapping
}

; unmap a given %mapping of size %len
; returns 0 on success
; %mapping should be page-aligned, but %len need not be
; (nothing necessarily needs to be mapped in the passed range)
define weak_odr i64 @munmap(ptr align 4096 %mapping, i64 %len) alwaysinline {
  %exitcode = tail call i64 @syscall(i64 11, ptr %mapping, i64 %len, i64 undef, i64 undef, i64 undef, i64 undef)
  ret i64 %exitcode
}

; exit the program with the provided %exitcode
define weak_odr void @exit(i64 %exitcode) alwaysinline noreturn {
  tail call i64 @syscall(i64 60, i64 %exitcode, i64 undef, i64 undef, i64 undef, i64 undef, i64 undef)
  tail call void asm sideeffect "hlt", ""() noreturn
  unreachable
}

; generate a random sequence of bytes into %count-sized buffer %buf
; returns the number of bytes copied to the buffer
; for flags, see /usr/include/linux/random.h
; e.g., GRND_NONBLOCK = 0x01; GRND_INSECURE = 0x04
define weak_odr i64 @getrandom(ptr %buf, i64 %count, i64 %flags) alwaysinline {
  %nbytes = tail call i64 @syscall(i64 318, ptr %buf, i64 %count, i64 %flags, i64 undef, i64 undef, i64 undef)
  ret i64 %nbytes
}

; generic syscall
define private i64 @syscall(i64 %call, i64 %rdi, i64 %rsi, i64 %rdx, i64 %r10, i64 %r8, i64 %r9) alwaysinline {
  ; syscall number is passed in %rax
  ; the six max arguments to the syscall are passed through %rdi, %rsi, %rdx, %r10, %r8, %r9
  ; syscalls clobber %rcx and %r11
  %rax = tail call i64 asm sideeffect "syscall", "={rax},{rax},{rdi},{rsi},{rdx},{r10},{r8},{r9},~{rcx},~{r11}"
                                  (i64 %call, i64 %rdi, i64 %rsi, i64 %rdx, i64 %r10, i64 %r8, i64 %r9)
  ret i64 %rax
}
