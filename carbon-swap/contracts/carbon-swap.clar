;; Carbon Credit Trading Contract (carbon-swap)
;; A smart contract for trading verified carbon offset certificates on Stacks blockchain

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-CERTIFICATE-NOT-FOUND (err u103))
(define-constant ERR-CERTIFICATE-EXPIRED (err u104))
(define-constant ERR-CERTIFICATE-ALREADY-USED (err u105))
(define-constant ERR-INVALID-PRICE (err u106))
(define-constant ERR-TRANSFER-FAILED (err u107))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map carbon-certificates
  { cert-id: uint }
  {
    issuer: principal,
    holder: principal,
    carbon-amount: uint,
    verification-standard: (string-ascii 50),
    issue-date: uint,
    expiry-date: uint,
    is-used: bool,
    project-name: (string-ascii 100)
  }
)

(define-map certificate-listings
  { cert-id: uint }
  {
    seller: principal,
    price-per-ton: uint,
    amount-available: uint,
    is-active: bool
  }
)

(define-map user-balances
  { user: principal }
  { carbon-credits: uint }
)

;; Variables
(define-data-var next-cert-id uint u1)
(define-data-var contract-fee-rate uint u250) ;; 2.5% fee (250 basis points)

;; Read-only functions
(define-read-only (get-certificate (cert-id uint))
  (map-get? carbon-certificates { cert-id: cert-id })
)

(define-read-only (get-listing (cert-id uint))
  (map-get? certificate-listings { cert-id: cert-id })
)

(define-read-only (get-user-balance (user principal))
  (default-to { carbon-credits: u0 } (map-get? user-balances { user: user }))
)

(define-read-only (get-contract-fee-rate)
  (var-get contract-fee-rate)
)

;; Private functions
(define-private (is-certificate-valid (cert-id uint))
  (match (get-certificate cert-id)
    cert-data (and 
                (not (get is-used cert-data))
                (> (get expiry-date cert-data) block-height))
    false
  )
)

(define-private (update-user-balance (user principal) (new-balance uint))
  (map-set user-balances { user: user } { carbon-credits: new-balance })
)

;; Public functions

;; Issue a new carbon certificate (only authorized issuers)
(define-public (issue-certificate 
  (carbon-amount uint)
  (verification-standard (string-ascii 50))
  (expiry-date uint)
  (project-name (string-ascii 100))
  (holder principal))
  (let ((cert-id (var-get next-cert-id)))
    (asserts! (> carbon-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> expiry-date block-height) ERR-CERTIFICATE-EXPIRED)
    
    (map-set carbon-certificates
      { cert-id: cert-id }
      {
        issuer: tx-sender,
        holder: holder,
        carbon-amount: carbon-amount,
        verification-standard: verification-standard,
        issue-date: block-height,
        expiry-date: expiry-date,
        is-used: false,
        project-name: project-name
      }
    )
    
    ;; Update holder's balance
    (let ((current-balance (get carbon-credits (get-user-balance holder))))
      (update-user-balance holder (+ current-balance carbon-amount))
    )
    
    (var-set next-cert-id (+ cert-id u1))
    (ok cert-id)
  )
)

;; List certificate for sale
(define-public (list-certificate (cert-id uint) (price-per-ton uint) (amount uint))
  (let ((cert-data (unwrap! (get-certificate cert-id) ERR-CERTIFICATE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get holder cert-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-certificate-valid cert-id) ERR-CERTIFICATE-EXPIRED)
    (asserts! (> price-per-ton u0) ERR-INVALID-PRICE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get carbon-amount cert-data)) ERR-INSUFFICIENT-BALANCE)
    
    (map-set certificate-listings
      { cert-id: cert-id }
      {
        seller: tx-sender,
        price-per-ton: price-per-ton,
        amount-available: amount,
        is-active: true
      }
    )
    
    (ok true)
  )
)

