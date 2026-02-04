package observability

import (
	"os"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func SetupLogger(serviceName string, debug bool) {
	zerolog.TimeFieldFormat = time.RFC3339Nano

	if debug {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
		log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339})
	} else {
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
		log.Logger = zerolog.New(os.Stdout).
			With().
			Timestamp().
			Str("service", serviceName).
			Logger()
	}
}

func Logger() *zerolog.Logger {
	return &log.Logger
}
