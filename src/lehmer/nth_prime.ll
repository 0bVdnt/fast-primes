declare i64 @llvm.ctlz.i64(i64, i1)
declare i64 @lehmer_pi(i64, ptr, i64, ptr, ptr, ptr)

; Approximates log2(n)
define private i64 @log.ish(i64 %n) {
  %lz = call i64 @llvm.ctlz.i64(i64 %n, i1 true)
  %size = sub i64 64, %lz
  ret i64 %size
}

; Generates a safe upper bound > p_n using n * (log2(n) + log2(log2(n)))
define private i64 @bound(i64 %n) {
entry:
  %is_tiny = icmp ult i64 %n, 2
  br i1 %is_tiny, label %return, label %log

log:
  %log.n = call i64 @log.ish(i64 %n)
  %log.log.n = call i64 @log.ish(i64 %log.n)
  %add = add i64 %log.n, %log.log.n
  %total = mul i64 %n, %add
  br label %return

return:
  %bound = phi i64 [ 4, %entry ], [ %total, %log ]
  ret i64 %bound
}

define weak_odr i128 @prime(i64 %target, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table) {
entry:
  %cmp = icmp eq i64 %target, 1
  br i1 %cmp, label %return_2, label %setup_search

return_2:
  ret i128 2

setup_search:
  %high.init = call i64 @bound(i64 %target)
  br label %search_loop

search_loop:
  %left = phi i64 [ 2, %setup_search ], [ %left.next, %check_bound ]
  %right = phi i64 [ %high.init, %setup_search ], [ %right.next, %check_bound ]
  
  %diff = sub i64 %right, %left
  %done = icmp eq i64 %diff, 0
  br i1 %done, label %found, label %step

step:
  %mid.offset = lshr i64 %diff, 1
  %mid = add i64 %left, %mid.offset

  ; Query Lehmer's algorithm for pi(n)
  %pi_mid = call i64 @lehmer_pi(i64 %mid, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  
  %is_geq = icmp uge i64 %pi_mid, %target
  br i1 %is_geq, label %move_right, label %move_left

move_right:
  br label %check_bound

move_left:
  %mid.plus1 = add i64 %mid, 1
  br label %check_bound

check_bound:
  %left.next = phi i64 [ %left, %move_right ], [ %mid.plus1, %move_left ]
  %right.next = phi i64 [ %mid, %move_right ], [ %right, %move_left ]
  br label %search_loop

found:
  %prime = zext i64 %left to i128
  ret i128 %prime
}