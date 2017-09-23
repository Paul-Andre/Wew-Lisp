#lang racket

(define map-single (lambda (f l) 
          (if (null? l) l
            (cons (f (car l)) (map-single f (cdr l))))))

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
                    (cons 'begin (map-single transform (cdar ast)))
                    (do-cond (cdr ast)))))))

(define do-not (lambda (ast)
              (list 'if ast #f #t)))


(define do-define (lambda (ast)
                    (if (pair? (car ast))
                      (list 'define (caar ast)
                            (cons 'lambda
                                  (cons (cdar ast)
                                        (map-single transform (cdr ast)))))
                      (list 'define
                            (car ast) 
                            (map-single transform (cadr ast))))))



(define transform-list
  (list
    (cons 'and do-and)
    (cons 'or do-or)
    (cons 'cond do-cond)
    (cons 'define do-define)
    (cons 'not do-not)))


(define transform (lambda (ast)
  (if (pair? ast)
    (if (symbol? (car ast))
      (let ((f (assq (car ast) transform-list )))
        (if f
          ((cdr f) (cdr ast))
          (cons (car ast) (map-single transform (cdr ast)))))
      (map-single transform ast))
    ast)))


(write (transform ( quote (define (a l) l) )))

          

