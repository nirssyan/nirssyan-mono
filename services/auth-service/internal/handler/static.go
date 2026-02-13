package handler

import (
	"embed"
	"net/http"
)

//go:embed static/infatiumv5.png
var staticFS embed.FS

type StaticHandler struct{}

func NewStaticHandler() *StaticHandler {
	return &StaticHandler{}
}

func (h *StaticHandler) Logo(w http.ResponseWriter, r *http.Request) {
	data, err := staticFS.ReadFile("static/infatiumv5.png")
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "image/png")
	w.Header().Set("Cache-Control", "public, max-age=86400")
	w.Write(data)
}
