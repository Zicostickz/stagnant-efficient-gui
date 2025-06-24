;; skincare-protocol
;; 
;; This contract serves as the central hub for the GlowLink protocol, handling:
;; - User profile registration and management
;; - Skincare expert verification
;; - Skincare routine template submission and management
;; - Personalized recommendation generation based on weather and user profiles
;; - User feedback and expert reputation tracking

;; ---------- Error Constants ----------

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-ALREADY-EXISTS (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-EXPERT-ALREADY-VERIFIED (err u103))
(define-constant ERR-EXPERT-NOT-VERIFIED (err u104))
(define-constant ERR-ROUTINE-NOT-FOUND (err u105))
(define-constant ERR-INVALID-SKIN-TYPE (err u106))
(define-constant ERR-INVALID-CONCERN (err u107))
(define-constant ERR-INVALID-GOAL (err u108))
(define-constant ERR-INVALID-WEATHER-DATA (err u109))
(define-constant ERR-INVALID-RATING (err u110))
(define-constant ERR-RECOMMENDATION-NOT-FOUND (err u111))
(define-constant ERR-ALREADY-RATED (err u112))

;; ---------- Data Maps and Variables ----------

;; Contract administrator who can verify experts
(define-data-var contract-admin principal tx-sender)

;; Valid skin types
(define-data-var valid-skin-types (list 10 (string-ascii 20)) 
  (list "dry" "oily" "combination" "sensitive"))

;; Valid skin concerns
(define-data-var valid-concerns (list 10 (string-ascii 20)) 
  (list "aging" "acne" "hyperpigmentation" "rosacea" "dullness" "texture"))

;; Valid skincare goals
(define-data-var valid-goals (list 10 (string-ascii 20)) 
  (list "hydration" "anti-aging" "brightening" "clarifying" "soothing"))

;; User profiles storing skin information and preferences
(define-map user-profiles
  { user: principal }
  {
    skin-type: (string-ascii 20),
    concerns: (list 5 (string-ascii 20)),
    goals: (list 5 (string-ascii 20)),
    registration-time: uint
  }
)

;; Verified skincare experts/dermatologists
(define-map verified-experts
  { expert: principal }
  {
    verification-time: uint,
    credentials: (string-utf8 500),
    reputation-score: uint
  }
)

;; Skincare routine templates created by experts
(define-map routine-templates
  { routine-id: uint }
  {
    expert: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    skin-types: (list 5 (string-ascii 20)),
    concerns: (list 5 (string-ascii 20)),
    weather-conditions: {
      min-temp: int,
      max-temp: int,
      min-humidity: uint,
      max-humidity: uint,
      max-uv-index: uint
    },
    steps: (list 10 {
      step-order: uint,
      product-type: (string-ascii 50),
      instructions: (string-utf8 200)
    }),
    creation-time: uint,
    rating-count: uint,
    average-rating: uint
  }
)

;; Personalized recommendations generated for users
(define-map user-recommendations
  { recommendation-id: uint }
  {
    user: principal,
    routine-id: uint,
    weather-data: {
      temperature: int,
      humidity: uint,
      uv-index: uint,
      timestamp: uint
    },
    recommendation-time: uint,
    has-feedback: bool
  }
)

;; User feedback on recommendations
(define-map user-feedback
  { recommendation-id: uint }
  {
    user: principal,
    rating: uint,
    comments: (optional (string-utf8 300)),
    feedback-time: uint
  }
)

;; Counters for generating IDs
(define-data-var next-routine-id uint u1)
(define-data-var next-recommendation-id uint u1)

;; ---------- Private Functions ----------



;; Validate that a list of goals contains only valid goals
;; Check if the caller is a verified expert
(define-private (is-verified-expert (caller principal))
  (is-some (map-get? verified-experts { expert: caller }))
)

;; Update expert reputation based on rating
(define-private (update-expert-reputation (expert principal) (rating uint))
  (let (
    (expert-data (unwrap-panic (map-get? verified-experts { expert: expert })))
    (current-score (get reputation-score expert-data))
    ;; Simple weighted average: new score is 90% old score + 10% new rating
    (new-score (+ (* u9 (/ current-score u10)) (/ rating u10)))
  )
  (map-set verified-experts
    { expert: expert }
    (merge expert-data { reputation-score: new-score })
  ))
)

;; Update routine rating based on user feedback
(define-private (update-routine-rating (routine-id uint) (rating uint))
  (let (
    (routine (unwrap-panic (map-get? routine-templates { routine-id: routine-id })))
    (current-count (get rating-count routine))
    (current-avg (get average-rating routine))
    (new-count (+ current-count u1))
    (new-avg (if (is-eq current-count u0)
      rating
      ;; Calculate new average
      (/ (+ (* current-avg current-count) rating) new-count)
    ))
  )
  (map-set routine-templates
    { routine-id: routine-id }
    (merge routine {
      rating-count: new-count,
      average-rating: new-avg
    })
  ))
)

;; Check if weather conditions match routine requirements
(define-private (weather-matches-routine? 
  (weather-data { temperature: int, humidity: uint, uv-index: uint, timestamp: uint })
  (routine-conditions { min-temp: int, max-temp: int, min-humidity: uint, max-humidity: uint, max-uv-index: uint }))
  (and
    (>= (get temperature weather-data) (get min-temp routine-conditions))
    (<= (get temperature weather-data) (get max-temp routine-conditions))
    (>= (get humidity weather-data) (get min-humidity routine-conditions))
    (<= (get humidity weather-data) (get max-humidity routine-conditions))
    (<= (get uv-index weather-data) (get max-uv-index routine-conditions))
  )
)



;; ---------- Read-Only Functions ----------

