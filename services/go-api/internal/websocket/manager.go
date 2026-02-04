package websocket

import (
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"
)

type Manager struct {
	connections map[uuid.UUID]map[*websocket.Conn]bool
	mu          sync.RWMutex
}

func NewManager() *Manager {
	return &Manager{
		connections: make(map[uuid.UUID]map[*websocket.Conn]bool),
	}
}

func (m *Manager) Connect(userID uuid.UUID, conn *websocket.Conn) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.connections[userID] == nil {
		m.connections[userID] = make(map[*websocket.Conn]bool)
	}
	m.connections[userID][conn] = true

	log.Info().
		Str("user_id", userID.String()).
		Int("total_connections", len(m.connections[userID])).
		Msg("WebSocket connected")
}

func (m *Manager) Disconnect(userID uuid.UUID, conn *websocket.Conn) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if conns, ok := m.connections[userID]; ok {
		delete(conns, conn)
		if len(conns) == 0 {
			delete(m.connections, userID)
		}
	}

	log.Info().
		Str("user_id", userID.String()).
		Msg("WebSocket disconnected")
}

func (m *Manager) SendToUser(userID uuid.UUID, message any) int {
	m.mu.RLock()
	conns := m.connections[userID]
	if len(conns) == 0 {
		m.mu.RUnlock()
		return 0
	}

	connList := make([]*websocket.Conn, 0, len(conns))
	for conn := range conns {
		connList = append(connList, conn)
	}
	m.mu.RUnlock()

	sentCount := 0
	var deadConns []*websocket.Conn

	for _, conn := range connList {
		if err := conn.WriteJSON(message); err != nil {
			log.Warn().
				Err(err).
				Str("user_id", userID.String()).
				Msg("Failed to send WebSocket message")
			deadConns = append(deadConns, conn)
		} else {
			sentCount++
		}
	}

	if len(deadConns) > 0 {
		m.mu.Lock()
		for _, conn := range deadConns {
			delete(m.connections[userID], conn)
		}
		if len(m.connections[userID]) == 0 {
			delete(m.connections, userID)
		}
		m.mu.Unlock()

		log.Info().
			Str("user_id", userID.String()).
			Int("cleaned", len(deadConns)).
			Msg("Cleaned up dead connections")
	}

	return sentCount
}

func (m *Manager) NotifyPostCreated(userID, postID, feedID uuid.UUID) int {
	return m.SendToUser(userID, map[string]string{
		"type":    "post_created",
		"post_id": postID.String(),
		"feed_id": feedID.String(),
	})
}

func (m *Manager) NotifyFeedCreationFinished(userID, feedID uuid.UUID) int {
	return m.SendToUser(userID, map[string]string{
		"type":    "feed_creation_finished",
		"feed_id": feedID.String(),
	})
}

func (m *Manager) GetConnectionCount(userID uuid.UUID) int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.connections[userID])
}

func (m *Manager) GetTotalConnections() int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	total := 0
	for _, conns := range m.connections {
		total += len(conns)
	}
	return total
}
