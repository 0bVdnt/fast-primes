declare ptr @mmap(ptr, i64, i64, i64, i64, i64)

; Populates primes array and pi_table[x] for x <= limit
define weak_odr i64 @init_sieve_cache(i64 %limit, ptr %pi_table, ptr %primes) {
entry:
    ; Allocate a temporary byte array for the sieve (1 byte per number)
    ; PROT_READ | PROT_WRITE = 3, MAP_PRIVATE | MAP_ANONYMOUS = 34 (0x22)
  %sieve = tail call ptr @mmap(ptr null, i64 %limit, i64 3, i64 34, i64 -1, i64 0)

  ; 0 and 1 are not prime
  %ptr.0 = getelementptr i8, ptr %sieve, i64 0
  store i8 1, ptr %ptr.0
  %ptr.1 = getelementptr i8, ptr %sieve, i64 1
  store i8 1, ptr %ptr.1

  ; pi_table[0] = 0, pi_table[1] = 0
  %pi.0 = getelementptr i64, ptr %pi_table, i64 0
  store i64 0, ptr %pi.0
  %pi.1 = getelementptr i64, ptr %pi_table, i64 1
  store i64 0, ptr %pi.1

  br label %sieve_loop

sieve_loop:
  %p = phi i64 [ 2, %entry ], [ %p.next, %sieve_latch ]
  %prime_count = phi i64 [ 0, %entry ], [ %prime_count.next, %sieve_latch ]
  
  %done = icmp ugt i64 %p, %limit
  br i1 %done, label %exit, label %check_prime

check_prime:
  %p.ptr = getelementptr i8, ptr %sieve, i64 %p
  %is_comp = load i8, ptr %p.ptr
  %is_prime = icmp eq i8 %is_comp, 0
  br i1 %is_prime, label %found_prime, label %record_pi

found_prime:
  ; primes[prime_count] = p
  %prime.store = getelementptr i64, ptr %primes, i64 %prime_count
  store i64 %p, ptr %prime.store
  %prime_count.inc = add i64 %prime_count, 1

  ; mark multiples
  %p.sqr = mul i64 %p, %p
  br label %mark_loop

mark_loop:
  %mult = phi i64 [ %p.sqr, %found_prime ], [ %mult.next, %mark_step ]
  %mark.done = icmp ugt i64 %mult, %limit
  br i1 %mark.done, label %record_pi, label %mark_step

mark_step:
  %mult.ptr = getelementptr i8, ptr %sieve, i64 %mult
  store i8 1, ptr %mult.ptr
  %mult.next = add i64 %mult, %p
  br label %mark_loop

record_pi:
  %prime_count.next = phi i64 [ %prime_count, %check_prime ], [ %prime_count.inc, %mark_loop ]
  %pi.ptr = getelementptr i64, ptr %pi_table, i64 %p
  store i64 %prime_count.next, ptr %pi.ptr
  br label %sieve_latch

sieve_latch:
  %p.next = add i64 %p, 1
  br label %sieve_loop

exit:
  ret i64 %prime_count
}
