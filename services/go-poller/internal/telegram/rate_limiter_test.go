package telegram

import (
	"testing"
	"time"
)

func TestNewAdaptiveRateController(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)

	if rc.baseDelay != 100*time.Millisecond {
		t.Errorf("expected baseDelay 100ms, got %v", rc.baseDelay)
	}

	if rc.maxMultiplier != 3.0 {
		t.Errorf("expected maxMultiplier 3.0, got %v", rc.maxMultiplier)
	}

	if rc.multiplier != 1.0 {
		t.Errorf("expected initial multiplier 1.0, got %v", rc.multiplier)
	}
}

func TestAdaptiveRateController_CurrentDelay(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)

	delay := rc.CurrentDelay()
	if delay < 75*time.Millisecond || delay > 125*time.Millisecond {
		t.Errorf("expected delay ~100ms (±25%%), got %v", delay)
	}

	rc.multiplier = 2.0
	delay = rc.CurrentDelay()
	if delay < 150*time.Millisecond || delay > 250*time.Millisecond {
		t.Errorf("expected delay ~200ms (±25%%), got %v", delay)
	}
}

func TestAdaptiveRateController_OnFloodWait_Short(t *testing.T) {
	rc := NewAdaptiveRateController(100, 5.0)

	rc.OnFloodWait(15)

	if rc.multiplier != 1.3 {
		t.Errorf("expected multiplier 1.3 for short wait, got %v", rc.multiplier)
	}

	if rc.consecutiveSuccesses != 0 {
		t.Errorf("expected consecutiveSuccesses reset to 0, got %d", rc.consecutiveSuccesses)
	}
}

func TestAdaptiveRateController_OnFloodWait_Medium(t *testing.T) {
	rc := NewAdaptiveRateController(100, 5.0)

	rc.OnFloodWait(45)

	if rc.multiplier != 1.5 {
		t.Errorf("expected multiplier 1.5 for medium wait, got %v", rc.multiplier)
	}
}

func TestAdaptiveRateController_OnFloodWait_Long(t *testing.T) {
	rc := NewAdaptiveRateController(100, 5.0)

	rc.OnFloodWait(120)

	if rc.multiplier != 2.0 {
		t.Errorf("expected multiplier 2.0 for long wait, got %v", rc.multiplier)
	}
}

func TestAdaptiveRateController_OnFloodWait_MaxMultiplier(t *testing.T) {
	rc := NewAdaptiveRateController(100, 2.0)

	rc.OnFloodWait(120)
	rc.OnFloodWait(120)
	rc.OnFloodWait(120)

	if rc.multiplier != 2.0 {
		t.Errorf("expected multiplier capped at 2.0, got %v", rc.multiplier)
	}
}

func TestAdaptiveRateController_OnSuccess_NoDecrease(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)
	rc.multiplier = 2.0

	for i := 0; i < 4; i++ {
		rc.OnSuccess()
	}

	if rc.multiplier != 2.0 {
		t.Errorf("expected multiplier unchanged after 4 successes, got %v", rc.multiplier)
	}
}

func TestAdaptiveRateController_OnSuccess_Decrease(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)
	rc.multiplier = 2.0

	for i := 0; i < 5; i++ {
		rc.OnSuccess()
	}

	expected := 2.0 * 0.9
	if rc.multiplier != expected {
		t.Errorf("expected multiplier %v after 5 successes, got %v", expected, rc.multiplier)
	}
}

func TestAdaptiveRateController_OnSuccess_MinMultiplier(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)
	rc.multiplier = 1.02

	for i := 0; i < 20; i++ {
		rc.OnSuccess()
	}

	if rc.multiplier != 1.0 {
		t.Errorf("expected multiplier floored at 1.0, got %v", rc.multiplier)
	}
}

func TestAdaptiveRateController_Reset(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)
	rc.multiplier = 2.5
	rc.consecutiveSuccesses = 15

	rc.Reset()

	if rc.multiplier != 1.0 {
		t.Errorf("expected multiplier reset to 1.0, got %v", rc.multiplier)
	}

	if rc.consecutiveSuccesses != 0 {
		t.Errorf("expected consecutiveSuccesses reset to 0, got %d", rc.consecutiveSuccesses)
	}
}

func TestAdaptiveRateController_Multiplier(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)
	rc.multiplier = 1.5

	if rc.Multiplier() != 1.5 {
		t.Errorf("expected Multiplier() to return 1.5, got %v", rc.Multiplier())
	}
}

func TestAdaptiveRateController_ConcurrentAccess(t *testing.T) {
	rc := NewAdaptiveRateController(100, 3.0)

	done := make(chan struct{})

	go func() {
		for i := 0; i < 100; i++ {
			rc.OnSuccess()
		}
		done <- struct{}{}
	}()

	go func() {
		for i := 0; i < 100; i++ {
			rc.OnFloodWait(10)
		}
		done <- struct{}{}
	}()

	go func() {
		for i := 0; i < 100; i++ {
			_ = rc.CurrentDelay()
			_ = rc.Multiplier()
		}
		done <- struct{}{}
	}()

	<-done
	<-done
	<-done
}
