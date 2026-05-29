declare i64 @isqrt(i64)
declare i64 @icbrt(i64)
declare i64 @iroot4(i64)
declare i64 @phi_eval(i64, i64, ptr, ptr, ptr)

define weak_odr i64 @lehmer_pi(i64 %x, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table) {
entry:
  %in_table = icmp ult i64 %x, %table_limit
  br i1 %in_table, label %cache_hit, label %compute

cache_hit:
  %cache.ptr = getelementptr i64, ptr %pi_table, i64 %x
  %cached.val = load i64, ptr %cache.ptr
  ret i64 %cached.val

compute:
  %a.input = tail call i64 @iroot4(i64 %x)
  %a.ptr = getelementptr i64, ptr %pi_table, i64 %a.input
  %a = load i64, ptr %a.ptr
  
  %b.input = tail call i64 @isqrt(i64 %x)
  %b.ptr = getelementptr i64, ptr %pi_table, i64 %b.input
  %b = load i64, ptr %b.ptr
  
  %c.input = tail call i64 @icbrt(i64 %x)
  %c.ptr = getelementptr i64, ptr %pi_table, i64 %c.input
  %c = load i64, ptr %c.ptr

  %base.phi = tail call i64 @phi_eval(i64 %x, i64 %a, ptr %phi_table, ptr %primes, ptr %hash_table)

  %b.plus.a = add i64 %b, %a
  %term1 = sub i64 %b.plus.a, 2
  %b.sub.a = sub i64 %b, %a
  %term2 = add i64 %b.sub.a, 1
  %term.mul = mul i64 %term1, %term2
  %term.div = lshr i64 %term.mul, 1

  %result.init = add i64 %base.phi, %term.div

  %loops.done = icmp eq i64 %a, %b
  br i1 %loops.done, label %return, label %loop_i.header

loop_i.header:
  %i = phi i64 [ %a, %compute ], [ %i.next, %loop_i.latch ]
  %result.i = phi i64 [ %result.init, %compute ], [ %result.next, %loop_i.latch ]
  %i.done = icmp uge i64 %i, %b
  br i1 %i.done, label %return, label %loop_i.body

loop_i.body:
  %p_i.ptr = getelementptr i64, ptr %primes, i64 %i
  %p_i = load i64, ptr %p_i.ptr
  %w = udiv i64 %x, %p_i
  
  %w_lt = icmp ult i64 %w, %table_limit
  br i1 %w_lt, label %pi_w_fast, label %pi_w_slow

pi_w_fast:
  %pi_w_ptr = getelementptr i64, ptr %pi_table, i64 %w
  %pi_w_fast_val = load i64, ptr %pi_w_ptr
  br label %pi_w_cont

pi_w_slow:
  %pi_w_slow_val = tail call i64 @lehmer_pi(i64 %w, ptr %pi_table, i64 %table_limit, ptr %primes, ptr %phi_table, ptr %hash_table)
  br label %pi_w_cont

pi_w_cont:
  %pi_w = phi i64 [ %pi_w_fast_val, %pi_w_fast ], [ %pi_w_slow_val, %pi_w_slow ]
  %result.sub1 = sub i64 %result.i, %pi_w

  %do_j = icmp ult i64 %i, %c
  br i1 %do_j, label %loop_j.setup, label %loop_i.latch

loop_j.setup:
  %w_sqrt = tail call i64 @isqrt(i64 %w)
  %limit_j_ptr = getelementptr i64, ptr %pi_table, i64 %w_sqrt
  %limit_j = load i64, ptr %limit_j_ptr
  br label %loop_j.header

loop_j.header:
  %j = phi i64 [ %i, %loop_j.setup ], [ %j.next, %loop_j.body ]
  %result.j = phi i64 [ %result.sub1, %loop_j.setup ], [ %result.j.next, %loop_j.body ]
  %j.done = icmp uge i64 %j, %limit_j
  br i1 %j.done, label %loop_i.latch, label %loop_j.body

loop_j.body:
  %p_j.ptr = getelementptr i64, ptr %primes, i64 %j
  %p_j = load i64, ptr %p_j.ptr
  %w_div_pj = udiv i64 %w, %p_j

  %pi_w_pj_ptr = getelementptr i64, ptr %pi_table, i64 %w_div_pj
  %pi_w_pj = load i64, ptr %pi_w_pj_ptr
  
  %term.sub = sub i64 %pi_w_pj, %j
  %result.j.next = sub i64 %result.j, %term.sub

  %j.next = add i64 %j, 1
  br label %loop_j.header

loop_i.latch:
  %result.next = phi i64 [ %result.sub1, %pi_w_cont ], [ %result.j, %loop_j.header ]
  %i.next = add i64 %i, 1
  br label %loop_i.header

return:
  %final.result = phi i64 [ %result.init, %compute ], [ %result.i, %loop_i.header ]
  ret i64 %final.result
}
