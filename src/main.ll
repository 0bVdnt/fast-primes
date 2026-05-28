declare ptr @mmap(ptr, i64, i64, i64, i64, i64)
declare void @init_phi_table(ptr)
declare i64 @init_sieve_cache(i64, ptr, ptr)
declare i128 @prime(i64, ptr, i64, ptr, ptr, ptr)
declare i64 @write(i64, ptr, i64)

@error.msg = private constant [22 x i8] c"Expected an integer.\0A\00"

define i64 @main(i64 %argc, ptr %argv) {
entry:
  %has_argc = icmp eq i64 %argc, 2
  br i1 %has_argc, label %setup_memory, label %error

error:
  call i64 @write(i64 2, ptr @error.msg, i64 22)
  ret i64 1

setup_memory:
  ; Parse CLI target (1 indexed)
  %n.offset = getelementptr ptr, ptr %argv, i64 1
  %n.ptr = load ptr, ptr %n.offset
  %target = call i64 @parse.i64(ptr %n.ptr)

  ; Allocate pi_table[10,000,000]
  %pi_table = call ptr @mmap(ptr null, i64 80000000, i64 3, i64 34, i64 -1, i64 0)

  ; Allocate primes array
  %primes = call ptr @mmap(ptr null, i64 80000000, i64 3, i64 34, i64 -1, i64 0)
  
  ; Allocate phi_table
  %phi_table = call ptr @mmap(ptr null, i64 1681736, i64 3, i64 34, i64 -1, i64 0)
  
  ; Allocate hash_table
  %hash_table = call ptr @mmap(ptr null, i64 268435456, i64 3, i64 34, i64 -1, i64 0)

  ; Populate tables
  call void @init_phi_table(ptr %phi_table)
  %cache_limit = add i64 10000000, 0
  call i64 @init_sieve_cache(i64 %cache_limit, ptr %pi_table, ptr %primes)

  ; Execute Lehmer Binary Search
  %p_n = call i128 @prime(i64 %target, ptr %pi_table, i64 %cache_limit, ptr %primes, ptr %phi_table, ptr %hash_table)

  call void @write.i128(i128 %p_n)
  ret i64 0
}

; parse %str as a decimal integer
define private i64 @parse.i64(ptr %str) {
entry:
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %i.inc, %continue ]
  %result = phi i64 [ 0, %entry ], [ %result.next, %continue ]
  %char.offset = getelementptr i8, ptr %str, i64 %i
  %char = load i8, ptr %char.offset
  %char_is_digit.lo = icmp uge i8 %char, 48 ; '0'
  %char_is_digit.hi = icmp ule i8 %char, 57 ; '9'
  %char_is_digit = and i1 %char_is_digit.lo, %char_is_digit.hi
  br i1 %char_is_digit, label %consume, label %check_separator

consume:
  %digit = sub i8 %char, 48 ; '0'
  %digit.val = zext i8 %digit to i64
  %result.10 = mul i64 %result, 10
  %result.sum = add i64 %result.10, %digit.val
  br label %continue

continue:
  %result.next = phi i64 [ %result, %check_separator ], [ %result.sum, %consume ]
  %i.inc = add i64 %i, 1
  br label %loop

check_separator:
  %is_comma = icmp eq i8 %char, 44 ; ','
  %is_underscore = icmp eq i8 %char, 95 ; '_'
  %is_separator = or i1 %is_comma, %is_underscore
  br i1 %is_separator, label %continue, label %return

return:
  ret i64 %result
}

; print integer %x to stdout
define private void @write.i128(i128 %x) {
entry:
  ; 128-bit integer has at most 39 digits in decimal
  ; plus separators every 3 digits and a newline = 52
  %buf = alloca [52 x i8]

  ; populate buffer in reverse
  %buf.end = getelementptr i8, ptr %buf, i64 51
  store i8 10, ptr %buf.end ; '\n' = 10
  br label %loop

loop:
  %x.rem = phi i128 [ %x, %entry ], [ %x.red, %step ], [ %x.red, %add_sep ]
  %i = phi i64 [ 50, %entry ], [ %i.next, %step ], [ %i.sep.next, %add_sep ]
  %sep_counter = phi i8 [ 2, %entry ], [ %sep.step, %step ], [ 2, %add_sep ]
  %digit = urem i128 %x.rem, 10
  %digit.byte = trunc i128 %digit to i8
  %digit.char = add i8 %digit.byte, 48 ; '0'

  %buf.slot = getelementptr i8, ptr %buf, i64 %i
  store i8 %digit.char, ptr %buf.slot

  %x.red = udiv i128 %x.rem, 10
  %i.red = sub i64 %i, 1
  %done = icmp eq i128 %x.red, 0
  br i1 %done, label %print, label %step

step:
  %i.next = sub i64 %i, 1
  %need_sep = icmp eq i8 %sep_counter, 0
  %sep.step = sub i8 %sep_counter, 1
  br i1 %need_sep, label %add_sep, label %loop

add_sep:
  %buf.sep.slot = getelementptr i8, ptr %buf, i64 %i.next
  store i8 95, ptr %buf.sep.slot ; '_'
  %i.sep.next = sub i64 %i.next, 1
  br label %loop

print:
  %len = sub i64 52, %i
  call i64 @write(i64 1, ptr %buf.slot, i64 %len)
  ret void
}
