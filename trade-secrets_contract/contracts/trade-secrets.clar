
;; title: trade-secrets
;; version: 1.0.0
;; summary: IP registry smart contract for confidential business information and trade secret protection
;; description: This contract provides a secure registry for trade secrets, allowing companies to establish
;; ownership and protection of confidential business information on the Stacks blockchain.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; data vars
(define-data-var next-trade-secret-id uint u1)

;; data maps
;; Main registry for trade secrets
(define-map trade-secrets
  { trade-secret-id: uint }
  {
    owner: principal,
    title: (string-ascii 100),
    description-hash: (buff 32),  ;; SHA256 hash of the actual trade secret description
    category: (string-ascii 50),
    registration-date: uint,
    last-updated: uint,
    is-active: bool,
    confidentiality-level: uint   ;; 1-5 scale
  }
)

;; Map to track authorized access to trade secrets
(define-map authorized-access
  { trade-secret-id: uint, accessor: principal }
  {
    granted-by: principal,
    granted-date: uint,
    access-level: uint,  ;; 1=view metadata, 2=view description hash, 3=full access
    expiry-date: (optional uint)
  }
)

;; Map to track trade secret ownership history
(define-map ownership-history
  { trade-secret-id: uint, sequence: uint }
  {
    previous-owner: (optional principal),
    new-owner: principal,
    transfer-date: uint,
    reason: (string-ascii 100)
  }
)

;; Map for dispute resolution
(define-map disputes
  { dispute-id: uint }
  {
    trade-secret-id: uint,
    challenger: principal,
    dispute-reason: (string-ascii 200),
    dispute-date: uint,
    status: (string-ascii 20),  ;; "open", "resolved", "dismissed"
    resolver: (optional principal)
  }
)

;; Counter for disputes
(define-data-var next-dispute-id uint u1)

;; public functions

;; Register a new trade secret
(define-public (register-trade-secret
  (title (string-ascii 100))
  (description-hash (buff 32))
  (category (string-ascii 50))
  (confidentiality-level uint))
  (let (
    (trade-secret-id (var-get next-trade-secret-id))
    (current-block-height block-height)
  )
    ;; Validate inputs
    (asserts! (> (len title) u0) err-invalid-input)
    (asserts! (> (len category) u0) err-invalid-input)
    (asserts! (and (>= confidentiality-level u1) (<= confidentiality-level u5)) err-invalid-input)

    ;; Trade secret ID is auto-generated, so no need to check for existence

    ;; Register the trade secret
    (map-set trade-secrets
      { trade-secret-id: trade-secret-id }
      {
        owner: tx-sender,
        title: title,
        description-hash: description-hash,
        category: category,
        registration-date: current-block-height,
        last-updated: current-block-height,
        is-active: true,
        confidentiality-level: confidentiality-level
      }
    )

    ;; Record initial ownership
    (map-set ownership-history
      { trade-secret-id: trade-secret-id, sequence: u0 }
      {
        previous-owner: none,
        new-owner: tx-sender,
        transfer-date: current-block-height,
        reason: "Initial registration"
      }
    )

    ;; Increment counter
    (var-set next-trade-secret-id (+ trade-secret-id u1))

    (ok trade-secret-id)
  )
)

;; Transfer ownership of a trade secret
(define-public (transfer-ownership
  (trade-secret-id uint)
  (new-owner principal)
  (reason (string-ascii 100)))
  (let (
    (trade-secret (unwrap! (map-get? trade-secrets { trade-secret-id: trade-secret-id }) err-not-found))
    (current-owner (get owner trade-secret))
  )
    ;; Only current owner can transfer
    (asserts! (is-eq tx-sender current-owner) err-unauthorized)
    (asserts! (get is-active trade-secret) err-unauthorized)
    (asserts! (> (len reason) u0) err-invalid-input)

    ;; Update ownership in main registry
    (map-set trade-secrets
      { trade-secret-id: trade-secret-id }
      (merge trade-secret {
        owner: new-owner,
        last-updated: block-height
      })
    )

    ;; Record ownership transfer
    (let ((next-sequence (get-next-ownership-sequence trade-secret-id)))
      (map-set ownership-history
        { trade-secret-id: trade-secret-id, sequence: next-sequence }
        {
          previous-owner: (some current-owner),
          new-owner: new-owner,
          transfer-date: block-height,
          reason: reason
        }
      )
    )

    (ok true)
  )
)

;; Grant access to a trade secret
(define-public (grant-access
  (trade-secret-id uint)
  (accessor principal)
  (access-level uint)
  (expiry-date (optional uint)))
  (let (
    (trade-secret (unwrap! (map-get? trade-secrets { trade-secret-id: trade-secret-id }) err-not-found))
  )
    ;; Only owner can grant access
    (asserts! (is-eq tx-sender (get owner trade-secret)) err-unauthorized)
    (asserts! (get is-active trade-secret) err-unauthorized)
    (asserts! (and (>= access-level u1) (<= access-level u3)) err-invalid-input)

    ;; Grant access
    (map-set authorized-access
      { trade-secret-id: trade-secret-id, accessor: accessor }
      {
        granted-by: tx-sender,
        granted-date: block-height,
        access-level: access-level,
        expiry-date: expiry-date
      }
    )

    (ok true)
  )
)

