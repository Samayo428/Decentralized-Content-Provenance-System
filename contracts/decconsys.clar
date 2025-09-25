;; Decentralized Content Provenance System
;; A Clarity smart contract for tracking digital content ownership and provenance on the Stacks blockchain

;; Contract initialization (moved to top)
(define-data-var contract-owner principal tx-sender)

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
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
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
      (contents-list (default-to (list) (get content-list (map-get? creator-contents { creator: creator }))))
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
    
    ;; Update creator's content list
    (map-set creator-contents
      { creator: creator }
      { content-list: (unwrap-panic (as-max-len? (append contents-list content-hash) u100)) }
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
      (contents-list (default-to (list) (get content-list (map-get? creator-contents { creator: creator }))))
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
      { content-list: (unwrap-panic (as-max-len? (append contents-list new-hash) u100)) }
    )
    
    (ok true)
  )
)

;; Allow transfer of contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read-only functions

;; Get content information by hash
(define-read-only (get-content-info (content-hash (buff 32)))
  (map-get? content-registry { content-hash: content-hash })
)

;; Get all content by a creator
(define-read-only (get-creator-content-list (creator principal))
  (map-get? creator-contents { creator: creator })
)

;; Get license type details
(define-read-only (get-license-details (license-id (string-utf8 64)))
  (map-get? license-types { license-id: license-id })
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Get the previous version hash of content
(define-read-only (get-previous-version (content-hash (buff 32)))
  (match (map-get? content-registry { content-hash: content-hash })
    content-data (ok (get previous-hash content-data))
    (err ERR-NOT-FOUND)
  )
)

;; Check if content exists
(define-read-only (content-exists (content-hash (buff 32)))
  (is-some (map-get? content-registry { content-hash: content-hash }))
)

;; Get content version number
(define-read-only (get-content-version (content-hash (buff 32)))
  (match (map-get? content-registry { content-hash: content-hash })
    content-data (ok (get version content-data))
    (err ERR-NOT-FOUND)
  )
)