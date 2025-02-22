;; Freelance Marketplace Contract

;; Data Maps and Variables
(define-map freelance-jobs
    { freelance-job-id: uint }
    {
        job-client: principal,
        job-title: (string-ascii 100),
        job-description: (string-ascii 500),
        job-budget: uint,
        job-status: (string-ascii 20),
        selected-freelancer: (optional principal),
        payment-milestones: (list 10 uint),
        active-milestone-index: uint
    }
)

(define-map freelancer-bids
    { freelance-job-id: uint, bidding-freelancer: principal }
    {
        bid-amount: uint,
        bid-proposal: (string-ascii 500),
        bid-status: (string-ascii 20)
    }
)

(define-map freelancer-ratings
    { rated-user: principal }
    {
        cumulative-rating: uint,
        rating-count: uint,
        rating-average: uint
    }
)

(define-map job-disputes
    { freelance-job-id: uint }
    {
        dispute-initiator: principal,
        dispute-reason: (string-ascii 500),
        release-payment-votes: uint,
        refund-payment-votes: uint,
        dispute-resolved: bool
    }
)

(define-map job-escrow
    { freelance-job-id: uint }
    {
        escrow-amount: uint,
        funds-locked: bool
    }
)

(define-data-var total-jobs-counter uint u0)

;; Status Constants
(define-constant JOB_STATUS_OPEN "open")
(define-constant JOB_STATUS_IN_PROGRESS "in-progress")
(define-constant JOB_STATUS_COMPLETED "completed")
(define-constant JOB_STATUS_DISPUTED "disputed")
(define-constant BID_STATUS_PENDING "pending")
(define-constant BID_STATUS_ACCEPTED "accepted")

;; Error constants
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_JOB_NOT_FOUND (err u101))
(define-constant ERR_INVALID_JOB_STATUS (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_DUPLICATE_BID (err u104))
(define-constant ERR_EXISTING_DISPUTE (err u105))
(define-constant ERR_INVALID_RATING_RANGE (err u106))
(define-constant ERR_INVALID_INPUT (err u107))
(define-constant ERR_FREELANCER_NOT_FOUND (err u108))

;; Helper functions for input validation
(define-private (is-valid-job-title (title (string-ascii 100)))
    (and (>= (len title) u1) (<= (len title) u100))
)

(define-private (is-valid-job-description (description (string-ascii 500)))
    (and (>= (len description) u1) (<= (len description) u500))
)

(define-private (is-valid-job-budget (budget uint))
    (> budget u0)
)

(define-private (is-valid-milestones (milestones (list 10 uint)))
    (and (>= (len milestones) u1) (<= (len milestones) u10))
)

(define-private (is-valid-bid-proposal (proposal (string-ascii 500)))
    (and (>= (len proposal) u1) (<= (len proposal) u500))
)

(define-private (is-valid-job-id (job-id uint))
    (<= job-id (var-get total-jobs-counter))
)

(define-private (is-valid-freelancer (freelance-job-id uint) (freelancer principal))
    (is-some (map-get? freelancer-bids { freelance-job-id: freelance-job-id, bidding-freelancer: freelancer }))
)

;; Job Management Functions

(define-public (post-freelance-job (job-title (string-ascii 100)) (job-description (string-ascii 500)) (job-budget uint) (payment-milestones (list 10 uint)))
    (begin
        (asserts! (is-valid-job-title job-title) ERR_INVALID_INPUT)
        (asserts! (is-valid-job-description job-description) ERR_INVALID_INPUT)
        (asserts! (is-valid-job-budget job-budget) ERR_INVALID_INPUT)
        (asserts! (is-valid-milestones payment-milestones) ERR_INVALID_INPUT)
        (let
            (
                (new-job-id (+ (var-get total-jobs-counter) u1))
            )
            (try! (stx-transfer? job-budget tx-sender (as-contract tx-sender)))
            (map-set freelance-jobs
                { freelance-job-id: new-job-id }
                {
                    job-client: tx-sender,
                    job-title: job-title,
                    job-description: job-description,
                    job-budget: job-budget,
                    job-status: JOB_STATUS_OPEN,
                    selected-freelancer: none,
                    payment-milestones: payment-milestones,
                    active-milestone-index: u0
                }
            )
            (var-set total-jobs-counter new-job-id)
            (map-set job-escrow
                { freelance-job-id: new-job-id }
                {
                    escrow-amount: job-budget,
                    funds-locked: true
                }
            )
            (ok new-job-id)
        )
    )
)

(define-public (submit-bid (freelance-job-id uint) (bid-amount uint) (bid-proposal (string-ascii 500)))
    (begin
        (asserts! (is-valid-job-id freelance-job-id) ERR_JOB_NOT_FOUND)
        (asserts! (is-valid-job-budget bid-amount) ERR_INVALID_INPUT)
        (asserts! (is-valid-bid-proposal bid-proposal) ERR_INVALID_INPUT)
        (let
            (
                (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) ERR_JOB_NOT_FOUND))
            )
            (asserts! (is-eq (get job-status job-details) JOB_STATUS_OPEN) ERR_INVALID_JOB_STATUS)
            (asserts! (is-none (map-get? freelancer-bids { freelance-job-id: freelance-job-id, bidding-freelancer: tx-sender })) ERR_DUPLICATE_BID)

            (map-set freelancer-bids
                { freelance-job-id: freelance-job-id, bidding-freelancer: tx-sender }
                {
                    bid-amount: bid-amount,
                    bid-proposal: bid-proposal,
                    bid-status: BID_STATUS_PENDING
                }
            )
            (ok true)
        )
    )
)

