package aucjp

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/crawl4ai"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/scrapers"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/repository"
)

const (
	baseURL       = "https://aucjp.co"
	searchPageURL = baseURL + "/japan_st"
)

type Scraper struct {
	client      *crawl4ai.Client
	catalogRepo *repository.CatalogRepository
}

func New(client *crawl4ai.Client, catalogRepo *repository.CatalogRepository) *Scraper {
	return &Scraper{
		client:      client,
		catalogRepo: catalogRepo,
	}
}

func (s *Scraper) Name() string {
	return "aucjp"
}

type rawLot struct {
	LotNumber   string `json:"lot_number"`
	AuctionDate string `json:"auction_date"`
	ChassisID   string `json:"chassis_id"`
	EngineCC    string `json:"engine_cc"`
	Year        string `json:"year"`
	PriceYen    string `json:"price_yen"`
	Equipment   string `json:"equipment"`
	Colour      string `json:"colour"`
	Link        string `json:"link"`
}

func (s *Scraper) Scrape(ctx context.Context, sub *scrapers.Subscription) ([]scrapers.Post, error) {
	sessionID := fmt.Sprintf("aucjp-%s", uuid.New().String())

	// Step 1: Load the search page
	resp, err := s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs: []string{searchPageURL},
		CrawlerConfig: &crawl4ai.CrawlerConfig{
			SessionID: sessionID,
			WaitFor:   "body",
			CacheMode: "bypass",
		},
	})
	if err != nil {
		return nil, fmt.Errorf("load search page: %w", err)
	}
	if !resp.Success || len(resp.Results) == 0 || !resp.Results[0].Success {
		return nil, fmt.Errorf("search page load failed")
	}

	// Step 2: Click vendor matching subscription's vendor_id
	// TODO: Adjust CSS selectors after inspecting the live aucjp.co DOM structure
	vendorClickJS := fmt.Sprintf(`
		(function() {
			const vendorLinks = document.querySelectorAll('a[data-vendor-id], .vendor-list a, .maker-list a');
			for (const link of vendorLinks) {
				const vid = link.getAttribute('data-vendor-id');
				if (vid === '%d') {
					link.click();
					return 'clicked';
				}
			}
			return 'not_found';
		})()
	`, sub.VendorID)

	resp, err = s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs: []string{searchPageURL},
		CrawlerConfig: &crawl4ai.CrawlerConfig{
			SessionID: sessionID,
			JSCode:    []string{vendorClickJS},
			WaitFor:   "body",
			CacheMode: "bypass",
		},
	})
	if err != nil {
		return nil, fmt.Errorf("click vendor: %w", err)
	}
	if len(resp.Results) > 0 && resp.Results[0].JSExecutionResult != nil {
		log.Debug().Strs("js_results", resp.Results[0].JSExecutionResult.Results).Msg("Vendor click result")
	}

	// Step 3: Click model matching subscription's model_name
	// TODO: Adjust selector for model list based on live DOM
	modelClickJS := fmt.Sprintf(`
		(function() {
			const modelLinks = document.querySelectorAll('.model-list a, a[data-model]');
			for (const link of modelLinks) {
				const name = (link.getAttribute('data-model') || link.textContent).trim().toUpperCase();
				if (name === '%s' || name.includes('%s')) {
					link.click();
					return 'clicked';
				}
			}
			return 'not_found';
		})()
	`, strings.ToUpper(sub.ModelName), strings.ToUpper(sub.ModelName))

	resp, err = s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs: []string{searchPageURL},
		CrawlerConfig: &crawl4ai.CrawlerConfig{
			SessionID: sessionID,
			JSCode:    []string{modelClickJS},
			WaitFor:   "body",
			CacheMode: "bypass",
		},
	})
	if err != nil {
		return nil, fmt.Errorf("click model: %w", err)
	}

	// Step 4: Extract lot data from the results table via JS
	var allPosts []scrapers.Post
	page := 1

	for {
		lots, hasNext, err := s.extractLots(ctx, sessionID, page)
		if err != nil {
			if page == 1 {
				return nil, fmt.Errorf("extract lots page %d: %w", page, err)
			}
			log.Warn().Err(err).Int("page", page).Msg("Failed to extract lots, stopping pagination")
			break
		}

		for _, lot := range lots {
			post, err := lotToPost(lot)
			if err != nil {
				log.Warn().Err(err).Str("lot_number", lot.LotNumber).Msg("Failed to convert lot to post")
				continue
			}
			allPosts = append(allPosts, *post)
		}

		if !hasNext || len(lots) == 0 {
			break
		}

		// TODO: Adjust pagination JS based on actual aucjp.co pagination controls
		nextPageJS := `
			(function() {
				const nextBtn = document.querySelector('.pagination .next a, a.next-page, [data-page="next"]');
				if (nextBtn) {
					nextBtn.click();
					return 'clicked';
				}
				return 'no_next';
			})()
		`
		_, err = s.client.Crawl(ctx, crawl4ai.CrawlRequest{
			URLs: []string{searchPageURL},
			CrawlerConfig: &crawl4ai.CrawlerConfig{
				SessionID: sessionID,
				JSCode:    []string{nextPageJS},
				WaitFor:   "body",
				CacheMode: "bypass",
			},
		})
		if err != nil {
			log.Warn().Err(err).Int("page", page+1).Msg("Failed to navigate to next page, stopping")
			break
		}

		page++
	}

	log.Info().
		Int("vendor_id", sub.VendorID).
		Str("model", sub.ModelName).
		Int("lots_found", len(allPosts)).
		Msg("Scrape completed")

	return allPosts, nil
}

