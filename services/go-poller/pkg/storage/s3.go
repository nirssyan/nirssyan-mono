package storage

import (
	"context"
	"io"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type S3Client struct {
	client *minio.Client
}

func NewS3Client(endpoint, accessKey, secretKey string, useSSL bool) (*S3Client, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, err
	}
	return &S3Client{client: client}, nil
}

func (c *S3Client) Upload(ctx context.Context, bucket, key string, reader io.Reader, size int64, contentType string) error {
	_, err := c.client.PutObject(ctx, bucket, key, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}

func (c *S3Client) Download(ctx context.Context, bucket, key string) (io.ReadCloser, error) {
	return c.client.GetObject(ctx, bucket, key, minio.GetObjectOptions{})
}

func (c *S3Client) Exists(ctx context.Context, bucket, key string) (bool, error) {
	_, err := c.client.StatObject(ctx, bucket, key, minio.StatObjectOptions{})
	if err != nil {
		errResp := minio.ToErrorResponse(err)
		if errResp.Code == "NoSuchKey" {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (c *S3Client) ListPrefix(ctx context.Context, bucket, prefix string) ([]string, error) {
	var keys []string
	opts := minio.ListObjectsOptions{Prefix: prefix, Recursive: true}
	for obj := range c.client.ListObjects(ctx, bucket, opts) {
		if obj.Err != nil {
			return keys, obj.Err
		}
		keys = append(keys, obj.Key)
	}
	return keys, nil
}
