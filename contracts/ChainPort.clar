;; ChainPort - Cross-chain token bridge and governance contract

;; Define the fungible token first
(define-fungible-token chainport-token)

;; Constants
(define-constant MAX-SUPPLY (* u21000000000 u1000000)) ;; 21 billion tokens with 6 decimals
(define-constant TOKEN-NAME "ChainPort Token")
(define-constant TOKEN-SYMBOL "CPT")
(define-constant TOKEN-DECIMALS u6)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))
(define-constant ERR_BURN_FAILED (err u1002))
(define-constant ERR_MINT_FAILED (err u1003))
(define-constant ERR_NOT_AUTHORIZED (err u1004))
(define-constant ERR_INVALID_AMOUNT (err u1005))

;; Data variables
(define-data-var token-name (string-ascii 32) TOKEN-NAME)
(define-data-var token-symbol (string-ascii 10) TOKEN-SYMBOL)
(define-data-var token-decimals uint TOKEN-DECIMALS)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; SIP-010 Fungible Token Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_UNAUTHORIZED)
    (asserts! (<= amount (ft-get-balance chainport-token sender)) ERR_INSUFFICIENT_BALANCE)
    (ft-transfer? chainport-token amount sender recipient)
  )
)

(define-public (get-name)
  (ok (var-get token-name))
)

(define-public (get-symbol)
  (ok (var-get token-symbol))
)

(define-public (get-decimals)
  (ok (var-get token-decimals))
)

(define-public (get-balance (who principal))
  (ok (ft-get-balance chainport-token who))
)

(define-public (get-total-supply)
  (ok (ft-get-supply chainport-token))
)

(define-public (get-token-uri)
  (ok (var-get token-uri))
)

;; Permit functionality
(define-map permits
  (tuple (owner principal) (spender principal))
  { nonce: uint, deadline: uint, amount: uint, signature: (buff 65) })

(define-public (permit-transfer
    (owner principal)
    (spender principal)
    (amount uint)
    (deadline uint)
    (signature (buff 65))
  )
  (begin
    ;; Example validation (you should add signature verification logic here)
    (asserts! (< stacks-block-height deadline) (err u900))

    ;; Store the permit
    (map-set permits
      (tuple (owner owner) (spender spender))
      {
        nonce: u0,
        deadline: deadline,
        amount: amount,
        signature: signature
      }
    )

    (print {
      event: "PermitGranted",
      owner: owner,
      spender: spender,
      amount: amount,
      deadline: deadline
    })

    (ok true)
  )
)

;; Vault functionality for token locking
(define-map vaults principal
  { amount: uint, unlock-height: uint })

