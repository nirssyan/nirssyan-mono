package aucjp_client

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"github.com/rs/zerolog/log"
)

type Vendor struct {
	ID       int
	Name     string
	LotCount int
}

type Model struct {
	VendorID int
	Name     string
	LotCount int
}

var (
	manufStrRe = regexp.MustCompile(`id=manuf_str[^>]*>([^<]+)<`)
	modelStrRe = regexp.MustCompile(`id=model_str[^>]*>([^<]+)<`)
)

func (c *Client) FetchCatalog(ctx context.Context) ([]Vendor, []Model, error) {
	html, err := c.FetchPage(ctx, searchPageURL)
	if err != nil {
		return nil, nil, fmt.Errorf("fetch search page: %w", err)
	}

	log.Debug().
		Int("page_size", len(html)).
		Bool("has_manuf_str", strings.Contains(html, "manuf_str")).
		Bool("has_model_str", strings.Contains(html, "model_str")).
		Bool("has_toyota", strings.Contains(html, "TOYOTA")).
		Msg("Catalog page fetched")

	vendors := parseVendors(html)
	models := parseModels(html)

	return vendors, models, nil
}

func parseVendors(html string) []Vendor {
	m := manufStrRe.FindStringSubmatch(html)
	if m == nil {
		return nil
	}
	return parseVendorString(m[1])
}

func parseVendorString(s string) []Vendor {
	var vendors []Vendor
	for _, entry := range strings.Split(s, ";") {
		entry = strings.TrimSpace(entry)
		if entry == "" {
			continue
		}
		// Format: "id:name (count)" or "id:name"
		parts := strings.SplitN(entry, ":", 2)
		if len(parts) != 2 {
			continue
		}
		id, err := strconv.Atoi(strings.TrimSpace(parts[0]))
		if err != nil {
			continue
		}
		nameAndCount := strings.TrimSpace(parts[1])
		name, count := extractNameAndCount(nameAndCount)
		if name == "" {
			continue
		}
		vendors = append(vendors, Vendor{ID: id, Name: name, LotCount: count})
	}
	return vendors
}

func parseModels(html string) []Model {
	m := modelStrRe.FindStringSubmatch(html)
	if m == nil {
		return nil
	}
	return parseModelString(m[1])
}

func parseModelString(s string) []Model {
	var models []Model
	for _, entry := range strings.Split(s, ";") {
		entry = strings.TrimSpace(entry)
		if entry == "" {
			continue
		}
		// Format: "vendorID:modelName (count)"
		parts := strings.SplitN(entry, ":", 2)
		if len(parts) != 2 {
			continue
		}
		vendorID, err := strconv.Atoi(strings.TrimSpace(parts[0]))
		if err != nil {
			continue
		}
		nameAndCount := strings.TrimSpace(parts[1])
		name, count := extractNameAndCount(nameAndCount)
		if name == "" {
			continue
		}
		models = append(models, Model{VendorID: vendorID, Name: name, LotCount: count})
	}
	return models
}

var countInParensRe = regexp.MustCompile(`\s*\((\d+)\)\s*$`)

func extractNameAndCount(s string) (string, int) {
	m := countInParensRe.FindStringSubmatch(s)
	if m == nil {
		return strings.TrimSpace(s), 0
	}
	name := strings.TrimSpace(s[:len(s)-len(m[0])])
	count, _ := strconv.Atoi(m[1])
	return name, count
}
