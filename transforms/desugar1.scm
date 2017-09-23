#lang racket

(define map-single (lambda (f l) 
          (if (null? l) l
            (cons (f (car l)) (map-single f (cdr l))))))

(define desugar-and (lambda (ast)
          (if (null? ast)
            #t
            (if (null? (cdr ast))
              (car ast)
              (list 'if (transform (car ast))
                    (desugar-and (cdr ast))
                    #f)))))

(define desugar-or (lambda (ast)
          (if (null? ast)
            #f
            (if (null? (cdr ast))
              (car ast)
              ((lambda (sym) 
                (list 'let (list(list sym (transform (car ast))))
                      (list 'if sym sym (desugar-or (cdr ast))))) (gensym))))))

(define desugar-let (lambda (ast)
        (define variable-list (car ast))
        (define body (transform (cdr ast)))
        (define variable-names (map-single car variable-list))
        (define variable-values (map-single transform
                                            (map-single cadr
                                                        variable-list)))
        (cons (cons ( 'lambda (cons variable-names '())))
              variable-values)))

(define desugar-cond (lambda (ast)
          (if (null? ast)
            #f
            (if (eq? (caar ast) 'else)
              (cdar ast)
              (list 'if (transform (caar ast))
                    (cons 'begin (map-single transform (cdar ast)))
                    (desugar-cond (cdr ast)))))))


(define desugar-define (lambda (ast)
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
    (cons 'and desugar-and)
    (cons 'or desugar-or)
    (cons 'cond desugar-cond)
    (cons 'define desugar-define)))


(define transform (lambda (ast)
  (if (pair? ast)
    (if (symbol? (car ast))
      (let ((f (assq (car ast) transform-list )))
        (if f
          ((cdr f) (cdr ast))
          (cons (car ast) (map-single transform (cdr ast)))))
      (map-single transform ast))
    ast)))


(transform ( quote (define (a l) l) ))

          

