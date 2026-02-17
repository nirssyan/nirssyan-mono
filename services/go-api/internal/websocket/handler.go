package websocket

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/rs/zerolog/log"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type Handler struct {
	manager   *Manager
	jwtSecret string
}

func NewHandler(manager *Manager, jwtSecret string) *Handler {
	return &Handler{
		manager:   manager,
		jwtSecret: jwtSecret,
	}
}

func (h *Handler) HandleFeedNotifications(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		log.Warn().Msg("WebSocket connection rejected: no token provided")
		http.Error(w, "Missing authentication token", http.StatusUnauthorized)
		return
	}

	userID, err := middleware.ValidateJWT(token, h.jwtSecret)
	if err != nil {
		log.Warn().Err(err).Msg("WebSocket connection rejected: invalid token")
		http.Error(w, "Invalid or expired token", http.StatusUnauthorized)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to upgrade WebSocket connection")
		return
	}

	h.manager.Connect(userID, conn)

	go func() {
		defer func() {
			h.manager.Disconnect(userID, conn)
			conn.Close()
		}()

		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		conn.SetPongHandler(func(string) error {
			conn.SetReadDeadline(time.Now().Add(60 * time.Second))
			return nil
		})

		for {
			_, msg, err := conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure, websocket.CloseNormalClosure) {
					log.Debug().Err(err).Str("user_id", userID.String()).Msg("WebSocket closed unexpectedly")
				}
				break
			}

			var data map[string]string
			if json.Unmarshal(msg, &data) == nil && data["type"] == "ping" {
				conn.WriteJSON(map[string]string{"type": "pong"})
			}

			conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		}
	}()
}
