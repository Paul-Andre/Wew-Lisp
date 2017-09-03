#lang racket

(define do-and (lambda (ast)
          (if (null? ast)
            #t
            (if (null? (cdr ast))
              (car ast)
              (list 'if (transform (car ast))
                    (do-and (cdr ast))
                    #f)))))

(define do-or (lambda (ast)
          (if (null? ast)
            #f
            (if (null? (cdr ast))
              (car ast)
              (let ((sym (gensym)))
                (list 'let (list(list sym (transform (car ast))))
                      (list 'if sym sym (do-or (cdr ast)))))))))

(define do-cond (lambda (ast)
          (if (null? ast)
            #f
            (if (eq? (caar ast) 'else)
              (cdar ast)
              (list 'if (transform (caar ast))
                    (cons 'begin (map transform (cdar ast)))
                    (do-cond (cdr ast)))))))

(define do-not (lambda (ast)
              (list 'if ast #f #t)))

#;
(define do-define (lambda (ast)
                    (if (pair? (car ast))
                      (list 'define (caar ast)
                            (list lambda (cdar ast) (cdr ast))))))


(define transform-list
  (list
    (cons 'and do-and)
    (cons 'or do-or)
    (cons 'cond do-cond)
    (cons 'not do-not)))


(define transform (lambda (ast)
  (if (pair? ast)
    (if (symbol? (car ast))
      (let ((f (assq (car ast) transform-list )))
        (if f
          ((cdr f) (cdr ast))
          (cons (car ast) (map transform (cdr ast)))))
      (map transform ast))
    ast)))


(write (transform '(cond ((= x 3)  'good)
                         ((and (not (< 4 x)) (> 10 x)) 'quite-good)
                         (else 'something-else))))

          

