package service

import "github.com/alexedwards/argon2id"

var argon2Params = &argon2id.Params{
	Memory:      64 * 1024, // 64 MiB (RFC 9106)
	Iterations:  3,
	Parallelism: 4,
	SaltLength:  16,
	KeyLength:   32,
}

func HashPassword(password string) (string, error) {
	return argon2id.CreateHash(password, argon2Params)
}

func VerifyPassword(password, hash string) (bool, error) {
	return argon2id.ComparePasswordAndHash(password, hash)
}
