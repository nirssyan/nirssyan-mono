package logging

import (
	"os"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func Setup(serviceName string, debug bool) {
	zerolog.TimeFieldFormat = time.RFC3339Nano

	if debug {
		log.Logger = zerolog.New(zerolog.ConsoleWriter{
			Out:        os.Stderr,
			TimeFormat: "15:04:05.000",
		}).With().
			Timestamp().
			Str("service", serviceName).
			Logger()
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	} else {
		log.Logger = zerolog.New(os.Stderr).With().
			Timestamp().
			Str("service", serviceName).
			Logger()
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
	}
}