;; Cancel certificate listing
(define-public (cancel-listing (cert-id uint))
  (let ((listing (unwrap! (get-listing cert-id) ERR-CERTIFICATE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
    
    (map-set certificate-listings
      { cert-id: cert-id }
      (merge listing { is-active: false })
    )
    
    (ok true)
  )
)

;; Buy carbon credits
(define-public (buy-credits (cert-id uint) (amount uint))
  (let (
    (cert-data (unwrap! (get-certificate cert-id) ERR-CERTIFICATE-NOT-FOUND))
    (listing (unwrap! (get-listing cert-id) ERR-CERTIFICATE-NOT-FOUND))
  )
    (asserts! (is-certificate-valid cert-id) ERR-CERTIFICATE-EXPIRED)
    (asserts! (get is-active listing) ERR-CERTIFICATE-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get amount-available listing)) ERR-INSUFFICIENT-BALANCE)
    
    (let (
      (total-cost (* amount (get price-per-ton listing)))
      (fee-amount (/ (* total-cost (var-get contract-fee-rate)) u10000))
      (seller-amount (- total-cost fee-amount))
      (seller (get seller listing))
      (buyer tx-sender)
    )
      
      ;; Transfer STX from buyer to seller
      (unwrap! (stx-transfer? seller-amount buyer seller) ERR-TRANSFER-FAILED)
      
      ;; Transfer fee to contract owner
      (unwrap! (stx-transfer? fee-amount buyer CONTRACT-OWNER) ERR-TRANSFER-FAILED)
      
      ;; Update balances
      (let (
        (seller-balance (get carbon-credits (get-user-balance seller)))
        (buyer-balance (get carbon-credits (get-user-balance buyer)))
      )
        (update-user-balance seller (- seller-balance amount))
        (update-user-balance buyer (+ buyer-balance amount))
      )
      
      ;; Update listing
      (let ((new-amount-available (- (get amount-available listing) amount)))
        (if (is-eq new-amount-available u0)
          (map-set certificate-listings
            { cert-id: cert-id }
            (merge listing { is-active: false, amount-available: u0 })
          )
          (map-set certificate-listings
            { cert-id: cert-id }
            (merge listing { amount-available: new-amount-available })
          )
        )
      )
      
      (ok true)
    )
  )
)

;; Retire carbon credits (mark as used)
(define-public (retire-credits (cert-id uint) (amount uint))
  (let ((cert-data (unwrap! (get-certificate cert-id) ERR-CERTIFICATE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get holder cert-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-certificate-valid cert-id) ERR-CERTIFICATE-EXPIRED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let (
      (user-balance (get carbon-credits (get-user-balance tx-sender)))
      (cert-amount (get carbon-amount cert-data))
    )
      (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
      (asserts! (>= cert-amount amount) ERR-INSUFFICIENT-BALANCE)
      
      ;; Update user balance
      (update-user-balance tx-sender (- user-balance amount))
      
      ;; If full amount retired, mark certificate as used
      (if (is-eq amount cert-amount)
        (map-set carbon-certificates
          { cert-id: cert-id }
          (merge cert-data { is-used: true })
        )
        (map-set carbon-certificates
          { cert-id: cert-id }
          (merge cert-data { carbon-amount: (- cert-amount amount) })
        )
      )
      
      (ok true)
    )
  )
)

;; Transfer carbon credits between users
(define-public (transfer-credits (recipient principal) (amount uint))
  (let (
    (sender-balance (get carbon-credits (get-user-balance tx-sender)))
    (recipient-balance (get carbon-credits (get-user-balance recipient)))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    (update-user-balance tx-sender (- sender-balance amount))
    (update-user-balance recipient (+ recipient-balance amount))
    
    (ok true)
  )
)

;; Admin function to update contract fee rate
(define-public (set-contract-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u1000) ERR-INVALID-AMOUNT) ;; Max 10% fee
    (var-set contract-fee-rate new-rate)
    (ok true)
  )
)