(define-public (accept-freelancer-bid (freelance-job-id uint) (chosen-freelancer principal))
    (begin
        (asserts! (is-valid-job-id freelance-job-id) ERR_JOB_NOT_FOUND)
        (asserts! (is-valid-freelancer freelance-job-id chosen-freelancer) ERR_FREELANCER_NOT_FOUND)
        (let
            (
                (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) ERR_JOB_NOT_FOUND))
                (bid-details (unwrap! (map-get? freelancer-bids { freelance-job-id: freelance-job-id, bidding-freelancer: chosen-freelancer }) ERR_FREELANCER_NOT_FOUND))
            )
            (asserts! (is-eq tx-sender (get job-client job-details)) ERR_UNAUTHORIZED_ACCESS)
            (asserts! (is-eq (get job-status job-details) JOB_STATUS_OPEN) ERR_INVALID_JOB_STATUS)

            (map-set freelance-jobs
                { freelance-job-id: freelance-job-id }
                (merge job-details {
                    job-status: JOB_STATUS_IN_PROGRESS,
                    selected-freelancer: (some chosen-freelancer)
                })
            )
            (map-set freelancer-bids
                { freelance-job-id: freelance-job-id, bidding-freelancer: chosen-freelancer }
                (merge bid-details { bid-status: BID_STATUS_ACCEPTED })
            )
            (ok true)
        )
    )
)

;; Milestone and Payment Functions

(define-public (complete-payment-milestone (freelance-job-id uint))
    (begin
        (asserts! (is-valid-job-id freelance-job-id) ERR_JOB_NOT_FOUND)
        (let
            (
                (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) ERR_JOB_NOT_FOUND))
                (escrow-details (unwrap! (map-get? job-escrow { freelance-job-id: freelance-job-id }) ERR_JOB_NOT_FOUND))
                (milestone-payment (unwrap! (element-at (get payment-milestones job-details) (get active-milestone-index job-details)) ERR_JOB_NOT_FOUND))
                (selected-freelancer (unwrap! (get selected-freelancer job-details) ERR_JOB_NOT_FOUND))
            )
            (asserts! (is-eq tx-sender (get job-client job-details)) ERR_UNAUTHORIZED_ACCESS)
            (asserts! (is-eq (get job-status job-details) JOB_STATUS_IN_PROGRESS) ERR_INVALID_JOB_STATUS)

            ;; Release milestone payment to freelancer
            (try! (as-contract (stx-transfer? milestone-payment tx-sender selected-freelancer)))

            ;; Update job state
            (map-set freelance-jobs
                { freelance-job-id: freelance-job-id }
                (merge job-details {
                    active-milestone-index: (+ (get active-milestone-index job-details) u1)
                })
            )

            ;; Check if this was the last milestone
            (if (is-eq (+ (get active-milestone-index job-details) u1) (len (get payment-milestones job-details)))
                (map-set freelance-jobs
                    { freelance-job-id: freelance-job-id }
                    (merge job-details {
                        job-status: JOB_STATUS_COMPLETED,
                        active-milestone-index: (+ (get active-milestone-index job-details) u1)
                    })
                )
                true
            )
            (ok true)
        )
    )
)

