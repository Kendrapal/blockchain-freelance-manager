;; Freelance Marketplace Contract

;; Data Maps and Variables
(define-map freelance-jobs
    { freelance-job-id: uint }
    {
        job-client: principal,
        job-title: (string-utf8 100),
        job-description: (string-utf8 500),
        job-budget: uint,
        job-status: (string-utf8 20),
        selected-freelancer: principal,
        payment-milestones: (list 10 uint),
        active-milestone-index: uint
    }
)

(define-map freelancer-bids
    { freelance-job-id: uint, bidding-freelancer: principal }
    {
        bid-amount: uint,
        bid-proposal: (string-utf8 500),
        bid-status: (string-utf8 20)
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
        dispute-reason: (string-utf8 500),
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

;; Error constants
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_JOB_NOT_FOUND (err u101))
(define-constant ERR_INVALID_JOB_STATUS (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_DUPLICATE_BID (err u104))
(define-constant ERR_EXISTING_DISPUTE (err u105))
(define-constant ERR_INVALID_RATING_RANGE (err u106))

;; Job Management Functions

(define-public (post-freelance-job (job-title (string-utf8 100)) (job-description (string-utf8 500)) (job-budget uint) (payment-milestones (list 10 uint)))
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
                job-status: "open",
                selected-freelancer: tx-sender,  ;; Initialize with tx-sender as placeholder
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

(define-public (submit-bid (freelance-job-id uint) (bid-amount uint) (bid-proposal (string-utf8 500)))
    (let
        (
            (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) (err u404)))
        )
        (asserts! (is-eq (get job-status job-details) "open") ERR_INVALID_JOB_STATUS)
        (asserts! (is-none (map-get? freelancer-bids { freelance-job-id: freelance-job-id, bidding-freelancer: tx-sender })) ERR_DUPLICATE_BID)

        (map-set freelancer-bids
            { freelance-job-id: freelance-job-id, bidding-freelancer: tx-sender }
            {
                bid-amount: bid-amount,
                bid-proposal: bid-proposal,
                bid-status: "pending"
            }
        )
        (ok true)
    )
)

(define-public (accept-freelancer-bid (freelance-job-id uint) (chosen-freelancer principal))
    (let
        (
            (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) (err u404)))
            (bid-details (unwrap! (map-get? freelancer-bids { freelance-job-id: freelance-job-id, bidding-freelancer: chosen-freelancer }) (err u404)))
        )
        (asserts! (is-eq tx-sender (get job-client job-details)) ERR_UNAUTHORIZED_ACCESS)
        (asserts! (is-eq (get job-status job-details) "open") ERR_INVALID_JOB_STATUS)

        (map-set freelance-jobs
            { freelance-job-id: freelance-job-id }
            (merge job-details {
                job-status: "in-progress",
                selected-freelancer: chosen-freelancer
            })
        )
        (map-set freelancer-bids
            { freelance-job-id: freelance-job-id, bidding-freelancer: chosen-freelancer }
            (merge bid-details { bid-status: "accepted" })
        )
        (ok true)
    )
)

;; Milestone and Payment Functions

(define-public (complete-payment-milestone (freelance-job-id uint))
    (let
        (
            (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) (err u404)))
            (escrow-details (unwrap! (map-get? job-escrow { freelance-job-id: freelance-job-id }) (err u404)))
            (milestone-payment (unwrap! (element-at (get payment-milestones job-details) (get active-milestone-index job-details)) (err u404)))
        )
        (asserts! (is-eq tx-sender (get job-client job-details)) ERR_UNAUTHORIZED_ACCESS)
        (asserts! (is-eq (get job-status job-details) "in-progress") ERR_INVALID_JOB_STATUS)

        ;; Release milestone payment to freelancer
        (try! (as-contract (stx-transfer? milestone-payment tx-sender (get selected-freelancer job-details))))

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
                    job-status: "completed",
                    active-milestone-index: (+ (get active-milestone-index job-details) u1)
                })
            )
            true
        )
        (ok true)
    )
)

;; Dispute Resolution Functions

(define-public (initiate-dispute (freelance-job-id uint) (dispute-reason (string-utf8 500)))
    (let
        (
            (job-details (unwrap! (map-get? freelance-jobs { freelance-job-id: freelance-job-id }) (err u404)))
        )
        (asserts! (or
            (is-eq tx-sender (get job-client job-details))
            (is-eq tx-sender (get selected-freelancer job-details))
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
            (merge job-details { job-status: "disputed" })
        )
        (ok true)
    )
)

(define-public (cast-dispute-vote (freelance-job-id uint) (vote-to-release bool))
    (let
        (
            (dispute-details (unwrap! (map-get? job-disputes { freelance-job-id: freelance-job-id }) (err u404)))
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

;; Rating System Functions

(define-public (submit-user-rating (rated-user principal) (rating-value uint))
    (let
        (
            (current-rating-data (default-to
                { cumulative-rating: u0, rating-count: u0, rating-average: u0 }
                (map-get? freelancer-ratings { rated-user: rated-user })
            ))
        )
        (asserts! (and (>= rating-value u1) (<= rating-value u5)) ERR_INVALID_RATING_RANGE)

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

;; Read-only Functions

(define-read-only (get-job-details (freelance-job-id uint))
    (map-get? freelance-jobs { freelance-job-id: freelance-job-id })
)

(define-read-only (get-freelancer-rating (rated-user principal))
    (map-get? freelancer-ratings { rated-user: rated-user })
)

(define-read-only (get-job-bids (freelance-job-id uint))
    (map-get? freelancer-bids { freelance-job-id: freelance-job-id })
)

(define-read-only (get-job-dispute-details (freelance-job-id uint))
    (map-get? job-disputes { freelance-job-id: freelance-job-id })
)