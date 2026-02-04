package telegram

import (
	"sync"
	"time"
)

// AdaptiveRateController manages request rate based on FloodWait feedback.
// Increases delay when FloodWait errors occur, gradually decreases after successes.
type AdaptiveRateController struct {
	baseDelay     time.Duration
	maxMultiplier float64

	mu                   sync.Mutex
	multiplier           float64
	consecutiveSuccesses int
}

// NewAdaptiveRateController creates a new rate controller.
func NewAdaptiveRateController(baseDelayMs int, maxMultiplier float64) *AdaptiveRateController {
	return &AdaptiveRateController{
		baseDelay:     time.Duration(baseDelayMs) * time.Millisecond,
		maxMultiplier: maxMultiplier,
		multiplier:    1.0,
	}
}

// CurrentDelay returns the current delay based on multiplier.
func (r *AdaptiveRateController) CurrentDelay() time.Duration {
	r.mu.Lock()
	defer r.mu.Unlock()
	return time.Duration(float64(r.baseDelay) * r.multiplier)
}

// Multiplier returns current multiplier value.
func (r *AdaptiveRateController) Multiplier() float64 {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.multiplier
}

// OnFloodWait increases multiplier based on wait duration.
func (r *AdaptiveRateController) OnFloodWait(waitSeconds int) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.consecutiveSuccesses = 0

	var increase float64
	switch {
	case waitSeconds < 30:
		increase = 0.3
	case waitSeconds < 60:
		increase = 0.5
	default:
		increase = 1.0
	}

	r.multiplier += increase
	if r.multiplier > r.maxMultiplier {
		r.multiplier = r.maxMultiplier
	}
}

// OnSuccess gradually decreases multiplier after consecutive successes.
func (r *AdaptiveRateController) OnSuccess() {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.consecutiveSuccesses++

	if r.consecutiveSuccesses >= 10 && r.multiplier > 1.0 {
		r.multiplier *= 0.95
		if r.multiplier < 1.0 {
			r.multiplier = 1.0
		}
	}
}

// Reset resets the controller to initial state.
func (r *AdaptiveRateController) Reset() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.multiplier = 1.0
	r.consecutiveSuccesses = 0
}
