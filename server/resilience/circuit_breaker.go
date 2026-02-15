package resilience

import (
	"errors"
	"sync"
	"time"
)

var ErrCircuitOpen = errors.New("circuit breaker is open")

type State string

const (
	StateClosed   State = "closed"
	StateOpen     State = "open"
	StateHalfOpen State = "half_open"
)

type CircuitBreaker struct {
	mu               sync.Mutex
	state            State
	consecutiveFails int
	failureThreshold int
	openTimeout      time.Duration
	openUntil        time.Time
}

func NewCircuitBreaker(failureThreshold int, openTimeout time.Duration) *CircuitBreaker {
	if failureThreshold <= 0 {
		failureThreshold = 5
	}
	if openTimeout <= 0 {
		openTimeout = 30 * time.Second
	}
	return &CircuitBreaker{
		state:            StateClosed,
		failureThreshold: failureThreshold,
		openTimeout:      openTimeout,
	}
}

func (cb *CircuitBreaker) Execute(fn func() error) error {
	if err := cb.allow(); err != nil {
		return err
	}

	if err := fn(); err != nil {
		cb.recordFailure()
		return err
	}
	cb.recordSuccess()
	return nil
}

func (cb *CircuitBreaker) allow() error {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	now := time.Now()
	switch cb.state {
	case StateOpen:
		if now.Before(cb.openUntil) {
			return ErrCircuitOpen
		}
		cb.state = StateHalfOpen
		return nil
	default:
		return nil
	}
}

func (cb *CircuitBreaker) recordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	cb.state = StateClosed
	cb.consecutiveFails = 0
	cb.openUntil = time.Time{}
}

func (cb *CircuitBreaker) recordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.consecutiveFails++
	if cb.consecutiveFails >= cb.failureThreshold {
		cb.state = StateOpen
		cb.openUntil = time.Now().Add(cb.openTimeout)
	}
}

func (cb *CircuitBreaker) Snapshot() (state State, failures int, openUntil time.Time) {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	return cb.state, cb.consecutiveFails, cb.openUntil
}
