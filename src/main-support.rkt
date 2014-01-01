#lang racket/gui
(require racket/lazy-require)
(require net/dns)
(require "l10n.rkt")
(lazy-require ("main.rkt"
               (events/set-status
                draw-data
                events/switch-tpane
                disable-cbutton
                enable-cbutton)))



(provide (all-defined-out))