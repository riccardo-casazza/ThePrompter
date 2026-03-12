require "ferrum"

module Imdb
  class ListScraper
    USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze
    SCROLL_COUNT = 100
    SCROLL_DELAY = 0.1

    PERSON_ID_PATTERN = /^nm\d{2,}$/
    TITLE_ID_PATTERN = /^tt\d{2,}$/

    def initialize(headless: true)
      @headless = headless
    end

    # Scrape persons from an IMDb list
    # Returns array of { name:, nconst:, category: }
    def scrape_persons_list(url, category)
      browser = create_browser
      persons = []

      begin
        browser.goto(url)
        scroll_page(browser)

        browser.css(".ipc-lockup-overlay").each do |element|
          name = element.attribute("aria-label")
          href = element.attribute("href")

          next unless href

          nconst = extract_id_from_href(href, PERSON_ID_PATTERN)
          next unless nconst

          persons << {
            name: sanitize_text(name),
            nconst: nconst,
            category: category
          }
        end
      ensure
        browser.quit
      end

      persons.uniq { |p| p[:nconst] }
    end

    # Scrape titles from an IMDb list (e.g., blacklist)
    # Returns array of tconst strings
    def scrape_titles_list(url)
      browser = create_browser
      tconsts = []

      begin
        browser.goto(url)
        scroll_page(browser)

        browser.css(".ipc-title-link-wrapper").each do |element|
          href = element.attribute("href")
          next unless href

          tconst = extract_id_from_href(href, TITLE_ID_PATTERN)
          tconsts << tconst if tconst
        end
      ensure
        browser.quit
      end

      tconsts.uniq
    end

    private

    def create_browser
      options = {
        headless: @headless,
        timeout: 30,
        browser_options: {
          "no-sandbox": true,
          "disable-dev-shm-usage": true,
          "user-agent": USER_AGENT
        }
      }

      # Use custom browser path if set (for Docker)
      options[:browser_path] = ENV["BROWSER_PATH"] if ENV["BROWSER_PATH"]

      Ferrum::Browser.new(**options)
    end

    def scroll_page(browser)
      SCROLL_COUNT.times do
        browser.execute("window.scrollBy(0, window.innerHeight)")
        sleep(SCROLL_DELAY)
      end
      # Wait for content to settle
      sleep(1)
    end

    def extract_id_from_href(href, pattern)
      parts = href.split("/")
      id = parts[4] || parts[2] # Handle different URL formats
      return id if id && pattern.match?(id)

      nil
    end

    def sanitize_text(text)
      return nil unless text

      text.strip
    end
  end
end
