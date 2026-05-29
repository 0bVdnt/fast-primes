declare i64 @isqrt(i64)
declare i64 @lehmer_pi(i64, ptr, i64, ptr, ptr, ptr)
declare ptr @mmap(ptr, i64, i64, i64, i64, i64)

define private double @log_fpu(double %x) {
  %fyl2x = call double asm "fyl2x", "={st},0,{st(1)},~{st(1)},~{dirflag},~{fpsr},~{flags}"(double %x, double 0.6931471805599453)
  ret double %fyl2x
}

define private double @logarithmic_integral(double %x) {
entry:
  %ln_x = tail call double @log_fpu(double %x)
  br label %loop
loop:
  %k = phi i32 [ 1, %entry ], [ %k.next, %latch ]
  %term = phi double [ 1.0, %entry ], [ %term.next, %latch ]
  %sum = phi double [ 1.0, %entry ], [ %sum.next, %latch ]
  %k.f = uitofp i32 %k to double
  %div = fdiv double %k.f, %ln_x
  %term.next = fmul double %term, %div
  %sum.next = fadd double %sum, %term.next
  %is_neg = fcmp olt double %term.next, 0.0
  %neg_term = fsub double 0.0, %term.next
  %abs = select i1 %is_neg, double %neg_term, double %term.next
  %done1 = fcmp olt double %abs, 1.0e-14
  %k.next = add i32 %k, 1
  %done2 = icmp sgt i32 %k.next, 14
  %done = or i1 %done1, %done2
  br i1 %done, label %exit, label %latch
latch:
  br label %loop
exit:
  %res1 = fdiv double %x, %ln_x
  %res = fmul double %res1, %sum.next
  ret double %res
}

define private i64 @inv_li(i64 %n_int) {
entry:
  %n = uitofp i64 %n_int to double
  %ln_n = call double @log_fpu(double %n)
  %ln_ln_n = call double @log_fpu(double %ln_n)
  %t1 = fadd double %ln_n, %ln_ln_n
  %t2 = fsub double %t1, 1.0
  %t3 = fsub double %ln_ln_n, 2.0
  %t4 = fdiv double %t3, %ln_n
  %t5 = fadd double %t2, %t4
  %x.init = fmul double %n, %t5
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %latch ]
  %x = phi double [ %x.init, %entry ], [ %x.corr, %latch ]
  %li_x = call double @logarithmic_integral(double %x)
  %err = fsub double %li_x, %n
  %ln_x = call double @log_fpu(double %x)
  %corr = fmul double %err, %ln_x
  %x.next = fsub double %x, %corr
  %is_neg = fcmp olt double %corr, 0.0
  %neg_corr = fsub double 0.0, %corr
  %abs = select i1 %is_neg, double %neg_corr, double %corr
  %done = fcmp olt double %abs, 0.5
  br i1 %done, label %exit, label %latch
latch:
  %i.next = add i32 %i, 1
  %x.lt2 = fcmp olt double %x.next, 2.0
  %x.corr = select i1 %x.lt2, double 2.0, double %x.next
  %idone = icmp sge i32 %i.next, 8
  br i1 %idone, label %exit, label %loop
exit:
  %x.final = phi double [ %x.next, %loop ], [ %x.corr, %latch ]
  %res = fptoui double %x.final to i64
  ret i64 %res
}

define weak_odr i128 @prime(i64 %target_idx, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table) {
entry:
  %n = add i64 %target_idx, 1

  ; For small N, directly look up from the populated primes array
  %is_small = icmp ule i64 %n, 600000
  br i1 %is_small, label %fast_lookup, label %one_shot

fast_lookup:
  %idx_m1 = sub i64 %n, 1
  %p_ptr = getelementptr i64, ptr %primes, i64 %idx_m1
  %p_val = load i64, ptr %p_ptr
  %p_val_z = zext i64 %p_val to i128
  ret i128 %p_val_z

one_shot:
  ; Generate a tight mathematical bound (guaranteed < p_n)
  %li_inv = call i64 @inv_li(i64 %n)
  %sqrt_est = call i64 @isqrt(i64 %li_inv)
  %margin = mul i64 %sqrt_est, 40
  %x_guess = sub i64 %li_inv, %margin

  ; Evaluate Lehmer Pi
  %c = call i64 @lehmer_pi(i64 %x_guess, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  %rem_target = sub i64 %n, %c

  ; Allocate a tiny Segmented Sieve to bridge the gap
  %gap_size = mul i64 %margin, 3
  %gap_sieve = call ptr @mmap(ptr null, i64 %gap_size, i64 3, i64 34, i64 -1, i64 0)
  
  %max_val = add i64 %x_guess, %gap_size
  %sqrt_max = call i64 @isqrt(i64 %max_val)

  br label %sieve_primes_loop

sieve_primes_loop:
  %i = phi i64 [ 0, %one_shot ], [ %i.next, %sieve_primes_latch ]
  %p_i.ptr = getelementptr i64, ptr %primes, i64 %i
  %p_i = load i64, ptr %p_i.ptr
  
  %is_zero = icmp eq i64 %p_i, 0
  %done1 = icmp ugt i64 %p_i, %sqrt_max
  %done = or i1 %is_zero, %done1
  br i1 %done, label %scan_gap, label %mark_gap

mark_gap:
  %rem_div = urem i64 %x_guess, %p_i
  %is_exact = icmp eq i64 %rem_div, 0
  %sub_p = sub i64 %p_i, %rem_div
  %offset = select i1 %is_exact, i64 0, i64 %sub_p
  br label %mark_loop

mark_loop:
  %j = phi i64 [ %offset, %mark_gap ], [ %j.next, %mark_step ]
  %j.done = icmp uge i64 %j, %gap_size
  br i1 %j.done, label %sieve_primes_latch, label %mark_step

mark_step:
  %ptr = getelementptr i8, ptr %gap_sieve, i64 %j
  store i8 1, ptr %ptr
  %j.next = add i64 %j, %p_i
  br label %mark_loop

sieve_primes_latch:
  %i.next = add i64 %i, 1
  br label %sieve_primes_loop

scan_gap:
  br label %scan_loop

scan_loop:
  %k = phi i64 [ 0, %scan_gap ], [ %k.next, %scan_latch ]
  %rem_count = phi i64 [ %rem_target, %scan_gap ], [ %rem.next, %scan_latch ]
  
  %ptr.k = getelementptr i8, ptr %gap_sieve, i64 %k
  %val = load i8, ptr %ptr.k
  %is_prime = icmp eq i8 %val, 0
  br i1 %is_prime, label %found_prime, label %scan_latch

found_prime:
  %rem.dec = sub i64 %rem_count, 1
  %is_target = icmp eq i64 %rem.dec, 0
  br i1 %is_target, label %return_ans, label %scan_latch

scan_latch:
  %rem.next = phi i64 [ %rem_count, %scan_loop ], [ %rem.dec, %found_prime ]
  %k.next = add i64 %k, 1
  br label %scan_loop

return_ans:
  %ans = add i64 %x_guess, %k
  %ans_z = zext i64 %ans to i128
  ret i128 %ans_z
}
