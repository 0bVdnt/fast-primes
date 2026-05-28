declare i64 @isqrt(i64)
declare i64 @icbrt(i64)
declare i64 @iroot4(i64)
declare i64 @phi_eval(i64, i64, ptr, ptr, ptr)

; We assume %pi_table is an mmap'd array where pi_table[x] holds the precomputed prime count up to x.

define weak_odr i64 @lehmer_pi(i64 %x, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table) {
entry:
	; O(1) Cache Lookup
	%in_table = icmp ult i64 %x, %table_limit
	br i1 %in_table, label %cache_hit, label %compute

cache_hit:
	%cache.ptr = getelementptr i64, ptr %pi_table, i64 %x
	%cached.val = load i64, ptr %cache.ptr
	ret i64 %cached.val

compute:
  %a.input = tail call i64 @iroot4(i64 %x)
  %a = tail call i64 @lehmer_pi(i64 %a.input, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  
  %b.input = tail call i64 @isqrt(i64 %x)
  %b = tail call i64 @lehmer_pi(i64 %b.input, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  
  %c.input = tail call i64 @icbrt(i64 %x)
  %c = tail call i64 @lehmer_pi(i64 %c.input, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)

	; result = phi(x, a) + ((b + a - 2) * (b - a + 1)) / 2
  %base.phi = tail call i64 @phi_eval(i64 %x, i64 %a, ptr %phi_table, ptr %primes, ptr %hash_table)

  %b.plus.a = add i64 %b, %a
  %term1 = sub i64 %b.plus.a, 2
  %b.sub.a = sub i64 %b, %a
  %term2 = add i64 %b.sub.a, 1
  %term.mul = mul i64 %term1, %term2
  %term.div = lshr i64 %term.mul, 1

	%result.init = add i64 %base.phi, %term.div

	; Early exit if a == b
	%loops.done = icmp eq i64 %a, %b
  br i1 %loops.done, label %return, label %loop_i.header

; Outer loop: P2 Computation (i from a to b-1)
loop_i.header:
	%i = phi i64 [ %a, %compute ], [ %i.next, %loop_i.latch ]
	%result.i = phi i64 [ %result.init, %compute ], [ %result.next, %loop_i.latch ]

	%i.done = icmp uge i64 %i, %b
	br i1 %i.done, label %return, label %loop_i.body

loop_i.body:
	; w = x / primes[i]
	%p_i.ptr = getelementptr i64, ptr %primes, i64 %i
	%p_i = load i64, ptr %p_i.ptr
  %w = udiv i64 %x, %p_i

	; result -= lehmer_pi(w)
	%pi_w = tail call i64 @lehmer_pi(i64 %w, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  %result.sub1 = sub i64 %result.i, %pi_w

	; if i < c, do P3 inner loop
	%do_j = icmp ult i64 %i, %c
  br i1 %do_j, label %loop_j.setup, label %loop_i.latch

; Inner loop: P3 Computation (j from i to limit-1)
loop_j.setup:
  %w_sqrt = tail call i64 @isqrt(i64 %w)
  %limit = tail call i64 @lehmer_pi(i64 %w_sqrt, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  br label %loop_j.header

loop_j.header:
  %j = phi i64 [ %i, %loop_j.setup ], [ %j.next, %loop_j.body ]
  %result.j = phi i64 [ %result.sub1, %loop_j.setup ], [ %result.j.next, %loop_j.body ]
  
  %j.done = icmp uge i64 %j, %limit
  br i1 %j.done, label %loop_i.latch, label %loop_j.body

loop_j.body:
	; w_div_pj = w / primes[j]
	%p_j.ptr = getelementptr i64, ptr %primes, i64 %j
  %p_j = load i64, ptr %p_j.ptr
  %w_div_pj = udiv i64 %w, %p_j

	; result -= lehmer_pi(w_div_pj) - j
	%pi_w_pj = tail call i64 @lehmer_pi(i64 %w_div_pj, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  %term.sub = sub i64 %pi_w_pj, %j
  %result.j.next = sub i64 %result.j, %term.sub

	%j.next = add i64 %j, 1
  br label %loop_j.header

; Latch and Return
loop_i.latch:
  %result.next = phi i64 [ %result.sub1, %loop_i.body ], [ %result.j, %loop_j.header ]
  %i.next = add i64 %i, 1
  br label %loop_i.header

return:
  %final.result = phi i64 [ %result.init, %compute ], [ %result.i, %loop_i.header ]
  ret i64 %final.result
}
