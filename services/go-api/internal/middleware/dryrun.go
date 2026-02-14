package middleware

import (
	"context"
	"net/http"
)

type ctxKey string

const dryRunNotifyKey ctxKey = "dry_run_notify"

func WithDryRunNotify(ctx context.Context) context.Context {
	return context.WithValue(ctx, dryRunNotifyKey, true)
}

func IsDryRunNotify(ctx context.Context) bool {
	v, _ := ctx.Value(dryRunNotifyKey).(bool)
	return v
}

func DryRunNotify(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Dry-Run-Notify") == "true" {
			r = r.WithContext(WithDryRunNotify(r.Context()))
		}
		next.ServeHTTP(w, r)
	})
}
