package aucjp

import (
	"context"
	"crypto/sha256"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/aucjp_client"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/scrapers"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/repository"
)

const pageSize = 20

type Scraper struct {
	client      *aucjp_client.Client
	catalogRepo *repository.CatalogRepository
}

func New(client *aucjp_client.Client, catalogRepo *repository.CatalogRepository) *Scraper {
	return &Scraper{
		client:      client,
		catalogRepo: catalogRepo,
	}
}

func (s *Scraper) Name() string {
	return "aucjp"
}

func (s *Scraper) Scrape(ctx context.Context, sub *scrapers.Subscription) ([]scrapers.Post, error) {
	var allPosts []scrapers.Post
	page := 1

	for {
		resp, err := s.client.FetchLots(ctx, sub.VendorID, sub.ModelName, page, pageSize)
		if err != nil {
			if page == 1 {
				return nil, fmt.Errorf("fetch lots page %d: %w", page, err)
			}
			log.Warn().Err(err).Int("page", page).Msg("Failed to fetch lots, stopping pagination")
			break
		}

		for _, lot := range resp.Lots {
			post := lotToPost(lot)
			allPosts = append(allPosts, post)
		}

		totalPages := 1
		if resp.Pagination.PageSize > 0 {
			totalPages = (resp.Pagination.TotalRows + resp.Pagination.PageSize - 1) / resp.Pagination.PageSize
		}

		if page >= totalPages || len(resp.Lots) == 0 {
			break
		}
		page++
	}

	log.Info().
		Int("vendor_id", sub.VendorID).
		Str("model", sub.ModelName).
		Int("lots_found", len(allPosts)).
		Int("pages", page).
		Msg("Scrape completed")

	return allPosts, nil
}

func lotToPost(lot aucjp_client.Lot) scrapers.Post {
	price := lot.LastPrice()
	hashInput := lot.LotNumber + lot.AuctionDate + lot.ChassisCode + price
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(hashInput)))

	year, _ := strconv.Atoi(lot.Year)

	title := fmt.Sprintf("Lot %s — %d %s %s %s¥",
		lot.LotNumber, year, lot.ChassisCode, lot.Grade, formatPrice(price))

	description := fmt.Sprintf(`<table>
<tr><th>Lot</th><td>%s</td></tr>
<tr><th>Auction</th><td>%s</td></tr>
<tr><th>Date</th><td>%s</td></tr>
<tr><th>Chassis</th><td>%s</td></tr>
<tr><th>Engine</th><td>%s cc</td></tr>
<tr><th>Year</th><td>%s</td></tr>
<tr><th>Price</th><td>%s ¥</td></tr>
<tr><th>Grade</th><td>%s</td></tr>
<tr><th>Transmission</th><td>%s</td></tr>
<tr><th>Rating</th><td>%s</td></tr>
<tr><th>Colour</th><td>%s</td></tr>
<tr><th>Status</th><td>%s</td></tr>
</table>`,
		lot.LotNumber, lot.AuctionName, lot.AuctionDate, lot.ChassisCode,
		lot.EngineCC, lot.Year, formatPrice(price), lot.Grade,
		lot.Transmission, lot.Rating, lot.Colour, lot.Status)

	pubDate := parseAuctionDate(lot.AuctionDate)

	extra := map[string]any{
		"lot_number":   lot.LotNumber,
		"auction_name": lot.AuctionName,
		"auction_date": lot.AuctionDate,
		"chassis_code": lot.ChassisCode,
		"engine_cc":    lot.EngineCC,
		"year":         lot.Year,
		"price_yen":    price,
		"price_list":   lot.PriceList,
		"final_price":  lot.FinalPrice,
		"grade":        lot.Grade,
		"transmission": lot.Transmission,
		"rating":       lot.Rating,
		"colour":       lot.Colour,
		"status":       lot.Status,
	}

	return scrapers.Post{
		Hash:        hash,
		Title:       title,
		Description: description,
		Link:        lot.Link(),
		PubDate:     pubDate,
		Extra:       extra,
	}
}

func (s *Scraper) SyncCatalog(ctx context.Context) error {
	vendors, models, err := s.client.FetchCatalog(ctx)
	if err != nil {
		return fmt.Errorf("fetch catalog: %w", err)
	}

	var entries []repository.CatalogEntry
	for _, v := range vendors {
		entries = append(entries, repository.CatalogEntry{
			VendorID:   v.ID,
			VendorName: v.Name,
			ModelName:  "",
			LotCount:   v.LotCount,
		})
	}
	for _, m := range models {
		vendorName := ""
		for _, v := range vendors {
			if v.ID == m.VendorID {
				vendorName = v.Name
				break
			}
		}
		entries = append(entries, repository.CatalogEntry{
			VendorID:   m.VendorID,
			VendorName: vendorName,
			ModelName:  m.Name,
			LotCount:   m.LotCount,
		})
	}

	if err := s.catalogRepo.UpsertCatalog(ctx, entries); err != nil {
		return fmt.Errorf("upsert catalog: %w", err)
	}

	log.Info().
		Int("vendors", len(vendors)).
		Int("models", len(models)).
		Msg("Catalog synced")
	return nil
}

func parseAuctionDate(s string) time.Time {
	formats := []string{
		"02.01.2006",
		"2006-01-02",
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