func (s *Scraper) extractLots(ctx context.Context, sessionID string, page int) ([]rawLot, bool, error) {
	// TODO: Adjust the extraction JS to match actual aucjp.co table structure
	extractJS := `
		(function() {
			const rows = document.querySelectorAll('table tbody tr');
			const lots = [];
			let hasNext = false;

			const nextBtn = document.querySelector('.pagination .next a, a.next-page, [data-page="next"]');
			if (nextBtn && !nextBtn.classList.contains('disabled')) {
				hasNext = true;
			}

			for (const row of rows) {
				const cells = row.querySelectorAll('td');
				if (cells.length < 5) continue;

				const linkEl = row.querySelector('a[href]');
				const link = linkEl ? linkEl.href : '';

				lots.push({
					lot_number: (cells[0] || {}).textContent?.trim() || '',
					auction_date: (cells[1] || {}).textContent?.trim() || '',
					chassis_id: (cells[2] || {}).textContent?.trim() || '',
					engine_cc: (cells[3] || {}).textContent?.trim() || '',
					year: (cells[4] || {}).textContent?.trim() || '',
					price_yen: (cells[5] || {}).textContent?.trim() || '',
					equipment: (cells[6] || {}).textContent?.trim() || '',
					colour: (cells[7] || {}).textContent?.trim() || '',
					link: link
				});
			}

			return JSON.stringify({lots: lots, has_next: hasNext});
		})()
	`

	resp, err := s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs: []string{searchPageURL},
		CrawlerConfig: &crawl4ai.CrawlerConfig{
			SessionID: sessionID,
			JSCode:    []string{extractJS},
			CacheMode: "bypass",
		},
	})
	if err != nil {
		return nil, false, fmt.Errorf("crawl for extraction: %w", err)
	}

	if len(resp.Results) == 0 || resp.Results[0].JSExecutionResult == nil {
		return nil, false, fmt.Errorf("no JS execution result")
	}

	jsResults := resp.Results[0].JSExecutionResult.Results
	if len(jsResults) == 0 {
		return nil, false, fmt.Errorf("empty JS result")
	}

	var result struct {
		Lots    []rawLot `json:"lots"`
		HasNext bool     `json:"has_next"`
	}
	if err := json.Unmarshal([]byte(jsResults[0]), &result); err != nil {
		return nil, false, fmt.Errorf("unmarshal extraction result: %w", err)
	}

	return result.Lots, result.HasNext, nil
}

