package handlers

import (
	"testing"
)

func TestSuggestionsHandler_Routes(t *testing.T) {
	handler := NewSuggestionsHandler(nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestNewSuggestionsHandler(t *testing.T) {
	handler := NewSuggestionsHandler(nil)
	if handler == nil {
		t.Fatal("NewSuggestionsHandler returned nil")
	}
}

func TestSuggestionResponse_Fields(t *testing.T) {
	sourceType := "rss"
	resp := SuggestionResponse{
		ID: "test-id",
		Name: SuggestionNameResponse{
			En: "English Name",
			Ru: "Russian Name",
		},
		SourceType: &sourceType,
	}

	if resp.ID != "test-id" {
		t.Errorf("expected ID 'test-id', got %q", resp.ID)
	}
	if resp.Name.En != "English Name" {
		t.Errorf("expected En 'English Name', got %q", resp.Name.En)
	}
	if resp.Name.Ru != "Russian Name" {
		t.Errorf("expected Ru 'Russian Name', got %q", resp.Name.Ru)
	}
	if *resp.SourceType != "rss" {
		t.Errorf("expected SourceType 'rss', got %q", *resp.SourceType)
	}
}

func TestSuggestionNameResponse_Fields(t *testing.T) {
	name := SuggestionNameResponse{
		En: "Test",
		Ru: "Тест",
	}

	if name.En != "Test" {
		t.Errorf("expected En 'Test', got %q", name.En)
	}
	if name.Ru != "Тест" {
		t.Errorf("expected Ru 'Тест', got %q", name.Ru)
	}
}
