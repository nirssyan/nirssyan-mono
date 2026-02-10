package main

import (
	"context"
	"fmt"

	"dagger/go-api-ci/internal/dagger"
)

type GoApiCi struct{}

func (m *GoApiCi) goBase(source *dagger.Directory) *dagger.Container {
	return dag.Container().
		From("golang:1.24-alpine").
		WithDirectory("/src", source, dagger.ContainerWithDirectoryOpts{
			Exclude: []string{".git", ".dagger"},
		}).
		WithWorkdir("/src").
		WithMountedCache("/go/pkg/mod", dag.CacheVolume("go-mod-124")).
		WithEnvVariable("GOMODCACHE", "/go/pkg/mod").
		WithMountedCache("/go/build-cache", dag.CacheVolume("go-build-124")).
		WithEnvVariable("GOCACHE", "/go/build-cache")
}

func (m *GoApiCi) Test(ctx context.Context, source *dagger.Directory) error {
	_, err := m.goBase(source).
		WithExec([]string{"go", "test", "-v", "./..."}).
		Sync(ctx)
	return err
}

func (m *GoApiCi) Build(ctx context.Context, source *dagger.Directory) *dagger.File {
	return m.goBase(source).
		WithEnvVariable("CGO_ENABLED", "0").
		WithEnvVariable("GOOS", "linux").
		WithEnvVariable("GOARCH", "amd64").
		WithExec([]string{"go", "build", "-ldflags=-w -s", "-o", "/api", "./cmd/api"}).
		File("/api")
}

func (m *GoApiCi) Containerize(ctx context.Context, source *dagger.Directory) *dagger.Container {
	binary := m.Build(ctx, source)

	return dag.Container(dagger.ContainerOpts{Platform: "linux/amd64"}).
		From("alpine:3.21").
		WithExec([]string{"apk", "add", "--no-cache", "ca-certificates", "tzdata"}).
		WithExec([]string{"adduser", "-D", "-u", "1000", "appuser"}).
		WithFile("/app/api", binary).
		WithWorkdir("/app").
		WithUser("appuser").
		WithExposedPort(8080).
		WithExposedPort(9464).
		WithEntrypoint([]string{"/app/api"})
}

func (m *GoApiCi) Publish(
	ctx context.Context,
	source *dagger.Directory,
	registry string,
	tag string,
) (string, error) {
	ctr := m.Containerize(ctx, source)
	addr := fmt.Sprintf("%s/go-api:%s", registry, tag)
	return ctr.Publish(ctx, addr)
}
