package handlers

import (
	"testing"
)

func TestMarketplaceHandler_Routes(t *testing.T) {
	handler := NewMarketplaceHandler(nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestMarketplaceResponse_Structure(t *testing.T) {
	resp := MarketplaceResponse{
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
	handler := NewMarketplaceHandler(nil)
	if handler == nil {
		t.Fatal("NewMarketplaceHandler returned nil")
	}
}