func lotToPost(lot rawLot) (*scrapers.Post, error) {
	hashInput := lot.LotNumber + lot.AuctionDate + lot.ChassisID + lot.PriceYen
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(hashInput)))

	year, _ := strconv.Atoi(lot.Year)

	title := fmt.Sprintf("Lot %s — %d %s %s %s¥",
		lot.LotNumber, year, lot.ChassisID, lot.Equipment, formatPrice(lot.PriceYen))

	description := fmt.Sprintf(`<table>
<tr><th>Lot</th><td>%s</td></tr>
<tr><th>Date</th><td>%s</td></tr>
<tr><th>Chassis</th><td>%s</td></tr>
<tr><th>Engine</th><td>%s cc</td></tr>
<tr><th>Year</th><td>%s</td></tr>
<tr><th>Price</th><td>%s ¥</td></tr>
<tr><th>Equipment</th><td>%s</td></tr>
<tr><th>Colour</th><td>%s</td></tr>
</table>`,
		lot.LotNumber, lot.AuctionDate, lot.ChassisID, lot.EngineCC,
		lot.Year, formatPrice(lot.PriceYen), lot.Equipment, lot.Colour)

	pubDate := parseAuctionDate(lot.AuctionDate)

	link := lot.Link
	if link == "" {
		link = baseURL
	}

	extra := map[string]any{
		"lot_number":   lot.LotNumber,
		"auction_date": lot.AuctionDate,
		"chassis_id":   lot.ChassisID,
		"engine_cc":    lot.EngineCC,
		"year":         lot.Year,
		"price_yen":    lot.PriceYen,
		"equipment":    lot.Equipment,
		"colour":       lot.Colour,
	}

	return &scrapers.Post{
		Hash:        hash,
		Title:       title,
		Description: description,
		Link:        link,
		PubDate:     pubDate,
		Extra:       extra,
	}, nil
}

func parseAuctionDate(s string) time.Time {
	formats := []string{
		"2006-01-02",
		"02.01.2006",
		"2006/01/02",
		"01/02/2006",
	}
	for _, f := range formats {
		if t, err := time.Parse(f, s); err == nil {
			return t
		}
	}
	return time.Now()
}

func formatPrice(price string) string {
	clean := strings.ReplaceAll(price, ",", "")
	clean = strings.ReplaceAll(clean, " ", "")
	clean = strings.TrimSpace(clean)

	n, err := strconv.ParseInt(clean, 10, 64)
	if err != nil {
		return price
	}

	s := strconv.FormatInt(n, 10)
	result := make([]byte, 0, len(s)+len(s)/3)
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			result = append(result, ',')
		}
		result = append(result, byte(c))
	}
	return string(result)
}

func (s *Scraper) SyncCatalog(ctx context.Context) error {
	sessionID := fmt.Sprintf("aucjp-catalog-%s", uuid.New().String())

	// TODO: This extracts vendor list from the initial page.
	// Full catalog sync (vendors + models) requires clicking each vendor.
	// For now, we extract vendors only.
	extractCatalogJS := `
		(function() {
			const vendors = [];
			const vendorEls = document.querySelectorAll('a[data-vendor-id], .vendor-list a, .maker-list a');
			for (const el of vendorEls) {
				const vid = el.getAttribute('data-vendor-id') || '';
				const text = el.textContent.trim();
				const countMatch = text.match(/\((\d+)\)/);
				const count = countMatch ? parseInt(countMatch[1]) : 0;
				const cleanName = text.replace(/\s*\(\d+\)\s*$/, '').trim();
				vendors.push({vendor_id: parseInt(vid) || 0, vendor_name: cleanName, count: count});
			}
			return JSON.stringify(vendors);
		})()
	`

	resp, err := s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs: []string{searchPageURL},
		CrawlerConfig: &crawl4ai.CrawlerConfig{
			SessionID: sessionID,
			JSCode:    []string{extractCatalogJS},
			WaitFor:   "body",
			CacheMode: "bypass",
		},
	})
	if err != nil {
		return fmt.Errorf("crawl for catalog: %w", err)
	}

	if len(resp.Results) == 0 || resp.Results[0].JSExecutionResult == nil {
		return fmt.Errorf("no JS execution result for catalog")
	}

	jsResults := resp.Results[0].JSExecutionResult.Results
	if len(jsResults) == 0 {
		return fmt.Errorf("empty JS result for catalog")
	}

	var vendors []struct {
		VendorID   int    `json:"vendor_id"`
		VendorName string `json:"vendor_name"`
		Count      int    `json:"count"`
	}
	if err := json.Unmarshal([]byte(jsResults[0]), &vendors); err != nil {
		return fmt.Errorf("unmarshal vendors: %w", err)
	}

	var entries []repository.CatalogEntry
	for _, v := range vendors {
		if v.VendorID == 0 || v.VendorName == "" {
			continue
		}
		entries = append(entries, repository.CatalogEntry{
			VendorID:   v.VendorID,
			VendorName: v.VendorName,
			ModelName:  "",
			LotCount:   v.Count,
		})
	}

	if err := s.catalogRepo.UpsertCatalog(ctx, entries); err != nil {
		return fmt.Errorf("upsert catalog: %w", err)
	}

	log.Info().Int("vendors", len(entries)).Msg("Catalog synced")
	return nil
}
