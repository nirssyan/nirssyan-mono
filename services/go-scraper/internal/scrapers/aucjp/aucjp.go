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
	defer func() {
		if err := s.client.CloseSession(ctx, sessionID); err != nil {
			log.Warn().Err(err).Str("session_id", sessionID).Msg("Failed to close crawl4ai session")
		}
	}()

	// Step 1: Load the search page
	resp, err := s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs:      []string{searchPageURL},
		SessionID: sessionID,
		WaitFor:   "css:.ajx-frame",
		CacheMode: "bypass",
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
			const vendorLinks = document.querySelectorAll('.ajx-frame a[data-vendor-id], .vendor-list a, .maker-list a');
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
		URLs:      []string{searchPageURL},
		SessionID: sessionID,
		JSCode:    []string{vendorClickJS},
		WaitFor:   "css:.model-list, css:.ajx-frame table",
		CacheMode: "bypass",
	})
	if err != nil {
		return nil, fmt.Errorf("click vendor: %w", err)
	}

	// Step 3: Click model matching subscription's model_name
	// TODO: Adjust selector for model list based on live DOM
	modelClickJS := fmt.Sprintf(`
		(function() {
			const modelLinks = document.querySelectorAll('.model-list a, .ajx-frame a[data-model]');
			for (const link of modelLinks) {
				const name = link.getAttribute('data-model') || link.textContent.trim();
				if (name === '%s' || link.textContent.trim().toUpperCase().includes('%s')) {
					link.click();
					return 'clicked';
				}
			}
			return 'not_found';
		})()
	`, sub.ModelName, strings.ToUpper(sub.ModelName))

	resp, err = s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs:      []string{searchPageURL},
		SessionID: sessionID,
		JSCode:    []string{modelClickJS},
		WaitFor:   "css:table.result-table, css:.lot-table, css:.ajx-frame table",
		CacheMode: "bypass",
	})
	if err != nil {
		return nil, fmt.Errorf("click model: %w", err)
	}

	// Step 4: Extract lot data from the results table
	var allPosts []scrapers.Post
	page := 1

	for {
		lots, hasNext, err := s.extractLots(ctx, sessionID, page)
		if err != nil {
			return nil, fmt.Errorf("extract lots page %d: %w", page, err)
		}

		for _, lot := range lots {
			post, err := lotToPost(lot)
			if err != nil {
				log.Warn().Err(err).Str("lot_number", lot.LotNumber).Msg("Failed to convert lot to post")
				continue
			}
			allPosts = append(allPosts, *post)
		}

		if !hasNext {
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
		resp, err = s.client.Crawl(ctx, crawl4ai.CrawlRequest{
			URLs:      []string{searchPageURL},
			SessionID: sessionID,
			JSCode:    []string{nextPageJS},
			WaitFor:   "css:table.result-table, css:.lot-table",
			CacheMode: "bypass",
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
			const rows = document.querySelectorAll('table.result-table tbody tr, .lot-table tbody tr, .ajx-frame table tbody tr');
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

	jsResp, err := s.client.ExecuteJS(ctx, sessionID, extractJS)
	if err != nil {
		return nil, false, fmt.Errorf("execute extraction js: %w", err)
	}

	var result struct {
		Lots    []rawLot `json:"lots"`
		HasNext bool     `json:"has_next"`
	}
	if err := json.Unmarshal([]byte(jsResp.Result), &result); err != nil {
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
	defer func() {
		if err := s.client.CloseSession(ctx, sessionID); err != nil {
			log.Warn().Err(err).Msg("Failed to close catalog session")
		}
	}()

	resp, err := s.client.Crawl(ctx, crawl4ai.CrawlRequest{
		URLs:      []string{searchPageURL},
		SessionID: sessionID,
		WaitFor:   "css:.ajx-frame",
		CacheMode: "bypass",
	})
	if err != nil {
		return fmt.Errorf("load page for catalog: %w", err)
	}
	if !resp.Success || len(resp.Results) == 0 {
		return fmt.Errorf("catalog page load failed")
	}

	// TODO: This extracts vendor list from the initial page.
	// Full catalog sync (vendors + models) requires clicking each vendor
	// to get its model list. For now, we extract vendors only.
	// Model-level catalog will be populated as subscriptions are created.
	extractCatalogJS := `
		(function() {
			const vendors = [];
			const vendorEls = document.querySelectorAll('.vendor-list a, .maker-list a, .ajx-frame a[data-vendor-id]');
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

	jsResp, err := s.client.ExecuteJS(ctx, sessionID, extractCatalogJS)
	if err != nil {
		return fmt.Errorf("extract catalog vendors: %w", err)
	}

	var vendors []struct {
		VendorID   int    `json:"vendor_id"`
		VendorName string `json:"vendor_name"`
		Count      int    `json:"count"`
	}
	if err := json.Unmarshal([]byte(jsResp.Result), &vendors); err != nil {
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
