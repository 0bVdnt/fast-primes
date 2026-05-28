; This file is taken from https://github.com/SheafificationOfG/QueenJewels

; Non-portable AMD64 ABI stuff
; (I'm only loosely following the ABI enough so things work on my machine.)

declare i64 @main(i64, ptr)
declare void @exit(i64) noreturn

; "naked" - don't generate stack frame boilerplate for _start
; (we need %rsp to read argc / argv)
define void @_start() naked {
  ; clear frame pointer
  tail call void asm sideeffect "", "{rbp}"(i64 0)

  ; on program entry, the stack is populated with
  ; argc at (%rsp)
  ; argv[0] at 8(%rsp)
  ; argv[1] at 16(%rsp)
  ; ...
  %rsp = tail call ptr asm "", "={rsp},0"(ptr undef)
  %argc = load i64, ptr %rsp
  %argv = getelementptr i8, ptr %rsp, i64 8

  ; note: stack is 16-byte aligned on entry
  %exitcode = tail call i64 @main(i64 %argc, ptr %argv)

  tail call void @exit(i64 %exitcode)
  unreachable
}

