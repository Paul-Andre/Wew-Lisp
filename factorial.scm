(((lambda (f)
    ((lambda (s) (f (lambda (x) ((s s) x) ))
     (lambda (s) (f (lambda (x) ((s s) x) ))))))
  (lambda (rec)
    (lambda (n)
      (if (= n 0)
        1
        (rec (- n 1))))))
 5)
