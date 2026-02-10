package handlers

import (
	"context"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	pgx "github.com/jackc/pgx/v5"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-rss-api/repository"
)

type RSSHandler struct {
	catalog      *repository.CatalogRepository
	subscription *repository.SubscriptionRepository
	post         *repository.PostRepository
}

func NewRSSHandler(
	catalog *repository.CatalogRepository,
	subscription *repository.SubscriptionRepository,
	post *repository.PostRepository,
) *RSSHandler {
	return &RSSHandler{
		catalog:      catalog,
		subscription: subscription,
		post:         post,
	}
}

func (h *RSSHandler) GetVendors(w http.ResponseWriter, r *http.Request) {
	vendors, err := h.catalog.GetVendors(r.Context())
	if err != nil {
		log.Error().Err(err).Msg("Failed to get vendors")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, vendors)
}

func (h *RSSHandler) GetModels(w http.ResponseWriter, r *http.Request) {
	vendorIDStr := chi.URLParam(r, "vendor_id")
	vendorID, err := strconv.Atoi(vendorIDStr)
	if err != nil {
		http.Error(w, "invalid vendor_id", http.StatusBadRequest)
		return
	}

	models, err := h.catalog.GetModels(r.Context(), vendorID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get models")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, models)
}

func (h *RSSHandler) GetRSSByVendorModel(w http.ResponseWriter, r *http.Request) {
	vendorParam := chi.URLParam(r, "vendor")
	modelName := chi.URLParam(r, "model")

	ctx := r.Context()

	vendorID, vendorName, err := h.resolveVendor(ctx, vendorParam)
	if err != nil {
		log.Error().Err(err).Str("vendor", vendorParam).Msg("Failed to resolve vendor")
		http.Error(w, "vendor not found", http.StatusNotFound)
		return
	}

	sub, err := h.subscription.GetByVendorModel(ctx, vendorID, modelName)
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			log.Error().Err(err).Msg("Failed to get subscription")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		slug := strings.ToLower(vendorName + "-" + modelName)
		sub = &repository.Subscription{
			VendorID:  vendorID,
			ModelName: strings.ToUpper(modelName),
			Slug:      slug,
		}
		if err := h.subscription.Create(ctx, sub); err != nil {
			log.Error().Err(err).Msg("Failed to create subscription")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		modelName = sub.ModelName
	}

	h.writeRSSFeed(ctx, w, vendorID, vendorName, modelName)
}

func (h *RSSHandler) GetRSSBySlug(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	ctx := r.Context()

	sub, err := h.subscription.GetBySlug(ctx, slug)
	if err != nil {
		http.Error(w, "subscription not found", http.StatusNotFound)
		return
	}

	vendorName, err := h.catalog.GetVendorName(ctx, sub.VendorID)
	if err != nil {
		vendorName = fmt.Sprintf("Vendor %d", sub.VendorID)
	}

	h.writeRSSFeed(ctx, w, sub.VendorID, vendorName, sub.ModelName)
}

func (h *RSSHandler) resolveVendor(ctx context.Context, param string) (int, string, error) {
	if id, err := strconv.Atoi(param); err == nil {
		name, err := h.catalog.GetVendorName(ctx, id)
		if err != nil {
			return 0, "", err
		}
		return id, name, nil
	}
	id, err := h.catalog.GetVendorIDByName(ctx, param)
	if err != nil {
		return 0, "", err
	}
	name, _ := h.catalog.GetVendorName(ctx, id)
	if name == "" {
		name = strings.ToUpper(param)
	}
	return id, name, nil
}

func (h *RSSHandler) writeRSSFeed(ctx context.Context, w http.ResponseWriter, vendorID int, vendorName, modelName string) {
	posts, err := h.post.GetLatest(ctx, vendorID, modelName, 40)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get posts")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	items := make([]rssItem, 0, len(posts))
	for _, p := range posts {
		items = append(items, rssItem{
			Title:       p.Title,
			Link:        p.Link,
			Description: rssCDATA{Value: p.Description},
			PubDate:     p.PubDate.Format(time.RFC1123Z),
			GUID: rssGUID{
				IsPermaLink: false,
				Value:       p.Hash,
			},
		})
	}

	var lastBuild string
	if len(posts) > 0 {
		lastBuild = posts[0].PubDate.Format(time.RFC1123Z)
	} else {
		lastBuild = time.Now().UTC().Format(time.RFC1123Z)
	}

	title := fmt.Sprintf("%s %s — aucjp.co", vendorName, modelName)
	feed := rssRoot{
		Version: "2.0",
		Channel: rssChannel{
			Title:         title,
			Link:          "https://aucjp.co/japan_st",
			Description:   fmt.Sprintf("Auction results for %s %s from aucjp.co", vendorName, modelName),
			LastBuildDate: lastBuild,
			Items:         items,
		},
	}

	w.Header().Set("Content-Type", "application/rss+xml; charset=utf-8")
	w.Write([]byte(xml.Header))
	enc := xml.NewEncoder(w)
	enc.Indent("", "  ")
	if err := enc.Encode(feed); err != nil {
		log.Error().Err(err).Msg("Failed to encode RSS")
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Error().Err(err).Msg("Failed to encode JSON")
	}
}

type rssRoot struct {
	XMLName xml.Name   `xml:"rss"`
	Version string     `xml:"version,attr"`
	Channel rssChannel `xml:"channel"`
}

type rssChannel struct {
	Title         string    `xml:"title"`
	Link          string    `xml:"link"`
	Description   string    `xml:"description"`
	LastBuildDate string    `xml:"lastBuildDate"`
	Items         []rssItem `xml:"item"`
}

type rssItem struct {
	Title       string   `xml:"title"`
	Link        string   `xml:"link"`
	Description rssCDATA `xml:"description"`
	PubDate     string   `xml:"pubDate"`
	GUID        rssGUID  `xml:"guid"`
}

type rssGUID struct {
	IsPermaLink bool   `xml:"isPermaLink,attr"`
	Value       string `xml:",chardata"`
}

type rssCDATA struct {
	Value string `xml:",cdata"`
}
