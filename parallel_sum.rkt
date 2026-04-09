#lang racket

;; ============================================================
;; Parallel Sum — Sequential vs Concurrent List Summation
;; ============================================================

;; -----------------------------------------------------------
;; 1. Large List Generation
;; -----------------------------------------------------------
(define (make-large-list n)
  (cond
    [(= n 0) '()]
    [else (cons n (make-large-list (- n 1)))]))

;; -----------------------------------------------------------
;; 2. Sequential (Recursive) Sum
;; -----------------------------------------------------------
(define (sum-seq lst)
  (cond
    [(empty? lst) 0]
    [else (+ (first lst)
             (sum-seq (rest lst)))]))

;; -----------------------------------------------------------
;; 3. Parallel / Concurrent Sum
;; -----------------------------------------------------------

;; Helper: recursive length
(define (length-rec lst)
  (cond
    [(empty? lst) 0]
    [else (+ 1 (length-rec (rest lst)))]))

;; Helper: take first n elements
(define (take-rec lst n)
  (cond
    [(or (= n 0) (empty? lst)) '()]
    [else (cons (first lst)
                (take-rec (rest lst) (- n 1)))]))

;; Helper: drop first n elements
(define (drop-rec lst n)
  (cond
    [(or (= n 0) (empty? lst)) lst]
    [else (drop-rec (rest lst) (- n 1))]))

;; Split a list into k roughly-equal chunks
(define (split-into-k lst k)
  (let* ((len (length-rec lst))
         (chunk-size (exact-ceiling (/ len k))))
    (split-helper lst k chunk-size)))

(define (split-helper lst remaining chunk-size)
  (cond
    [(or (empty? lst) (= remaining 0)) '()]
    [else (cons (take-rec lst chunk-size)
                (split-helper (drop-rec lst chunk-size)
                              (- remaining 1)
                              chunk-size))]))

;; Sum a vector of partial results
(define (sum-vector vec len idx)
  (cond
    [(= idx len) 0]
    [else (+ (vector-ref vec idx)
             (sum-vector vec len (+ idx 1)))]))

;; Spawn one thread per chunk; each writes its partial sum into results[i]
(define (spawn-threads chunks results idx)
  (cond
    [(null? chunks) '()]
    [else
     (let ((chunk (car chunks))
           (i idx))
       (cons (thread (lambda ()
                       (vector-set! results i (sum-seq chunk))))
             (spawn-threads (cdr chunks) results (+ idx 1))))]))

;; Wait for every thread to finish
(define (join-threads ts)
  (cond
    [(null? ts) (void)]
    [else
     (thread-wait (car ts))
     (join-threads (cdr ts))]))

;; Main parallel-sum: split → spawn → join → combine
(define (parallel-sum lst k)
  (let* ((chunks    (split-into-k lst k))
         (n-chunks  (length-rec chunks))
         (results   (make-vector n-chunks 0))
         (ts        (spawn-threads chunks results 0)))
    (join-threads ts)
    (sum-vector results n-chunks 0)))

;; -----------------------------------------------------------
;; 4. Timing Utility
;; -----------------------------------------------------------
(define (measure-time-ms thunk)
  (let-values (((res cpu real gc) (time-apply thunk '())))
    real))

;; -----------------------------------------------------------
;; 5. Run Experiments & Generate Plot
;; -----------------------------------------------------------
(define LIST-SIZE 100000)
(define large-list (make-large-list LIST-SIZE))

(displayln "=== Parallel Sum Execution ===")
(displayln (string-append "List size: " (number->string LIST-SIZE)))
(displayln "")

(define seq-time (measure-time-ms (lambda () (sum-seq large-list))))
(displayln (string-append "Sequential sum time : " (number->string seq-time) " ms"))
(displayln "")

(define thread-counts (list 1 2 4 8 16 32 64))

(define (collect-parallel-times counts)
  (cond
    [(null? counts) '()]
    [else
     (let* ((k (car counts))
            (t (measure-time-ms (lambda () (parallel-sum large-list k)))))
       (displayln (string-append "Parallel sum (k=" (number->string k)
                                 " threads): " (number->string t) " ms"))
       (cons (vector k t)
             (collect-parallel-times (cdr counts))))]))

(displayln "--- Parallel timings ---")
(define plot-data (collect-parallel-times thread-counts))

(require plot)

(plot-file
 (list
  (lines  plot-data #:color 'blue  #:width 2  #:label "Parallel sum")
  (points plot-data #:color 'blue  #:sym 'fullcircle5 #:size 10)
  (hrule  seq-time  #:color 'red   #:style 'long-dash #:width 2
          #:label (string-append "Sequential: " (number->string seq-time) " ms")))
 "timing_plot.png"
 #:x-label "Number of Threads (k)"
 #:y-label "Execution Time (ms)"
 #:title   "Threads vs Execution Time (Parallel Sum)")

(displayln "")
(displayln "Plot saved to: timing_plot.png")
