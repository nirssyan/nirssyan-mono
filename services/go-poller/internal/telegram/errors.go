// Package telegram provides Telegram MTProto client functionality.
package telegram

import (
	"errors"
	"fmt"
)

// FloodWaitError indicates Telegram rate limit was hit.
type FloodWaitError struct {
	Seconds int
}

func (e *FloodWaitError) Error() string {
	return fmt.Sprintf("flood wait: need to wait %d seconds", e.Seconds)
}

// ChannelUnavailableError indicates channel cannot be accessed.
type ChannelUnavailableError struct {
	Username string
	Reason   string
}

func (e *ChannelUnavailableError) Error() string {
	return fmt.Sprintf("channel @%s unavailable: %s", e.Username, e.Reason)
}

// SessionError indicates session-related failure.
type SessionError struct {
	Op  string
	Err error
}

func (e *SessionError) Error() string {
	return fmt.Sprintf("session %s: %v", e.Op, e.Err)
}

func (e *SessionError) Unwrap() error {
	return e.Err
}

// Common errors.
var (
	ErrNotConnected    = errors.New("telegram client not connected")
	ErrSessionExpired  = errors.New("telegram session expired")
	ErrChannelNotFound = errors.New("channel not found")
)
