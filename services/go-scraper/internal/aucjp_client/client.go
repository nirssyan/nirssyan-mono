package aucjp_client

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"golang.org/x/text/encoding/charmap"
)

const (
	BaseURL       = "https://aucjp.co"
	searchPageURL = BaseURL + "/japan_st"
	loaderURL     = BaseURL + "/st"
)

type Client struct {
	httpClient *http.Client
}

func New() *Client {
	return &Client{
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
}

type Lot struct {
	Slug        string // a — lot link slug
	LotNumber   string // c — lot number
	AuctionName string // d — auction name
	AuctionDate string // e — auction date DD.MM.YYYY
	Year        string // g — year
	EngineCC    string // h — engine displacement
	PriceList   string // i — comma-separated bid history
	ChassisCode string // j — chassis code
	Transmission string // k — transmission
	Grade       string // l — grade/trim
	FinalPrice  string // o — final price yen
	Rating      string // r — auction rating
	Status      string // v — status text (decoded from windows-1251)
	Colour      string // w — colour (decoded from windows-1251)
}

func (l *Lot) Link() string {
	if l.Slug == "" {
		return BaseURL
	}
	return fmt.Sprintf("%s/st-%s.htm", BaseURL, l.Slug)
}

func (l *Lot) LastPrice() string {
	if l.FinalPrice != "" && l.FinalPrice != "0" {
		return l.FinalPrice
	}
	if l.PriceList == "" {
		return "0"
	}
	parts := strings.Split(l.PriceList, ",")
	return strings.TrimSpace(parts[len(parts)-1])
}

type Pagination struct {
	TotalRows int
	Page      int
	PageSize  int
}

type LotsResponse struct {
	Lots       []Lot
	Pagination Pagination
}

func (c *Client) FetchPage(ctx context.Context, pageURL string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, pageURL, nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; GoScraper/1.0)")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("fetch page: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read body: %w", err)
	}
	return string(body), nil
}

func (c *Client) FetchLots(ctx context.Context, vendorID int, model string, page, pageSize int) (*LotsResponse, error) {
	form := url.Values{
		"vendor":    {strconv.Itoa(vendorID)},
		"model":     {model},
		"is_stat":   {"0"},
		"page":      {strconv.Itoa(page)},
		"list_size": {strconv.Itoa(pageSize)},
	}

	reqURL := loaderURL + "?file=loader&Q=" + url.QueryEscape(model)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, reqURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; GoScraper/1.0)")
	req.Header.Set("Referer", searchPageURL)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch lots: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	return parseJSONPResponse(string(body))
}

var dataReadyRe = regexp.MustCompile(`ajx\.dataReady\('[^']*',\s*'[^']*',\s*\{\s*'tpl_poisk'\s*:\s*'((?:[^'\\]|\\.)*)'\s*\}`)

func parseJSONPResponse(raw string) (*LotsResponse, error) {
	m := dataReadyRe.FindStringSubmatch(raw)
	if m == nil {
		if strings.Contains(raw, "tpl_poisk") {
			return nil, fmt.Errorf("matched tpl_poisk but failed regex extraction")
		}
		return nil, fmt.Errorf("no ajx.dataReady response found")
	}

	jsContent := m[1]
	jsContent = strings.ReplaceAll(jsContent, "\\'", "'")
	jsContent = strings.ReplaceAll(jsContent, "\\\\", "\\")

	return parseDataVar(jsContent)
}

var (
	naviRe = regexp.MustCompile(`navi:\{([^}]+)\}`)
	bodyRe = regexp.MustCompile(`body:\[(.+)\]`)
)

func parseDataVar(js string) (*LotsResponse, error) {
	result := &LotsResponse{}

	if m := naviRe.FindStringSubmatch(js); m != nil {
		result.Pagination = parseNavi(m[1])
	}

	m := bodyRe.FindStringSubmatch(js)
	if m == nil {
		return result, nil
	}

	lotsStr := m[1]
	lots, err := parseLotObjects(lotsStr)
	if err != nil {
		return nil, fmt.Errorf("parse lot objects: %w", err)
	}
	result.Lots = lots

	return result, nil
}

func parseNavi(s string) Pagination {
	p := Pagination{}
	for _, part := range strings.Split(s, ",") {
		part = strings.TrimSpace(part)
		kv := strings.SplitN(part, ":", 2)
		if len(kv) != 2 {
			continue
		}
		key := strings.Trim(kv[0], `"' `)
		val := strings.Trim(kv[1], `"' `)
		switch key {
		case "rows":
			p.TotalRows, _ = strconv.Atoi(val)
		case "page":
			p.Page, _ = strconv.Atoi(val)
		case "limit_step":
			p.PageSize, _ = strconv.Atoi(val)
		}
	}
	return p
}

func parseLotObjects(s string) ([]Lot, error) {
	var lots []Lot

	depth := 0
	start := -1
	for i, ch := range s {
		switch ch {
		case '{':
			if depth == 0 {
				start = i
			}
			depth++
		case '}':
			depth--
			if depth == 0 && start >= 0 {
				obj := s[start+1 : i]
				lot := parseSingleLot(obj)
				lots = append(lots, lot)
				start = -1
			}
		}
	}

	return lots, nil
}

func parseSingleLot(obj string) Lot {
	fields := extractFields(obj)
	lot := Lot{
		Slug:         fields["a"],
		LotNumber:    fields["c"],
		AuctionName:  fields["d"],
		AuctionDate:  fields["e"],
		Year:         fields["g"],
		EngineCC:     fields["h"],
		PriceList:    fields["i"],
		ChassisCode:  fields["j"],
		Transmission: fields["k"],
		Grade:        fields["l"],
		FinalPrice:   fields["o"],
		Rating:       fields["r"],
		Status:       decodeWin1251(fields["v"]),
		Colour:       decodeWin1251(fields["w"]),
	}
	return lot
}

func extractFields(obj string) map[string]string {
	fields := make(map[string]string)
	i := 0
	n := len(obj)

	for i < n {
		for i < n && (obj[i] == ' ' || obj[i] == ',' || obj[i] == '\n' || obj[i] == '\r' || obj[i] == '\t') {
			i++
		}
		if i >= n {
			break
		}

		keyStart := i
		for i < n && obj[i] != ':' && obj[i] != '"' && obj[i] != '\'' {
			i++
		}
		key := strings.TrimSpace(obj[keyStart:i])
		if key == "" {
			i++
			continue
		}

		for i < n && obj[i] != ':' {
			i++
		}
		if i >= n {
			break
		}
		i++ // skip ':'

		for i < n && obj[i] == ' ' {
			i++
		}
		if i >= n {
			break
		}

		if obj[i] == '"' || obj[i] == '\'' {
			quote := obj[i]
			i++
			valStart := i
			for i < n && obj[i] != quote {
				if obj[i] == '\\' {
					i++
				}
				i++
			}
			val := obj[valStart:i]
			if i < n {
				i++ // skip closing quote
			}
			fields[key] = val
		} else {
			valStart := i
			for i < n && obj[i] != ',' && obj[i] != '}' {
				i++
			}
			fields[key] = strings.TrimSpace(obj[valStart:i])
		}
	}

	return fields
}

func decodeWin1251(s string) string {
	if s == "" {
		return s
	}
	decoded, err := charmap.Windows1251.NewDecoder().String(s)
	if err != nil {
		return s
	}
	return decoded
}