;; Revoke access to a trade secret
(define-public (revoke-access
  (trade-secret-id uint)
  (accessor principal))
  (let (
    (trade-secret (unwrap! (map-get? trade-secrets { trade-secret-id: trade-secret-id }) err-not-found))
  )
    ;; Only owner can revoke access
    (asserts! (is-eq tx-sender (get owner trade-secret)) err-unauthorized)

    ;; Revoke access
    (map-delete authorized-access { trade-secret-id: trade-secret-id, accessor: accessor })

    (ok true)
  )
)

;; File a dispute
(define-public (file-dispute
  (trade-secret-id uint)
  (dispute-reason (string-ascii 200)))
  (let (
    (dispute-id (var-get next-dispute-id))
    (trade-secret (unwrap! (map-get? trade-secrets { trade-secret-id: trade-secret-id }) err-not-found))
  )
    ;; Validate inputs
    (asserts! (> (len dispute-reason) u0) err-invalid-input)
    (asserts! (not (is-eq tx-sender (get owner trade-secret))) err-unauthorized) ;; Owner cannot dispute their own trade secret

    ;; File dispute
    (map-set disputes
      { dispute-id: dispute-id }
      {
        trade-secret-id: trade-secret-id,
        challenger: tx-sender,
        dispute-reason: dispute-reason,
        dispute-date: block-height,
        status: "open",
        resolver: none
      }
    )

    ;; Increment counter
    (var-set next-dispute-id (+ dispute-id u1))

    (ok dispute-id)
  )
)

;; Update trade secret (owner only)
(define-public (update-trade-secret
  (trade-secret-id uint)
  (title (string-ascii 100))
  (description-hash (buff 32))
  (category (string-ascii 50))
  (confidentiality-level uint))
  (let (
    (trade-secret (unwrap! (map-get? trade-secrets { trade-secret-id: trade-secret-id }) err-not-found))
  )
    ;; Only owner can update
    (asserts! (is-eq tx-sender (get owner trade-secret)) err-unauthorized)
    (asserts! (get is-active trade-secret) err-unauthorized)

    ;; Validate inputs
    (asserts! (> (len title) u0) err-invalid-input)
    (asserts! (> (len category) u0) err-invalid-input)
    (asserts! (and (>= confidentiality-level u1) (<= confidentiality-level u5)) err-invalid-input)

    ;; Update trade secret
    (map-set trade-secrets
      { trade-secret-id: trade-secret-id }
      (merge trade-secret {
        title: title,
        description-hash: description-hash,
        category: category,
        confidentiality-level: confidentiality-level,
        last-updated: block-height
      })
    )

    (ok true)
  )
)

;; Deactivate a trade secret (soft delete)
(define-public (deactivate-trade-secret (trade-secret-id uint))
  (let (
    (trade-secret (unwrap! (map-get? trade-secrets { trade-secret-id: trade-secret-id }) err-not-found))
  )
    ;; Only owner can deactivate
    (asserts! (is-eq tx-sender (get owner trade-secret)) err-unauthorized)

    ;; Deactivate
    (map-set trade-secrets
      { trade-secret-id: trade-secret-id }
      (merge trade-secret {
        is-active: false,
        last-updated: block-height
      })
    )

    (ok true)
  )
)

;; read only functions

;; Get trade secret details
(define-read-only (get-trade-secret (trade-secret-id uint))
  (map-get? trade-secrets { trade-secret-id: trade-secret-id })
)

;; Check if caller has access to a trade secret
(define-read-only (has-access (trade-secret-id uint) (accessor principal))
  (let (
    (trade-secret (unwrap! (map-get? trade-secrets { trade-secret-id: trade-secret-id }) (ok false)))
    (access-info (map-get? authorized-access { trade-secret-id: trade-secret-id, accessor: accessor }))
  )
    ;; Owner always has access
    (if (is-eq accessor (get owner trade-secret))
      (ok true)
      (match access-info
        access-data
        ;; Check if access is still valid (not expired)
        (match (get expiry-date access-data)
          expiry
          (ok (< block-height expiry))
          (ok true)  ;; No expiry date means permanent access
        )
        (ok false)  ;; No access granted
      )
    )
  )
)

;; Get access level for a specific accessor
(define-read-only (get-access-level (trade-secret-id uint) (accessor principal))
  (match (map-get? authorized-access { trade-secret-id: trade-secret-id, accessor: accessor })
    access-data (some (get access-level access-data))
    none
  )
)

;; Get ownership history
(define-read-only (get-ownership-history (trade-secret-id uint) (sequence uint))
  (map-get? ownership-history { trade-secret-id: trade-secret-id, sequence: sequence })
)

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

;; Get total number of registered trade secrets
(define-read-only (get-total-trade-secrets)
  (- (var-get next-trade-secret-id) u1)
)

;; Get total number of disputes
(define-read-only (get-total-disputes)
  (- (var-get next-dispute-id) u1)
)

;; Check if trade secret exists and is active
(define-read-only (is-active-trade-secret (trade-secret-id uint))
  (match (map-get? trade-secrets { trade-secret-id: trade-secret-id })
    trade-secret (get is-active trade-secret)
    false
  )
)

;; private functions

;; Get next sequence number for ownership history
(define-private (get-next-ownership-sequence (trade-secret-id uint))
  (let ((current-seq u0))
    ;; This is a simplified version - in a real implementation,
    ;; you might want to maintain a separate counter per trade secret
    (+ current-seq u1)
  )
)
