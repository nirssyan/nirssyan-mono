package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestContainsLabel(t *testing.T) {
	tests := []struct {
		name   string
		labels []string
		label  string
		want   bool
	}{
		{
			name:   "empty labels",
			labels: []string{},
			label:  "test",
			want:   false,
		},
		{
			name:   "nil labels",
			labels: nil,
			label:  "test",
			want:   false,
		},
		{
			name:   "label found",
			labels: []string{"a", "foreign_agent", "c"},
			label:  "foreign_agent",
			want:   true,
		},
		{
			name:   "label not found",
			labels: []string{"a", "b", "c"},
			label:  "foreign_agent",
			want:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := containsLabel(tt.labels, tt.label)
			if got != tt.want {
				t.Errorf("containsLabel() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestApplyEntityMarkers(t *testing.T) {
	tests := []struct {
		name     string
		views    map[string]string
		entities []string
		want     map[string]string
	}{
		{
			name:     "empty views",
			views:    map[string]string{},
			entities: []string{"test"},
			want:     map[string]string{},
		},
		{
			name:     "empty entities",
			views:    map[string]string{"text": "hello world"},
			entities: []string{},
			want:     map[string]string{"text": "hello world"},
		},
		{
			name:     "marker applied",
			views:    map[string]string{"text": "Hello World Test"},
			entities: []string{"World"},
			want:     map[string]string{"text": "Hello World * Test"},
		},
		{
			name:     "case insensitive",
			views:    map[string]string{"text": "Hello WORLD test"},
			entities: []string{"world"},
			want:     map[string]string{"text": "Hello world * test"},
		},
		{
			name:     "multiple entities",
			views:    map[string]string{"text": "Hello World Foo Bar"},
			entities: []string{"World", "Foo"},
			want:     map[string]string{"text": "Hello World * Foo * Bar"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := applyEntityMarkers(tt.views, tt.entities)
			for k, v := range tt.want {
				if got[k] != v {
					t.Errorf("applyEntityMarkers()[%s] = %q, want %q", k, got[k], v)
				}
			}
		})
	}
}

func TestReplaceIgnoreCase(t *testing.T) {
	tests := []struct {
		name    string
		s       string
		old     string
		new     string
		want    string
	}{
		{
			name: "basic replace",
			s:    "Hello World",
			old:  "World",
			new:  "World *",
			want: "Hello World *",
		},
		{
			name: "case insensitive",
			s:    "Hello WORLD",
			old:  "world",
			new:  "world *",
			want: "Hello world *",
		},
		{
			name: "multiple occurrences",
			s:    "World Hello World",
			old:  "World",
			new:  "World *",
			want: "World * Hello World *",
		},
		{
			name: "empty old",
			s:    "Hello",
			old:  "",
			new:  "X",
			want: "Hello",
		},
		{
			name: "no match",
			s:    "Hello",
			old:  "World",
			new:  "World *",
			want: "Hello",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := replaceIgnoreCase(tt.s, tt.old, tt.new)
			if got != tt.want {
				t.Errorf("replaceIgnoreCase() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestEmptyIfNil(t *testing.T) {
	tests := []struct {
		name  string
		input []string
		want  int
	}{
		{
			name:  "nil slice",
			input: nil,
			want:  0,
		},
		{
			name:  "empty slice",
			input: []string{},
			want:  0,
		},
		{
			name:  "non-empty slice",
			input: []string{"a", "b"},
			want:  2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := emptyIfNil(tt.input)
			if got == nil {
				t.Error("emptyIfNil() returned nil")
			}
			if len(got) != tt.want {
				t.Errorf("emptyIfNil() len = %d, want %d", len(got), tt.want)
			}
		})
	}
}

func TestPostHandler_Routes(t *testing.T) {
	handler := NewPostHandler(nil, nil, nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestPostHandler_MarkSeen_Unauthorized(t *testing.T) {
	handler := NewPostHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodPost, "/posts/seen", map[string]interface{}{
		"post_ids": []string{uuid.New().String()},
	})
	rr := httptest.NewRecorder()

	handler.MarkSeen(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestPostHandler_MarkSeen_InvalidBody(t *testing.T) {
	handler := NewPostHandler(nil, nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/posts/seen", "invalid json", userID)
	rr := httptest.NewRecorder()

	handler.MarkSeen(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestPostHandler_GetPost_Unauthorized(t *testing.T) {
	handler := NewPostHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodGet, "/posts/"+uuid.New().String(), nil)
	req = withURLParam(req, "post_id", uuid.New().String())
	rr := httptest.NewRecorder()

	handler.GetPost(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestPostHandler_GetPost_InvalidPostID(t *testing.T) {
	handler := NewPostHandler(nil, nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodGet, "/posts/invalid", nil, userID)
	req = withURLParam(req, "post_id", "invalid")
	rr := httptest.NewRecorder()

	handler.GetPost(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestPostHandler_GetFeedPosts_Unauthorized(t *testing.T) {
	handler := NewPostHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodGet, "/posts/feed/"+uuid.New().String(), nil)
	req = withURLParam(req, "feed_id", uuid.New().String())
	rr := httptest.NewRecorder()

	handler.GetFeedPosts(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestPostHandler_GetFeedPosts_InvalidFeedID(t *testing.T) {
	handler := NewPostHandler(nil, nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodGet, "/posts/feed/invalid", nil, userID)
	req = withURLParam(req, "feed_id", "invalid")
	rr := httptest.NewRecorder()

	handler.GetFeedPosts(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}
