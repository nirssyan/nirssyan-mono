package telegram

import (
	"context"
	"os"
	"path/filepath"

	"github.com/gotd/td/session"
)

// FileStorage implements session.Storage for file-based persistence.
// Compatible with K8s PVC mounts.
type FileStorage struct {
	path string
}

// NewFileStorage creates file-based session storage.
func NewFileStorage(dir, name string) *FileStorage {
	return &FileStorage{
		path: filepath.Join(dir, name+".session"),
	}
}

// LoadSession reads session data from file.
func (s *FileStorage) LoadSession(_ context.Context) ([]byte, error) {
	data, err := os.ReadFile(s.path)
	if os.IsNotExist(err) {
		return nil, session.ErrNotFound
	}
	if err != nil {
		return nil, &SessionError{Op: "load", Err: err}
	}
	return data, nil
}

// StoreSession writes session data to file atomically.
func (s *FileStorage) StoreSession(_ context.Context, data []byte) error {
	dir := filepath.Dir(s.path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return &SessionError{Op: "mkdir", Err: err}
	}

	// Write to temp file then rename for atomicity
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return &SessionError{Op: "write", Err: err}
	}

	if err := os.Rename(tmp, s.path); err != nil {
		os.Remove(tmp)
		return &SessionError{Op: "rename", Err: err}
	}

	return nil
}

// Path returns the session file path.
func (s *FileStorage) Path() string {
	return s.path
}

// Exists checks if session file exists.
func (s *FileStorage) Exists() bool {
	_, err := os.Stat(s.path)
	return err == nil
}
