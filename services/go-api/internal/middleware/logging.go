package middleware

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/rs/zerolog/log"
)

const maxBodyLogSize = 4096

type responseWriter struct {
	http.ResponseWriter
	statusCode int
	written    int64
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	n, err := rw.ResponseWriter.Write(b)
	rw.written += int64(n)
	return n, err
}

func (rw *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hj, ok := rw.ResponseWriter.(http.Hijacker); ok {
		return hj.Hijack()
	}
	return nil, nil, fmt.Errorf("http.Hijacker not supported")
}

func shouldLogBody(r *http.Request) bool {
	contentType := r.Header.Get("Content-Type")
	if strings.HasPrefix(contentType, "multipart/form-data") {
		return false
	}
	if r.ContentLength > maxBodyLogSize {
		return false
	}
	return r.Method == http.MethodPost || r.Method == http.MethodPut || r.Method == http.MethodPatch
}

func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		var bodyBytes []byte
		if shouldLogBody(r) && r.Body != nil {
			bodyBytes, _ = io.ReadAll(io.LimitReader(r.Body, maxBodyLogSize))
			r.Body.Close()
			r.Body = io.NopCloser(bytes.NewReader(bodyBytes))
		}

		rw := &responseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		next.ServeHTTP(rw, r)

		duration := time.Since(start)
		reqID := GetRequestID(r.Context())

		event := log.Info()
		if rw.statusCode >= 400 {
			event = log.Warn()
		}
		if rw.statusCode >= 500 {
			event = log.Error()

			sentry.WithScope(func(scope *sentry.Scope) {
				scope.SetTag("method", r.Method)
				scope.SetTag("path", r.URL.Path)
				scope.SetTag("status_code", fmt.Sprintf("%d", rw.statusCode))
				scope.SetTag("request_id", reqID)
				scope.SetLevel(sentry.LevelError)
				sentry.CaptureException(fmt.Errorf("%s %s returned %d", r.Method, r.URL.Path, rw.statusCode))
			})
			sentry.Flush(2 * time.Second)
		}

		event = event.
			Str("method", r.Method).
			Str("path", r.URL.Path).
			Int("status", rw.statusCode).
			Int64("bytes", rw.written).
			Dur("duration", duration).
			Str("request_id", reqID)

		if len(bodyBytes) > 0 {
			event = event.Str("request_body", string(bodyBytes))
		}

		if r.URL.RawQuery != "" {
			event = event.Str("query", r.URL.RawQuery)
		}

		event.Msg("HTTP request")
	})
}
