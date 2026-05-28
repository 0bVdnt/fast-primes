; Flat-Memory Hash Table Entry: { i64 key, i64 value }
; phi_table layout: [7 x [30031 x i64]] (1,681,736 bytes total)
; modulus = 30030

define weak_odr i64 @phi_eval(i64 %x, i64 %a, ptr %phi_table, ptr %primes, ptr %hash_table) {
entry:
  ; If a <= 6, use the precomputed 2D fast-path array
  %is_small = icmp ule i64 %a, 6
  br i1 %is_small, label %table_lookup, label %cache_lookup

table_lookup:
  ; idx_base = a * 30031 (row offset)
  %idx_base = mul i64 %a, 30031
  %blocks = udiv i64 %x, 30030
  %rem = urem i64 %x, 30030

  ; val_modulus = phi_table[a][30030]
  %mod_idx = add i64 %idx_base, 30030
  %mod_ptr = getelementptr i64, ptr %phi_table, i64 %mod_idx
  %val_modulus = load i64, ptr %mod_ptr

  ; val_rem = phi_table[a][rem]
  %rem_idx = add i64 %idx_base, %rem
  %rem_ptr = getelementptr i64, ptr %phi_table, i64 %rem_idx
  %val_rem = load i64, ptr %rem_ptr

  ; return (block * val_modulus) + val_rem
  %block_val = mul i64 %blocks, %val_modulus
  %table_res = add i64 %block_val, %val_rem
  ret i64 %table_res

cache_lookup:
  ; Construct 64-bit hash key:  (x << 8) | a
  ; (Since 'a' never exceeds 128 in Lehmer, it safely fits in teh lower 8 bits)
  %x_shl = shl i64 %x, 8
  %key = or i64 %x_shl, %a

  ; Hash Function: SplitMix64 style multiplication
  %hash = mul i64 %key, -7046029254386353131 ; 0x9E3779B97F4A7C15
  br label %probe_read

probe_read:
  %probe_idx = phi i64 [ %hash, %cache_lookup ], [ %probe_next, %probe_step ]
  
  ; Mask with 0xFFFFFF (16,777,215) to bind within the 16M entry hash table
  %idx = and i64 %probe_idx, 16777215
  %entry_ptr = getelementptr { i64, i64 }, ptr %hash_table, i64 %idx
  
  %stored_key.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 0
  %stored_key = load i64, ptr %stored_key.ptr

  ; If slot is empty (key == 0), cache miss -> proceed to compute
  %is_empty = icmp eq i64 %stored_key, 0
  br i1 %is_empty, label %compute, label %check_match

check_match:
  ; If keys match, cache hit -> return value
  %is_match = icmp eq i64 %stored_key, %key
  br i1 %is_match, label %cache_hit, label %probe_step

probe_step:
  ; Linear Probing: index + 1
  %probe_next = add i64 %probe_idx, 1
  br label %probe_read

cache_hit:
  %stored_val.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 1
  %stored_val = load i64, ptr %stored_val.ptr
  ret i64 %stored_val

compute:
  ; Cache miss: compute phi(x, 6) as the baseline
  %base = tail call i64 @phi_eval(i64 %x, i64 6, ptr %phi_table, ptr %primes, ptr %hash_table)
  br label %compute_loop

compute_loop:
  ; result = base - sum(phi_eval(x / primes[i], i)) for i in 6..(a - 1)
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
  ; Save the computed result into the empty hash slot found earlier
  %insert_key.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 0
  store i64 %key, ptr %insert_key.ptr
  
  %insert_val.ptr = getelementptr { i64, i64 }, ptr %entry_ptr, i32 0, i32 1
  store i64 %result, ptr %insert_val.ptr
  
  ret i64 %result
}
