;; Decentralized Content Provenance System
;; A Clarity smart contract for tracking digital content ownership and provenance on the Stacks blockchain

;; Contract owner
(define-constant contract-owner tx-sender)

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

;; Public functions

;; Register a new license type
(define-public (register-license-type (license-id (string-utf8 64)) (description (string-utf8 512)) (terms-url (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR-NOT-AUTHORIZED))
    (map-insert license-types
      { license-id: license-id }
      {
        description: description,
        terms-url: terms-url
      }
    )
    (ok true)
  )
)

;; Register new content
(define-public (register-content 
  (content-hash (buff 32))
  (title (string-utf8 256))
  (description (string-utf8 1024))
  (license-type (string-utf8 64))
  (previous-hash (optional (buff 32))))
  
  (let
    (
      (creator tx-sender)
      (timestamp (default-to u0 (get-block-info? time (- block-height u1))))
      (current-contents (default-to (list) (get content-list (map-get? creator-contents { creator: creator }))))
    )
    
    ;; Verify the content isn't already registered
    (asserts! (is-none (map-get? content-registry { content-hash: content-hash })) (err ERR-ALREADY-REGISTERED))
    
    ;; Verify license type exists
    (asserts! (is-some (map-get? license-types { license-id: license-type })) (err ERR-LICENSE-NOT-FOUND))
    
    ;; Register the content
    (map-set content-registry
      { content-hash: content-hash }
      {
        creator: creator,
        title: title,
        timestamp: timestamp,
        description: description,
        license-type: license-type,
        version: u1,
        previous-hash: previous-hash
      }
    )
    
    ;; Update creator's content list (using unwrap-panic for simplicity, consider better error handling)
    (map-set creator-contents
      { creator: creator }
      { content-list: (unwrap-panic (as-max-len? (append current-contents content-hash) u100)) }
    )
    
    (ok true)
  )
)
;; Update existing content (create a new version)
(define-public (update-content 
  (original-hash (buff 32))
  (new-hash (buff 32)) 
  (title (string-utf8 256))
  (description (string-utf8 1024))
  (license-type (string-utf8 64)))
  
  (let
    (
      (content (map-get? content-registry { content-hash: original-hash }))
      (creator tx-sender)
      (timestamp (default-to u0 (get-block-info? time (- block-height u1))))
      (current-contents (default-to (list) (get content-list (map-get? creator-contents { creator: creator }))))
    )
    
    ;; Verify original content exists
    (asserts! (is-some content) (err ERR-NOT-FOUND))
    
    ;; Verify sender is the original creator
    (asserts! (is-eq creator (get creator (unwrap-panic content))) (err ERR-NOT-AUTHORIZED))
    
    ;; Verify license type exists
    (asserts! (is-some (map-get? license-types { license-id: license-type })) (err ERR-LICENSE-NOT-FOUND))
    
    ;; Verify the new hash isn't already registered
    (asserts! (is-none (map-get? content-registry { content-hash: new-hash })) (err ERR-ALREADY-REGISTERED))
    
    ;; Register the new version
    (map-set content-registry
      { content-hash: new-hash }
      {
        creator: creator,
        title: title,
        timestamp: timestamp,
        description: description,
        license-type: license-type,
        version: (+ u1 (get version (unwrap-panic content))),
        previous-hash: (some original-hash)
      }
    )
    
    ;; Update creator's content list
    (map-set creator-contents
      { creator: creator }
      { content-list: (unwrap-panic (as-max-len? (append current-contents new-hash) u100)) }
    )
    
    (ok true)
  )
)