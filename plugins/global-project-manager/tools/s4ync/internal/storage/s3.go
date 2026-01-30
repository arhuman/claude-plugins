package storage

import (
	"bytes"
	"context"
	"io"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/arhuman/s4ync/internal/config"
)

// S3Storage implements Storage for MinIO S3.
type S3Storage struct {
	client     *minio.Client
	bucketName string
	prefix     string
}

// NewMinioClient creates a MinIO client from the given configuration.
func NewMinioClient(cfg *config.Config) (*minio.Client, error) {
	return minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure: cfg.MinIOSecure,
	})
}

// NewS3Storage creates a new S3Storage with the given configuration.
func NewS3Storage(cfg *config.Config, shortname string) (*S3Storage, error) {
	client, err := NewMinioClient(cfg)
	if err != nil {
		return nil, err
	}

	return &S3Storage{
		client:     client,
		bucketName: cfg.BucketName,
		prefix:     shortname + "/",
	}, nil
}

// NewS3StorageWithClient creates an S3Storage with an existing client (for testing).
func NewS3StorageWithClient(client *minio.Client, bucketName, shortname string) *S3Storage {
	return &S3Storage{
		client:     client,
		bucketName: bucketName,
		prefix:     shortname + "/",
	}
}

// EnsureBucket creates the bucket if it doesn't exist.
func (s *S3Storage) EnsureBucket(ctx context.Context) error {
	exists, err := s.client.BucketExists(ctx, s.bucketName)
	if err != nil {
		return err
	}
	if !exists {
		return s.client.MakeBucket(ctx, s.bucketName, minio.MakeBucketOptions{})
	}
	return nil
}

// List returns all files under the given prefix.
func (s *S3Storage) List(prefix string) ([]FileInfo, error) {
	var files []FileInfo
	ctx := context.Background()

	fullPrefix := s.prefix
	if prefix != "" {
		fullPrefix = s.prefix + prefix
	}

	objectCh := s.client.ListObjects(ctx, s.bucketName, minio.ListObjectsOptions{
		Prefix:    fullPrefix,
		Recursive: true,
	})

	for object := range objectCh {
		if object.Err != nil {
			return nil, object.Err
		}

		// Remove prefix to get relative path
		relPath := object.Key[len(s.prefix):]

		files = append(files, FileInfo{
			Path:    relPath,
			ModTime: object.LastModified,
			Size:    object.Size,
		})
	}

	return files, nil
}

// Read returns the contents of a file.
func (s *S3Storage) Read(path string) ([]byte, error) {
	ctx := context.Background()
	objectKey := s.prefix + path

	obj, err := s.client.GetObject(ctx, s.bucketName, objectKey, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	defer obj.Close()

	return io.ReadAll(obj)
}

// Write writes data to a file.
func (s *S3Storage) Write(path string, data []byte) error {
	ctx := context.Background()
	objectKey := s.prefix + path

	_, err := s.client.PutObject(ctx, s.bucketName, objectKey, bytes.NewReader(data),
		int64(len(data)), minio.PutObjectOptions{
			ContentType: "text/markdown",
		})

	return err
}

// GetModTime returns the modification time of a file.
func (s *S3Storage) GetModTime(path string) (time.Time, error) {
	ctx := context.Background()
	objectKey := s.prefix + path

	objInfo, err := s.client.StatObject(ctx, s.bucketName, objectKey, minio.StatObjectOptions{})
	if err != nil {
		return time.Time{}, err
	}

	return objInfo.LastModified, nil
}

// Delete removes a file.
func (s *S3Storage) Delete(path string) error {
	ctx := context.Background()
	objectKey := s.prefix + path

	return s.client.RemoveObject(ctx, s.bucketName, objectKey, minio.RemoveObjectOptions{})
}

// Exists checks if a file exists.
func (s *S3Storage) Exists(path string) (bool, error) {
	ctx := context.Background()
	objectKey := s.prefix + path

	_, err := s.client.StatObject(ctx, s.bucketName, objectKey, minio.StatObjectOptions{})
	if err != nil {
		errResp := minio.ToErrorResponse(err)
		if errResp.Code == "NoSuchKey" {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// Prefix returns the S3 prefix (shortname/).
func (s *S3Storage) Prefix() string {
	return s.prefix
}

// BucketName returns the bucket name.
func (s *S3Storage) BucketName() string {
	return s.bucketName
}
