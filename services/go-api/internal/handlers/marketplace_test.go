package handlers

import (
	"net/http"
	"testing"
)

func TestMarketplaceHandler_Routes(t *testing.T) {
	handler := NewMarketplaceHandler(nil, nil)
	router := handler.Routes(func(next http.Handler) http.Handler { return next })

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestMarketplaceListResponse_Structure(t *testing.T) {
	resp := MarketplaceListResponse{
		Data: []MarketplaceFeedResponse{
			{
				Name: "Test Feed",
				Type: "SINGLE_POST",
			},
		},
	}

	if len(resp.Data) != 1 {
		t.Errorf("expected 1 item in Data, got %d", len(resp.Data))
	}
	if resp.Data[0].Name != "Test Feed" {
		t.Errorf("expected name 'Test Feed', got %q", resp.Data[0].Name)
	}
}

func TestNewMarketplaceHandler(t *testing.T) {
	handler := NewMarketplaceHandler(nil, nil)
	if handler == nil {
		t.Fatal("NewMarketplaceHandler returned nil")
	}
}

func TestSlugify(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"Startup Daily Digest", "startup-daily-digest"},
		{"AI Research", "ai-research"},
		{"  spaces  ", "spaces"},
		{"", "feed"},
	}

	for _, tt := range tests {
		got := slugify(tt.input)
		if got != tt.want {
			t.Errorf("slugify(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}
