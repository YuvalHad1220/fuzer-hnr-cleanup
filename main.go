package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
)

// TelegramLogService is a simple struct to encapsulate Telegram log service details
type TelegramLogService struct {
	ServiceURL string
	BotName    string
}

// HnRCleaner with a reference to the Telegram log service
type HnRCleaner struct {
	BaseURL     string
	ProxyHost   string
	TelegramLog *TelegramLogService
}

type ProxyResponse struct {
	Error     string `json:"error"`
	ErrorCode int    `json:"error_code"`
	Content   string `json:"content"`
}

// NewHnRCleaner initializes HnRCleaner with the Telegram log service
func NewHnRCleaner(baseURL, proxyHost, telegramServiceURL, botName string) *HnRCleaner {
	return &HnRCleaner{
		BaseURL:   baseURL,
		ProxyHost: proxyHost,
		TelegramLog: &TelegramLogService{
			ServiceURL: telegramServiceURL,
			BotName:    botName,
		},
	}
}

// logToTelegram sends a message to the Telegram log service
func (c *HnRCleaner) logToTelegram(content string) {
	payload := map[string]string{
		"botName": c.TelegramLog.BotName,
		"content": content,
	}
	jsonData, err := json.Marshal(payload)
	if err != nil {
		log.Printf("Failed to marshal log payload: %v", err)
		return
	}

	resp, err := http.Post(c.TelegramLog.ServiceURL, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("Failed to send log to Telegram: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("Non-OK response from Telegram log service: %d", resp.StatusCode)
	}
}
func (c *HnRCleaner) fetchPageContent(targetURL string) (*goquery.Document, error) {
	encodedURL := url.QueryEscape(targetURL)
	proxyURL := fmt.Sprintf("%s/?url=%s", c.ProxyHost, encodedURL)

	resp, err := http.Get(proxyURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var response ProxyResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, err
	}

	if response.ErrorCode != 200 {
		return nil, fmt.Errorf("error fetching content: %s", response.Error)
	}

	return goquery.NewDocumentFromReader(strings.NewReader(response.Content))
}

func (c *HnRCleaner) extractHnRTitles(doc *goquery.Document) []string {
	var hrefs []string
	doc.Find("table .thead:contains('היסטוריית העלאה/הורדה')").Parent().Parent().Find("tr").Each(func(i int, tr *goquery.Selection) {
		if tr.Find("td:nth-child(9)").Text() == "Yes" {
			if threadLink := tr.Find(".threadlink"); threadLink.Length() > 0 {
				if href, exists := threadLink.Attr("href"); exists {
					hrefs = append(hrefs, c.BaseURL+"/"+href)
				}
			}
		}
	})
	return hrefs
}

func (c *HnRCleaner) extractDeleteLink(doc *goquery.Document) (string, error) {
	deleteLink := doc.Find("a").FilterFunction(func(i int, s *goquery.Selection) bool {
		return strings.TrimSpace(s.Text()) == "מחק"
	})

	href, exists := deleteLink.Attr("href")
	if !exists {
		return "", fmt.Errorf("no 'מחק' link found")
	}

	return c.BaseURL + "/" + href, nil
}

func (c *HnRCleaner) extractFormDetails(doc *goquery.Document) (map[string]string, error) {
	formDetails := make(map[string]string)
	doc.Find("form[name='delhnr'] input[type='hidden']").Each(func(i int, input *goquery.Selection) {
		name, _ := input.Attr("name")
		value, _ := input.Attr("value")
		formDetails[name] = value
	})

	if len(formDetails) == 0 {
		return nil, fmt.Errorf("no form details found")
	}

	return formDetails, nil
}

func (c *HnRCleaner) sendDeleteRequest(formData map[string]string) error {
	jsonData, err := json.Marshal(formData)
	if err != nil {
		return fmt.Errorf("error encoding form data: %v", err)
	}

	postURL := c.BaseURL + "/snatchlist.php?do=dodelhnr"
	encodedURL := url.QueryEscape(postURL)
	proxyURL := fmt.Sprintf("%s/?url=%s", c.ProxyHost, encodedURL)

	req, err := http.NewRequest(http.MethodPost, proxyURL, strings.NewReader(string(jsonData)))
	if err != nil {
		return fmt.Errorf("error creating POST request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("error sending POST request: %v", err)
	}
	defer resp.Body.Close()

	var response ProxyResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return fmt.Errorf("error decoding response: %v", err)
	}

	if response.ErrorCode != 200 {
		return fmt.Errorf("error in POST request: %s", response.Error)
	}

	return nil
}

// cleanHnRTorrents updated with Telegram logging
func (c *HnRCleaner) cleanHnRTorrents() error {
	snatchlistURL := c.BaseURL + "/snatchlist.php?u=14815&type=hnr&order=hnr&sort=desc"

	doc, err := c.fetchPageContent(snatchlistURL)
	if err != nil {
		c.logToTelegram(fmt.Sprintf("Error fetching snatchlist: %v", err))
		return err
	}

	titles := c.extractHnRTitles(doc)
	if len(titles) == 0 {
		c.logToTelegram("No HnR torrents found.")
		log.Println("No HnR torrents found.")

		return nil
	}

	deletedCount := 0

	for _, title := range titles {
		pageDoc, err := c.fetchPageContent(title)
		if err != nil {
			logMsg := fmt.Sprintf("Error fetching page %s: %v", title, err)
			c.logToTelegram(logMsg)
			log.Println(logMsg)
			continue
		}

		deleteLink, err := c.extractDeleteLink(pageDoc)
		if err != nil {
			logMsg := fmt.Sprintf("Error extracting delete link from %s: %v", title, err)
			c.logToTelegram(logMsg)
			log.Println(logMsg)
			continue
		}

		deletePageDoc, err := c.fetchPageContent(deleteLink)
		if err != nil {
			logMsg := fmt.Sprintf("Error fetching delete page %s: %v", deleteLink, err)
			c.logToTelegram(logMsg)
			log.Println(logMsg)
			continue
		}

		formDetails, err := c.extractFormDetails(deletePageDoc)
		if err != nil {
			logMsg := fmt.Sprintf("Error extracting form details from %s: %v", deleteLink, err)
			c.logToTelegram(logMsg)
			log.Println(logMsg)
			continue
		}

		if err := c.sendDeleteRequest(formDetails); err != nil {
			logMsg := fmt.Sprintf("Error sending delete request for %s: %v", deleteLink, err)
			c.logToTelegram(logMsg)
			log.Println(logMsg)
		} else {
			deletedCount++
		}
	}

	summaryMsg := fmt.Sprintf("HnR cleanup completed. Deleted %d warnings.", deletedCount)
	c.logToTelegram(summaryMsg)
	log.Println(summaryMsg)

	return nil
}

// runScheduledCleaner with Telegram logging
func runScheduledCleaner() {
	cleaner := NewHnRCleaner(
		"https://www.fuzer.xyz",
		"http://fuzer-service:8080",
		"http://telegram-log-service:8080/send",
		"fuzer_main_bot",
	)

	for {
		log.Println("Starting HnR torrent cleanup...")
		cleaner.logToTelegram("Starting HnR torrent cleanup...")
		if err := cleaner.cleanHnRTorrents(); err != nil {
			cleaner.logToTelegram(fmt.Sprintf("Cleanup failed: %v", err))
			log.Printf("Cleanup failed: %v\n", err)
		}
		log.Println("HnR torrent cleanup completed. Waiting 8 hours...")
		cleaner.logToTelegram("HnR torrent cleanup completed. Waiting 8 hours...")

		time.Sleep(8 * time.Hour)
	}
}

func main() {
	runScheduledCleaner()
}
