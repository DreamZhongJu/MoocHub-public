package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const fcmScope = "https://www.googleapis.com/auth/firebase.messaging"

type FCMClient struct {
	projectID  string
	httpClient *http.Client
}

type serviceAccount struct {
	ProjectID string `json:"project_id"`
}

func NewFCMClient(ctx context.Context, serviceAccountPath, projectID string) (*FCMClient, error) {
	if serviceAccountPath == "" {
		return nil, errors.New("FCM service account path is empty")
	}
	raw, err := os.ReadFile(serviceAccountPath)
	if err != nil {
		return nil, fmt.Errorf("read service account: %w", err)
	}

	if projectID == "" {
		var sa serviceAccount
		if err := json.Unmarshal(raw, &sa); err == nil && sa.ProjectID != "" {
			projectID = sa.ProjectID
		}
	}
	if projectID == "" {
		return nil, errors.New("FCM project_id is empty")
	}

	creds, err := google.CredentialsFromJSON(ctx, raw, fcmScope)
	if err != nil {
		return nil, fmt.Errorf("parse credentials: %w", err)
	}

	client := oauth2.NewClient(ctx, creds.TokenSource)
	return &FCMClient{projectID: projectID, httpClient: client}, nil
}

func (c *FCMClient) SendToToken(ctx context.Context, token, title, body string, data map[string]string) error {
	if c == nil || c.httpClient == nil {
		return errors.New("FCM client not initialized")
	}
	if token == "" {
		return errors.New("token is empty")
	}

	payload := map[string]any{
		"message": map[string]any{
			"token": token,
			"notification": map[string]string{
				"title": title,
				"body":  body,
			},
			"data": data,
			"android": map[string]any{
				"notification": map[string]any{
					"channel_id": "important_channel",
				},
			},
		},
	}

	bodyBytes, _ := json.Marshal(payload)
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", c.projectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("FCM send failed: %s", resp.Status)
	}
	return nil
}
