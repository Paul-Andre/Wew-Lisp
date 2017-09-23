(define factorial (lambda (n) 
                    (if (<= n 1) 1
                      (* n (factorial (- n 1))))))

(list (factorial 1)
      (factorial 2)
      (factorial 3))

