#lang racket

(require racket/match)

(define (insert key value l)
  (cons (cons key value) l))

(define (get-value key l)
  (cond 
    ((null? l) #f)
    ((equal? (caar l) key) (cdar l))
    (else (get-value key (cdr l)))))

(define (replace list-of-names l) 
  (if (null? list-of-names) l
    (cons (cons (car list-of-names)
                (gensym (car list-of-names)))
          l)))

(define (alphatize ast replacements)
  (match ast
         (`(lambda ,argument . ,body)
          (let ((new-replacements (replace argument replacements)))
          `(lambda ,(alphatize argument new-replacements);; ahhh this repeats work stupidly
             . ,(alphatize body new-replacements))))
         ((? symbol? symbol) (begin
                               (print replacements)
                               (newline)
                               (let
                                 ((value (get-value symbol replacements)))
                                 (if value value symbol))))
         ((? list?) (map (lambda (x) (alphatize x replacements)) ast))
         (something-else something-else)))


(write (alphatize '(lambda (x)
                     x
                     (lambda (x)
                             x))

                  '()))


