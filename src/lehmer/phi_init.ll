@phi.primes = private constant [6 x i64] [i64 2, i64 3, i64 5, i64 7, i64 11, i64 13]

; Populates the [7 x 30031] i64 array for O(1) phi evaluations when a <= 6
define weak_odr void @init_phi_table(ptr %phi_table) {
entry:
  br label %init_row_zero

; Initialize Row 0: phi_table[0][n] = n
init_row_zero:
  %n = phi i64 [ 0, %entry ], [ %n.next, %init_row_zero ]
  %ptr.0 = getelementptr i64, ptr %phi_table, i64 %n
  store i64 %n, ptr %ptr.0
  %n.next = add i64 %n, 1
  %done_0 = icmp ugt i64 %n, 30030
  br i1 %done_0, label %outer_loop.setup, label %init_row_zero

; Initialize Rows 1 to 6
outer_loop.setup:
  br label %outer_loop

outer_loop:
  %a = phi i64 [ 1, %outer_loop.setup ], [ %a.next, %outer_latch ]

  ; Get p_a = phi.primes[a - 1]
  %a.m1 = sub i64 %a, 1
  %p_a.ptr = getelementptr [6 x i64], ptr @phi.primes, i32 0, i64 %a.m1
  %p_a = load i64, ptr %p_a.ptr

  ; Base offsets for Row[a] and Row[a-1]
  %row.a.offset = mul i64 %a, 30031
  %row.prev.offset = mul i64 %a.m1, 30031
  
  br label %inner_loop

inner_loop:
  %idx = phi i64 [ 0, %outer_loop ], [ %idx.next, %inner_loop ]

  ; previous[n]
  %idx.prev = add i64 %row.prev.offset, %idx
  %ptr.prev = getelementptr i64, ptr %phi_table, i64 %idx.prev
  %val.prev = load i64, ptr %ptr.prev

  ; previous[n / p_a]
  %n_div_p = udiv i64 %idx, %p_a
  %idx.prev.div = add i64 %row.prev.offset, %n_div_p
  %ptr.prev.div = getelementptr i64, ptr %phi_table, i64 %idx.prev.div
  %val.prev.div = load i64, ptr %ptr.prev.div

  ; current[n] = previous[n] - previous[n / p_a]
  %val.current = sub i64 %val.prev, %val.prev.div
  %idx.current = add i64 %row.a.offset, %idx
  %ptr.current = getelementptr i64, ptr %phi_table, i64 %idx.current
  store i64 %val.current, ptr %ptr.current
  
  %idx.next = add i64 %idx, 1
  %done_inner = icmp ugt i64 %idx, 30030
  br i1 %done_inner, label %outer_latch, label %inner_loop

outer_latch:
  %a.next = add i64 %a, 1
  %done_outer = icmp ugt i64 %a, 6
  br i1 %done_outer, label %exit, label %outer_loop

exit:
  ret void
}
