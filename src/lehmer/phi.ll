define weak_odr i64 @phi_eval(i64 %x, i64 %a, ptr %phi_table, ptr %primes, ptr %hash_table) {
entry:
  %x_zero = icmp eq i64 %x, 0
  br i1 %x_zero, label %ret_zero, label %check_a
ret_zero:
  ret i64 0
check_a:
  %a_zero = icmp eq i64 %a, 0
  br i1 %a_zero, label %ret_x, label %check_pa
ret_x:
  ret i64 %x
check_pa:
  %a_minus_1 = sub i64 %a, 1
  %pa_ptr = getelementptr i64, ptr %primes, i64 %a_minus_1
  %pa = load i64, ptr %pa_ptr
  %x_le_pa = icmp ule i64 %x, %pa
  br i1 %x_le_pa, label %ret_one, label %check_small
ret_one:
  ret i64 1

check_small:
  %is_small = icmp ule i64 %a, 6
  br i1 %is_small, label %table_lookup, label %cache_lookup

table_lookup:
  %idx_base = mul i64 %a, 30031
  %blocks = udiv i64 %x, 30030
  %rem = urem i64 %x, 30030
  %mod_idx = add i64 %idx_base, 30030
  %mod_ptr = getelementptr i64, ptr %phi_table, i64 %mod_idx
  %val_modulus = load i64, ptr %mod_ptr
  %rem_idx = add i64 %idx_base, %rem
  %rem_ptr = getelementptr i64, ptr %phi_table, i64 %rem_idx
  %val_rem = load i64, ptr %rem_ptr
  %block_val = mul i64 %blocks, %val_modulus
  %table_res = add i64 %block_val, %val_rem
  ret i64 %table_res

cache_lookup:
  %x_shl = shl i64 %x, 16
  %key = or i64 %x_shl, %a
  %hash = mul i64 %key, -7046029254386353131
  
  ; Fibonacci Hashing, extract Top 26 bits
  %hash_top = lshr i64 %hash, 38
  br label %probe_read

probe_read:
  %idx = phi i64 [ %hash_top, %cache_lookup ], [ %idx_next_wrapped, %probe_step ]
  %entry_ptr = getelementptr { i64, i64 }, ptr %hash_table, i64 %idx
  %stored_key.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 0
  %stored_key = load i64, ptr %stored_key.ptr

  %is_empty = icmp eq i64 %stored_key, 0
  br i1 %is_empty, label %compute, label %check_match

check_match:
  %is_match = icmp eq i64 %stored_key, %key
  br i1 %is_match, label %cache_hit, label %probe_step

probe_step:
  %idx_next = add i64 %idx, 1
  ; Mask with 67108863
  %idx_next_wrapped = and i64 %idx_next, 67108863
  br label %probe_read

cache_hit:
  %stored_val.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 1
  %stored_val = load i64, ptr %stored_val.ptr
  ret i64 %stored_val

compute:
  %base = tail call i64 @phi_eval(i64 %x, i64 6, ptr %phi_table, ptr %primes, ptr %hash_table)
  br label %compute_loop

compute_loop:
  %i = phi i64 [ 6, %compute ], [ %i.next, %compute_loop_step ]
  %result = phi i64 [ %base, %compute ], [ %result.next, %compute_loop_step ]
  %done = icmp uge i64 %i, %a
  br i1 %done, label %cache_insert, label %compute_loop_step

compute_loop_step:
  %p_i.ptr = getelementptr i64, ptr %primes, i64 %i
  %p_i = load i64, ptr %p_i.ptr
  %w = udiv i64 %x, %p_i
  %rec_val = tail call i64 @phi_eval(i64 %w, i64 %i, ptr %phi_table, ptr %primes, ptr %hash_table)
  %result.next = sub i64 %result, %rec_val
  %i.next = add i64 %i, 1
  br label %compute_loop

cache_insert:
  %insert_key.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 0
  store i64 %key, ptr %insert_key.ptr
  %insert_val.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 1
  store i64 %result, ptr %insert_val.ptr
  ret i64 %result
}