;; Get user profile information
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

;; Check if a user has registered
(define-read-only (is-user-registered (user principal))
  (is-some (map-get? user-profiles { user: user }))
)

;; Get expert verification status and reputation
(define-read-only (get-expert-info (expert principal))
  (map-get? verified-experts { expert: expert })
)

;; Get routine template details
(define-read-only (get-routine-template (routine-id uint))
  (map-get? routine-templates { routine-id: routine-id })
)

;; Get user recommendation details
(define-read-only (get-user-recommendation (recommendation-id uint))
  (map-get? user-recommendations { recommendation-id: recommendation-id })
)

;; Get feedback for a recommendation
(define-read-only (get-recommendation-feedback (recommendation-id uint))
  (map-get? user-feedback { recommendation-id: recommendation-id })
)

;; Get all valid skin types
(define-read-only (get-valid-skin-types)
  (var-get valid-skin-types)
)

;; Get all valid skin concerns
(define-read-only (get-valid-concerns)
  (var-get valid-concerns)
)

;; Get all valid skincare goals
(define-read-only (get-valid-goals)
  (var-get valid-goals)
)

;; ---------- Public Functions ----------

;; Update contract administrator
(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-admin new-admin))
  )
)


;; Verify a skincare expert (only contract admin can do this)
(define-public (verify-expert (expert principal) (credentials (string-utf8 500)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-verified-expert expert)) ERR-EXPERT-ALREADY-VERIFIED)
    
    (ok (map-set verified-experts
      { expert: expert }
      {
        verification-time: block-height,
        credentials: credentials,
        reputation-score: u80  ;; Start with 80/100 reputation
      }
    ))
  )
)

;; Generate a personalized recommendation based on weather and user profile
(define-public (generate-recommendation
  (temperature int)
  (humidity uint)
  (uv-index uint))
  (let (
    (sender tx-sender)
    (weather-data {
      temperature: temperature,
      humidity: humidity,
      uv-index: uv-index,
      timestamp: block-height
    })
    (recommendation-id (var-get next-recommendation-id))
  )
    (asserts! (is-user-registered sender) ERR-USER-NOT-FOUND)
    
    ;; Simple validation of weather data
    (asserts! (and (>= temperature (- 50)) (<= temperature 50)) ERR-INVALID-WEATHER-DATA)
    (asserts! (and (>= humidity u0) (<= humidity u100)) ERR-INVALID-WEATHER-DATA)
    (asserts! (and (>= uv-index u0) (<= uv-index u12)) ERR-INVALID-WEATHER-DATA)
    
    ;; For demonstration purposes, we're choosing routine ID 1
    ;; In a real implementation, we would scan all routines to find the best match
    ;; based on weather conditions and user profile
    (asserts! (is-some (get-routine-template u1)) ERR-ROUTINE-NOT-FOUND)
    
    ;; Create the recommendation
    (map-set user-recommendations
      { recommendation-id: recommendation-id }
      {
        user: sender,
        routine-id: u1,
        weather-data: weather-data,
        recommendation-time: block-height,
        has-feedback: false
      }
    )
    
    ;; Increment recommendation ID counter
    (var-set next-recommendation-id (+ recommendation-id u1))
    
    (ok recommendation-id)
  )
)

;; Find best matching routine for user based on current weather
;; This would typically use an oracle for weather data
(define-public (find-best-routine
  (temperature int)
  (humidity uint)
  (uv-index uint))
  (let (
    (sender tx-sender)
    (user-data (unwrap! (get-user-profile sender) ERR-USER-NOT-FOUND))
    (weather-data {
      temperature: temperature,
      humidity: humidity,
      uv-index: uv-index,
      timestamp: block-height
    })
    ;; In a real implementation, this would scan all routine templates
    ;; and find optimal matches using an algorithm
    ;; For demonstration purposes, we'll just return routine ID 1 if it exists
    (routine-id u1)
  )
    (asserts! (is-some (get-routine-template routine-id)) ERR-ROUTINE-NOT-FOUND)
    (ok routine-id)
  )
)

;; Submit feedback for a recommendation
(define-public (submit-feedback
  (recommendation-id uint)
  (rating uint)
  (comments (optional (string-utf8 300))))
  (let (
    (sender tx-sender)
    (recommendation (unwrap! (map-get? user-recommendations { recommendation-id: recommendation-id }) ERR-RECOMMENDATION-NOT-FOUND))
  )
    ;; Validate that the feedback comes from the recommendation recipient
    (asserts! (is-eq sender (get user recommendation)) ERR-NOT-AUTHORIZED)
    
    ;; Check that the recommendation hasn't already been rated
    (asserts! (not (get has-feedback recommendation)) ERR-ALREADY-RATED)
    
    ;; Validate rating (1-100 scale)
    (asserts! (and (>= rating u1) (<= rating u100)) ERR-INVALID-RATING)
    
    ;; Get the routine data
    (let (
      (routine-id (get routine-id recommendation))
      (routine (unwrap! (map-get? routine-templates { routine-id: routine-id }) ERR-ROUTINE-NOT-FOUND))
      (expert (get expert routine))
    )
      ;; Update the user recommendation to mark it as having feedback
      (map-set user-recommendations
        { recommendation-id: recommendation-id }
        (merge recommendation { has-feedback: true })
      )
      
      ;; Store the feedback
      (map-set user-feedback
        { recommendation-id: recommendation-id }
        {
          user: sender,
          rating: rating,
          comments: comments,
          feedback-time: block-height
        }
      )
      
      ;; Update the routine's rating
      (update-routine-rating routine-id rating)
      
      ;; Update the expert's reputation
      (update-expert-reputation expert rating)
      
      (ok true)
    )
  )
)