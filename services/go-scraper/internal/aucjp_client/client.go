package aucjp_client

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
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
	Slug         string // a
	LotNumber    string // c
	AuctionName  string // d
	AuctionDate  string // e
	Year         string // g
	EngineCC     string // h
	PriceList    string // i — comma-separated bid history
	ChassisCode  string // j
	Transmission string // k
	Grade        string // l
	FinalPrice   string // o — final price yen, "0" if not sold
	Rating       string // r
	Status       string // v
	Colour       string // w
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
	return decodeBody(body, resp.Header.Get("Content-Type")), nil
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

	return parseJSONPResponse(decodeBody(body, resp.Header.Get("Content-Type")))
}

// extractTplPoisk extracts the tpl_poisk value from:
// ajx.dataReady('0', '', { 'tpl_poisk': 'VAR_DATA_HERE', 'js_1': '...', ... })
func extractTplPoisk(raw string) (string, error) {
	idx := strings.Index(raw, "'tpl_poisk'")
	if idx < 0 {
		return "", fmt.Errorf("tpl_poisk not found in response")
	}
	rest := raw[idx:]

	// Find the colon after 'tpl_poisk'
	colonIdx := strings.Index(rest, ":")
	if colonIdx < 0 {
		return "", fmt.Errorf("no colon after tpl_poisk")
	}
	rest = rest[colonIdx+1:]

	// Find opening quote
	rest = strings.TrimSpace(rest)
	if len(rest) == 0 || rest[0] != '\'' {
		return "", fmt.Errorf("expected opening quote for tpl_poisk value")
	}
	rest = rest[1:]

	// Find matching closing quote (handle escaped quotes)
	var b strings.Builder
	i := 0
	for i < len(rest) {
		if rest[i] == '\\' && i+1 < len(rest) {
			next := rest[i+1]
			switch next {
			case '\'':
				b.WriteByte('\'')
			case '"':
				b.WriteByte('"')
			case '\\':
				b.WriteByte('\\')
			default:
				b.WriteByte('\\')
				b.WriteByte(next)
			}
			i += 2
			continue
		}
		if rest[i] == '\'' {
			return b.String(), nil
		}
		b.WriteByte(rest[i])
		i++
	}

	return "", fmt.Errorf("unterminated tpl_poisk value")
}

func parseJSONPResponse(raw string) (*LotsResponse, error) {
	jsContent, err := extractTplPoisk(raw)
	if err != nil {
		return nil, err
	}
	return parseDataVar(jsContent)
}

func parseDataVar(js string) (*LotsResponse, error) {
	result := &LotsResponse{}

	// Extract navi:{...}
	naviStart := strings.Index(js, "navi:{")
	if naviStart >= 0 {
		naviContent := js[naviStart+len("navi:{"):]
		depth := 1
		end := 0
		for i := 0; i < len(naviContent); i++ {
			if naviContent[i] == '{' {
				depth++
			} else if naviContent[i] == '}' {
				depth--
				if depth == 0 {
					end = i
					break
				}
			}
		}
		if end > 0 {
			result.Pagination = parseNavi(naviContent[:end])
		}
	}

	// Extract body:[...]
	bodyStart := strings.Index(js, "body:[")
	if bodyStart < 0 {
		return result, nil
	}
	bodyContent := js[bodyStart+len("body:["):]
	depth := 1
	end := 0
	for i := 0; i < len(bodyContent); i++ {
		if bodyContent[i] == '[' {
			depth++
		} else if bodyContent[i] == ']' {
			depth--
			if depth == 0 {
				end = i
				break
			}
		}
	}
	if end == 0 {
		return result, nil
	}

	lots := parseLotObjects(bodyContent[:end])
	result.Lots = lots
	return result, nil
}

func parseNavi(s string) Pagination {
	fields := extractFields(s)
	p := Pagination{}
	p.TotalRows, _ = strconv.Atoi(fields["rows"])
	p.Page, _ = strconv.Atoi(fields["page"])
	p.PageSize, _ = strconv.Atoi(fields["limit_step"])
	return p
}

func parseLotObjects(s string) []Lot {
	var lots []Lot

	depth := 0
	start := -1
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case '{':
			if depth == 0 {
				start = i
			}
			depth++
		case '}':
			depth--
			if depth == 0 && start >= 0 {
				obj := s[start+1 : i]
				fields := extractFields(obj)

				// Skip login-gated items (g1 < 0)
				if g1, err := strconv.Atoi(fields["g1"]); err == nil && g1 < 0 {
					start = -1
					continue
				}
				// Skip items with no slug (empty lots / placeholders)
				if fields["a"] == "" {
					start = -1
					continue
				}

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
					Status:       cleanHTML(fields["v"]),
					Colour:       fields["w"],
				}
				lots = append(lots, lot)
				start = -1
			}
		}
	}

	return lots
}

func extractFields(obj string) map[string]string {
	fields := make(map[string]string)
	i := 0
	n := len(obj)

	for i < n {
		// Skip whitespace and commas
		for i < n && (obj[i] == ' ' || obj[i] == ',' || obj[i] == '\n' || obj[i] == '\r' || obj[i] == '\t') {
			i++
		}
		if i >= n {
			break
		}

		// Read key (unquoted identifier or quoted string)
		var key string
		if i < n && (obj[i] == '"' || obj[i] == '\'') {
			quote := obj[i]
			i++
			keyStart := i
			for i < n && obj[i] != quote {
				i++
			}
			key = obj[keyStart:i]
			if i < n {
				i++
			}
		} else {
			keyStart := i
			for i < n && obj[i] != ':' && obj[i] != ' ' {
				i++
			}
			key = strings.TrimSpace(obj[keyStart:i])
		}

		if key == "" {
			i++
			continue
		}

		// Skip to colon
		for i < n && obj[i] != ':' {
			i++
		}
		if i >= n {
			break
		}
		i++ // skip ':'

		// Skip whitespace
		for i < n && obj[i] == ' ' {
			i++
		}
		if i >= n {
			break
		}

		// Read value
		if obj[i] == '"' || obj[i] == '\'' {
			quote := obj[i]
			i++
			var val strings.Builder
			for i < n && obj[i] != quote {
				if obj[i] == '\\' && i+1 < n {
					next := obj[i+1]
					switch next {
					case '"', '\'', '\\':
						val.WriteByte(next)
					default:
						val.WriteByte('\\')
						val.WriteByte(next)
					}
					i += 2
					continue
				}
				val.WriteByte(obj[i])
				i++
			}
			if i < n {
				i++ // skip closing quote
			}
			fields[key] = val.String()
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

func cleanHTML(s string) string {
	s = strings.ReplaceAll(s, "<b>", "")
	s = strings.ReplaceAll(s, "</b>", "")
	return strings.TrimSpace(s)
}

func decodeBody(body []byte, contentType string) string {
	if strings.Contains(strings.ToLower(contentType), "windows-1251") {
		decoded, err := charmap.Windows1251.NewDecoder().Bytes(body)
		if err == nil {
			return string(decoded)
		}
	}
	return string(body)
}
