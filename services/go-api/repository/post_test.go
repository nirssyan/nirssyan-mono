package repository

import (
	"encoding/base64"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestEncodeCursor(t *testing.T) {
	createdAt := time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC)
	id := uuid.MustParse("550e8400-e29b-41d4-a716-446655440000")

	encoded := EncodeCursor(createdAt, id)

	if encoded == "" {
		t.Error("EncodeCursor returned empty string")
	}

	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		t.Fatalf("Failed to decode base64: %v", err)
	}

	var cursor PostCursor
	if err := json.Unmarshal(decoded, &cursor); err != nil {
		t.Fatalf("Failed to unmarshal cursor: %v", err)
	}

	if cursor.ID != id.String() {
		t.Errorf("cursor.ID = %s, want %s", cursor.ID, id.String())
	}
}

func TestDecodeCursor(t *testing.T) {
	tests := []struct {
		name    string
		cursor  string
		wantErr bool
	}{
		{
			name:    "invalid base64",
			cursor:  "not-valid-base64!!!",
			wantErr: true,
		},
		{
			name:    "invalid json",
			cursor:  base64.StdEncoding.EncodeToString([]byte("not json")),
			wantErr: true,
		},
		{
			name: "invalid date format",
			cursor: base64.StdEncoding.EncodeToString([]byte(
				`{"created_at":"invalid","id":"550e8400-e29b-41d4-a716-446655440000"}`,
			)),
			wantErr: true,
		},
		{
			name: "invalid uuid",
			cursor: base64.StdEncoding.EncodeToString([]byte(
				`{"created_at":"2024-01-15T10:30:00Z","id":"invalid"}`,
			)),
			wantErr: true,
		},
		{
			name: "valid cursor",
			cursor: base64.StdEncoding.EncodeToString([]byte(
				`{"created_at":"2024-01-15T10:30:00Z","id":"550e8400-e29b-41d4-a716-446655440000"}`,
			)),
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			createdAt, id, err := DecodeCursor(tt.cursor)

			if tt.wantErr {
				if err == nil {
					t.Error("expected error, got nil")
				}
				return
			}

			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}

			if createdAt.IsZero() {
				t.Error("createdAt is zero")
			}
			if id == uuid.Nil {
				t.Error("id is nil uuid")
			}
		})
	}
}

func TestEncodeDecode_RoundTrip(t *testing.T) {
	originalTime := time.Date(2024, 6, 15, 14, 30, 45, 0, time.UTC)
	originalID := uuid.New()

	encoded := EncodeCursor(originalTime, originalID)
	decodedTime, decodedID, err := DecodeCursor(encoded)

	if err != nil {
		t.Fatalf("DecodeCursor error: %v", err)
	}

	if !decodedTime.Equal(originalTime) {
		t.Errorf("time mismatch: got %v, want %v", decodedTime, originalTime)
	}

	if decodedID != originalID {
		t.Errorf("id mismatch: got %v, want %v", decodedID, originalID)
	}
}

func TestPostCursor_JSONMarshaling(t *testing.T) {
	cursor := PostCursor{
		CreatedAt: "2024-01-15T10:30:00Z",
		ID:        "550e8400-e29b-41d4-a716-446655440000",
	}

	data, err := json.Marshal(cursor)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var decoded PostCursor
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if decoded.CreatedAt != cursor.CreatedAt {
		t.Errorf("CreatedAt mismatch: got %s, want %s", decoded.CreatedAt, cursor.CreatedAt)
	}
	if decoded.ID != cursor.ID {
		t.Errorf("ID mismatch: got %s, want %s", decoded.ID, cursor.ID)
	}
}