;; Dispute Resolution Functions

(define-public (initiate-dispute (freelance-job-id uint) (dispute-reason (string-ascii 500)))
    (begin
        (asserts! (is-valid-job-id freelance-job-id) ERR_JOB_NOT_FOUND)
        (asserts! (is-valid-job-description dispute-reason) ERR_INVALID_INPUT)
        (let
            (
                (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) ERR_JOB_NOT_FOUND))
                (selected-freelancer (unwrap! (get selected-freelancer job-details) ERR_JOB_NOT_FOUND))
            )
            (asserts! (or
                (is-eq tx-sender (get job-client job-details))
                (is-eq tx-sender selected-freelancer)
            ) ERR_UNAUTHORIZED_ACCESS)
            (asserts! (is-none (map-get? job-disputes { freelance-job-id: freelance-job-id })) ERR_EXISTING_DISPUTE)

            (map-set job-disputes
                { freelance-job-id: freelance-job-id }
                {
                    dispute-initiator: tx-sender,
                    dispute-reason: dispute-reason,
                    release-payment-votes: u0,
                    refund-payment-votes: u0,
                    dispute-resolved: false
                }
            )
            (map-set freelance-jobs
                { freelance-job-id: freelance-job-id }
                (merge job-details { job-status: JOB_STATUS_DISPUTED })
            )
            (ok true)
        )
    )
)

(define-public (cast-dispute-vote (freelance-job-id uint) (vote-to-release bool))
    (begin
        (asserts! (is-valid-job-id freelance-job-id) ERR_JOB_NOT_FOUND)
        (let
            (
                (dispute-details (unwrap! (map-get? job-disputes { freelance-job-id: freelance-job-id }) ERR_JOB_NOT_FOUND))
            )
            (asserts! (not (get dispute-resolved dispute-details)) ERR_INVALID_JOB_STATUS)

            (map-set job-disputes
                { freelance-job-id: freelance-job-id }
                (merge dispute-details {
                    release-payment-votes: (if vote-to-release (+ (get release-payment-votes dispute-details) u1) (get release-payment-votes dispute-details)),
                    refund-payment-votes: (if (not vote-to-release) (+ (get refund-payment-votes dispute-details) u1) (get refund-payment-votes dispute-details))
                })
            )
            (ok true)
        )
    )
)

;; Rating System Functions

(define-public (submit-user-rating (rated-user principal) (rating-value uint))
    (begin
        (asserts! (and (>= rating-value u1) (<= rating-value u5)) ERR_INVALID_RATING_RANGE)
        (asserts! (not (is-eq tx-sender rated-user)) ERR_INVALID_INPUT)
        (let
            (
                (current-rating-data (default-to
                    { cumulative-rating: u0, rating-count: u0, rating-average: u0 }
                    (map-get? freelancer-ratings { rated-user: rated-user })
                ))
            )
            (map-set freelancer-ratings
                { rated-user: rated-user }
                {
                    cumulative-rating: (+ (get cumulative-rating current-rating-data) rating-value),
                    rating-count: (+ (get rating-count current-rating-data) u1),
                    rating-average: (/ (+ (get cumulative-rating current-rating-data) rating-value)
                                     (+ (get rating-count current-rating-data) u1))
                }
            )
            (ok true)
        )
    )
)

;; Read-only Functions

(define-read-only (get-job-details (freelance-job-id uint))
    (map-get? freelance-jobs { freelance-job-id: freelance-job-id })
)

(define-read-only (get-freelancer-rating (rated-user principal))
    (map-get? freelancer-ratings { rated-user: rated-user })
)

(define-read-only (get-job-bid (freelance-job-id uint) (bidding-freelancer principal))
    (map-get? freelancer-bids { freelance-job-id: freelance-job-id, bidding-freelancer: bidding-freelancer })
)

(define-read-only (get-job-dispute-details (freelance-job-id uint))
    (map-get? job-disputes { freelance-job-id: freelance-job-id })
)