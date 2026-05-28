; Fast precise integer square root
define weak_odr i64 @isqrt(i64 %n) {
entry:
  %cmp = icmp eq i64 %n, 0
  br i1 %cmp, label %return, label %calc
calc:
  %lz = tail call i64 @llvm.ctlz.i64(i64 %n, i1 true)
  %active = sub i64 64, %lz

  ; Force round-up for the initial shift in order to always start >= the actual root.
  ; This ensures Newton's method converges monotonically downwards.
  %active.plus1 = add i64 %active, 1
  %shift = lshr i64 %active.plus1, 1
  %guess.init = shl i64 1, %shift
  br label %loop

loop:
  %guess = phi i64 [ %guess.init, %calc ], [%guess.next, %loop ]
  %div = udiv i64 %n, %guess
  %add = add i64 %guess, %div
  %guess.next = lshr i64 %add, 1
  %converged = icmp uge i64 %guess.next, %guess
  br i1 %converged, label %return, label %loop

return:
  %res = phi i64 [ 0, %entry ], [ %guess, %loop ]
  ret i64 %res
}

; Precise integer cube root using binary search
define weak_odr i64 @icbrt(i64 %n) {
entry:
  %cmp = icmp eq i64 %n, 0
  br i1 %cmp, label %return, label %search

search:
  br label %loop

loop:
  %low = phi i64 [ 1, %search ], [ %low.keep, %check_high ], [ %low.next, %check_low ]
  %high = phi i64 [ 2097151, %search ], [ %high.next, %check_high ], [ %high.keep, %check_low ]
  
  %diff = sub i64 %high, %low
  %done = icmp ule i64 %diff, 1
  br i1 %done, label %return, label %step

step:
  %mid = lshr i64 %diff, 1
  %guess = add i64 %low, %mid
  %sq = mul i64 %guess, %guess
  %cube = mul i64 %sq, %guess

  %too_big = icmp ugt i64 %cube, %n
  br i1 %too_big, label %check_high, label %check_low

check_high:
  %low.keep = phi i64 [ %guess, %step ]
  %high.next = phi i64 [ %high, %step ]
  br label %loop

check_low:
  %low.next = phi i64 [ %guess, %step ]
  %high.keep = phi i64 [ %high, %step ]
  br label %loop

return:
  %res = phi i64 [ 0, %entry ], [ %low, %loop ]
  ret i64 %res
}

; Precise integer fourth root (isqrt(isqrt(x)))
define weak_odr i64 @iroot4(i64 %n) {
entry:
  %root2 = tail call i64 @isqrt(i64 %n)
  %root4 = tail call i64 @isqrt(i64 %root2)
  ret i64 %root4
}

declare i64 @llvm.ctlz.i64(i64, i1)