(define-public (lock-tokens (amount uint) (lock-period uint))
  (begin
    (asserts! (>= (ft-get-balance chainport-token tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
    (unwrap! (ft-burn? chainport-token amount tx-sender) ERR_BURN_FAILED)

    (let ((current-height stacks-block-height)
          (unlock-height (+ stacks-block-height lock-period)))
      (map-set vaults tx-sender {
        amount: amount,
        unlock-height: unlock-height
      })

      (print {
        event: "TokensLocked",
        sender: tx-sender,
        amount: amount,
        until: unlock-height
      })

      (ok true)
    )
  )
)

(define-public (unlock-tokens)
  (match (map-get? vaults tx-sender)
    vault
    (let ((amt (get amount vault)))
      (begin
        (asserts! (>= stacks-block-height (get unlock-height vault)) (err u910))
        (unwrap! (ft-mint? chainport-token amt tx-sender) ERR_MINT_FAILED)
        (map-delete vaults tx-sender)
        (print { event: "TokensUnlocked", sender: tx-sender, amount: amt })
        (ok amt)))
    (err u911)))

;; Governance functionality
(define-map proposals uint
  {
    proposer: principal,
    title: (string-utf8 64),
    description: (string-utf8 256),
    votes-for: uint,
    votes-against: uint,
    end-height: uint,
    executed: bool
  })

(define-map proposal-votes
  (tuple (proposal-id uint) (voter principal))
  bool)

(define-data-var proposal-counter uint u0)

(define-public (propose (title (string-utf8 64)) (description (string-utf8 256)) (duration uint))
  (let ((pid (var-get proposal-counter)))
    (map-set proposals pid {
      proposer: tx-sender,
      title: title,
      description: description,
      votes-for: u0,
      votes-against: u0,
      end-height: (+ stacks-block-height duration),
      executed: false
    })
    (var-set proposal-counter (+ pid u1))
    (print { event: "ProposalCreated", id: pid, proposer: tx-sender })
    (ok pid)))

(define-public (vote (proposal-id uint) (support bool))
  (begin
    (asserts! (not (default-to false (map-get? proposal-votes (tuple (proposal-id proposal-id) (voter tx-sender))))) (err u920))
    (match (map-get? proposals proposal-id)
      proposal
      (begin
        (asserts! (< stacks-block-height (get end-height proposal)) (err u921))
        (let ((weight (ft-get-balance chainport-token tx-sender)))
          (map-set proposal-votes (tuple (proposal-id proposal-id) (voter tx-sender)) true)
          (if support
            (map-set proposals proposal-id (merge proposal { votes-for: (+ (get votes-for proposal) weight) }))
            (map-set proposals proposal-id (merge proposal { votes-against: (+ (get votes-against proposal) weight) })))
          (print { event: "VoteCast", voter: tx-sender, proposal-id: proposal-id, support: support, weight: weight })
          (ok true)))
      (err u922))))

;; Admin functionality
(define-map pending-admin-actions uint
  {
    action-type: (string-ascii 32),
    target: principal,
    amount: (optional uint),
    signatures: (list 10 principal),
    executed: bool
  })

(define-data-var required-signatures uint u3)
(define-data-var admin-action-counter uint u0)

(define-public (execute-admin-action (id uint))
  (begin
    (match (map-get? pending-admin-actions id)
      action
      (begin
        (asserts! (not (get executed action)) (err u930))
        (let ((signatures (get signatures action)))
          (asserts! (>= (len signatures) (var-get required-signatures)) ERR_NOT_AUTHORIZED)
          ;; Implement actual action here, like adding an operator/admin
          (map-set pending-admin-actions id (merge action { executed: true }))
          (print { event: "AdminActionExecuted", id: id })
          (ok true)))
      (err u931))))

;; Fee calculation based on user tiers
(define-map user-tiers principal uint) ;; e.g., u1 = basic, u2 = gold

(define-read-only (calculate-fee (user principal) (amount uint))
  (let ((tier (default-to u1 (map-get? user-tiers user))))
    (if (is-eq tier u1)
      (ok (/ amount u100))         ;; 1% fee for basic tier
      (if (is-eq tier u2)
        (ok (/ amount u200))       ;; 0.5% fee for gold tier
        (if (is-eq tier u3)
          (ok (/ amount u500))     ;; 0.2% fee for platinum tier
          (ok (/ amount u100))     ;; default fallback: 1%
        )
      )
    )
  )
) ;; default fallback

;; Audit logging
(define-map audit-log uint {
  user: principal,
  action: (string-ascii 32),
  amount: (optional uint),
  chain: (optional (string-ascii 20)),
  timestamp: uint
})

(define-data-var audit-id uint u0)

(define-private (log-audit (user principal) (action (string-ascii 32)) (amount (optional uint)) (chain (optional (string-ascii 20))))
  (let ((id (var-get audit-id)))
    (map-set audit-log id {
      user: user,
      action: action,
      amount: amount,
      chain: chain,
      timestamp: stacks-block-height
    })
    (var-set audit-id (+ id u1))
    (ok id)))

;; Initialize contract with some tokens for testing
(define-public (initialize)
  (begin
    (unwrap! (ft-mint? chainport-token u1000000000 tx-sender) ERR_MINT_FAILED)
    (ok true)
  ))