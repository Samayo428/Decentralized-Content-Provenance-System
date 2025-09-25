;; Decentralized Content Provenance System
;; A Clarity smart contract for tracking digital content ownership and provenance on the Stacks blockchain

;; Data structures
(define-map content-registry
  { content-hash: (buff 32) }
  {
    creator: principal,
    title: (string-utf8 256),
    timestamp: uint,
    description: (string-utf8 1024),
    license-type: (string-utf8 64),
    version: uint,
    previous-hash: (optional (buff 32))
  }
)

(define-map creator-contents
  { creator: principal }
  { content-list: (list 100 (buff 32)) }
)

(define-map license-types
  { license-id: (string-utf8 64) }
  { 
    description: (string-utf8 512),
    terms-url: (string-utf8 256)
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-REGISTERED u2)
(define-constant ERR-NOT-FOUND u3)
(define-constant ERR-LICENSE-NOT-FOUND u4)
