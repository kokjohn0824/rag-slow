package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"time"
)

// APIClient handles API calls to the trace demo service
type APIClient struct {
	baseURL string
	client  *http.Client
}

// NewAPIClient creates a new API client
func NewAPIClient(baseURL string, timeoutSeconds int) *APIClient {
	return &APIClient{
		baseURL: baseURL,
		client: &http.Client{
			Timeout: time.Duration(timeoutSeconds) * time.Second,
		},
	}
}

// OrderRequest represents an order creation request
type OrderRequest struct {
	UserID    string  `json:"user_id"`
	ProductID string  `json:"product_id"`
	Quantity  int     `json:"quantity"`
	Price     float64 `json:"price"`
}

// ReportRequest represents a report generation request
type ReportRequest struct {
	ReportType string   `json:"report_type"`
	StartDate  string   `json:"start_date"`
	EndDate    string   `json:"end_date"`
	Filters    []string `json:"filters"`
}

// BatchRequest represents a batch processing request
type BatchRequest struct {
	Items []string `json:"items"`
}

// CreateOrder calls the order creation API
func (c *APIClient) CreateOrder() error {
	orderReq := OrderRequest{
		UserID:    fmt.Sprintf("user_%d", time.Now().Unix()),
		ProductID: fmt.Sprintf("prod_%d", rand.Intn(1000)),
		Quantity:  rand.Intn(5) + 1,
		Price:     rand.Float64() * 500,
	}

	body, err := json.Marshal(orderReq)
	if err != nil {
		return fmt.Errorf("failed to marshal order request: %w", err)
	}

	resp, err := c.client.Post(
		c.baseURL+"/api/order/create",
		"application/json",
		bytes.NewBuffer(body),
	)
	if err != nil {
		return fmt.Errorf("failed to call order API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("order API returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// GetUserProfile calls the user profile API
func (c *APIClient) GetUserProfile() error {
	userID := fmt.Sprintf("user_%d", rand.Intn(10000))
	url := fmt.Sprintf("%s/api/user/profile?user_id=%s", c.baseURL, userID)

	resp, err := c.client.Get(url)
	if err != nil {
		return fmt.Errorf("failed to call user profile API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("user profile API returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// GenerateReport calls the report generation API
func (c *APIClient) GenerateReport() error {
	// Generate date range (last 30 days)
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -30)

	reportReq := ReportRequest{
		ReportType: "sales",
		StartDate:  startDate.Format("2006-01-02"),
		EndDate:    endDate.Format("2006-01-02"),
		Filters:    []string{"active", "completed"},
	}

	body, err := json.Marshal(reportReq)
	if err != nil {
		return fmt.Errorf("failed to marshal report request: %w", err)
	}

	resp, err := c.client.Post(
		c.baseURL+"/api/report/generate",
		"application/json",
		bytes.NewBuffer(body),
	)
	if err != nil {
		return fmt.Errorf("failed to call report API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("report API returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// Search calls the search API
func (c *APIClient) Search() error {
	queries := []string{"laptop", "phone", "tablet", "monitor", "keyboard"}
	query := queries[rand.Intn(len(queries))]
	page := rand.Intn(3) + 1
	limit := 10

	url := fmt.Sprintf("%s/api/search?q=%s&page=%d&limit=%d", c.baseURL, query, page, limit)

	resp, err := c.client.Get(url)
	if err != nil {
		return fmt.Errorf("failed to call search API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("search API returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// BatchProcess calls the batch processing API
func (c *APIClient) BatchProcess() error {
	itemCount := rand.Intn(10) + 5
	items := make([]string, itemCount)
	for i := 0; i < itemCount; i++ {
		items[i] = fmt.Sprintf("item_%d", i+1)
	}

	batchReq := BatchRequest{
		Items: items,
	}

	body, err := json.Marshal(batchReq)
	if err != nil {
		return fmt.Errorf("failed to marshal batch request: %w", err)
	}

	resp, err := c.client.Post(
		c.baseURL+"/api/batch/process",
		"application/json",
		bytes.NewBuffer(body),
	)
	if err != nil {
		return fmt.Errorf("failed to call batch API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("batch API returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}

// Simulate calls the simulation API
func (c *APIClient) Simulate() error {
	depth := rand.Intn(3) + 2            // 2-4
	breadth := rand.Intn(2) + 2          // 2-3
	duration := rand.Intn(100) + 50      // 50-150ms
	variance := 0.3 + rand.Float64()*0.4 // 0.3-0.7

	url := fmt.Sprintf("%s/api/simulate?depth=%d&breadth=%d&duration=%d&variance=%.2f",
		c.baseURL, depth, breadth, duration, variance)

	resp, err := c.client.Get(url)
	if err != nil {
		return fmt.Errorf("failed to call simulate API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("simulate API returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return nil
}
