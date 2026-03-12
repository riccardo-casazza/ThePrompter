require "ferrum"
require "csv"

module Imdb
  class RatingsExporter
    USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze
    DOWNLOAD_DIR = Rails.root.join("tmp", "imdb_exports").to_s
    MAX_DOWNLOAD_WAIT_ATTEMPTS = 20
    DOWNLOAD_CHECK_INTERVAL = 20 # seconds

    def initialize(user_id:, cookies: {}, headless: true)
      @user_id = user_id
      @cookies = cookies
      @headless = headless
    end

    # Export ratings and return array of { tconst:, rating: }
    def export
      FileUtils.mkdir_p(DOWNLOAD_DIR)

      browser = create_browser

      begin
        # Navigate to ratings page
        ratings_url = "https://www.imdb.com/user/#{@user_id}/ratings/"
        browser.goto(ratings_url)

        # Setup downloads after page is created
        setup_downloads(browser)

        # Add authentication cookies
        add_cookies(browser)

        # Reload with cookies
        browser.goto(ratings_url)
        sleep(3)

        # Dismiss cookie banner if present
        dismiss_cookie_banner(browser)

        # Find and click export button
        click_export_button(browser)

        # Navigate to exports page and download
        download_export(browser)

        # Parse the downloaded CSV
        parse_ratings_csv
      ensure
        browser.quit
      end
    end

    private

    def create_browser
      options = {
        headless: @headless,
        timeout: 60,
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

    def setup_downloads(browser)
      # Set download behavior using the Downloads API (Ferrum 0.15+)
      # Must be called after page is created (after first goto)
      browser.downloads.set_behavior(save_path: DOWNLOAD_DIR, behavior: :allow)
      Rails.logger.info "Download behavior set to save to: #{DOWNLOAD_DIR}"
    end

    def add_cookies(browser)
      @cookies.each do |name, value|
        browser.cookies.set(
          name: name.to_s,
          value: value,
          domain: ".imdb.com"
        )
      end
    end

    def dismiss_cookie_banner(browser)
      begin
        accept_button = browser.at_xpath("//button[@data-testid='accept-button']")
        accept_button&.click
        sleep(1)
      rescue Ferrum::Error
        # Banner not present, continue
      end

      # Remove overlay elements via JS
      browser.execute(<<~JS)
        document.querySelectorAll('[class*="consent"], [class*="cookie"]').forEach(el => el.remove());
      JS
    end

    def click_export_button(browser)
      buttons = browser.css(".ipc-responsive-button")
      export_button = buttons.find { |b| b.attribute("aria-label") == "Export" }

      if export_button
        Rails.logger.info "Found Export button, clicking..."
        browser.execute("arguments[0].click()", export_button)
        sleep(2)
      else
        raise "Export button not found on ratings page"
      end
    end

    def download_export(browser)
      browser.goto("https://www.imdb.com/exports/?ref_=rt")
      sleep(5)
      dismiss_cookie_banner(browser)

      MAX_DOWNLOAD_WAIT_ATTEMPTS.times do |attempt|
        begin
          items = browser.css(".ipc-metadata-list-summary-item")
          raise "No export items found" if items.empty?

          download_item = items.first
          download_button = download_item.at_css("[data-testid='export-status-button']")

          # Check various disabled states - IMDB uses different patterns
          is_disabled = download_button&.attribute("disabled") ||
                        download_button&.attribute("aria-disabled") == "true" ||
                        download_button&.text&.include?("progress")

          if is_disabled
            button_text = download_button&.text&.strip || "unknown"
            Rails.logger.info "Export not ready (status: #{button_text}), waiting... (attempt #{attempt + 1}/#{MAX_DOWNLOAD_WAIT_ATTEMPTS})"
            sleep(DOWNLOAD_CHECK_INTERVAL)
            browser.refresh
            sleep(3)
            dismiss_cookie_banner(browser)
          else
            Rails.logger.info "Download button ready, clicking..."
            dismiss_cookie_banner(browser)

            # Log button details for debugging
            button_html = browser.evaluate("arguments[0].outerHTML", download_button)
            Rails.logger.info "Download button HTML: #{button_html}"

            # Check if it's a link with href
            href = download_button.attribute("href")
            if href
              Rails.logger.info "Button has href: #{href}"
            end

            browser.execute("arguments[0].click()", download_button)
            Rails.logger.info "Download button clicked, waiting for file..."
            wait_for_download(browser)
            return
          end
        rescue Ferrum::Error => e
          Rails.logger.warn "Error on download attempt #{attempt + 1}: #{e.message}"
          sleep(5)
        end
      end

      raise "Failed to download export after #{MAX_DOWNLOAD_WAIT_ATTEMPTS} attempts"
    end

    def wait_for_download(browser)
      max_attempts = 30
      max_attempts.times do |attempt|
        # Check for CSV files (not .crdownload partial files)
        csv_files = Dir.glob(File.join(DOWNLOAD_DIR, "*.csv"))
        partial_files = Dir.glob(File.join(DOWNLOAD_DIR, "*.crdownload"))

        # Also check Ferrum's downloads API
        begin
          download_files = browser.downloads.files
          Rails.logger.info "Ferrum downloads: #{download_files.inspect}" if download_files.any?
        rescue StandardError => e
          Rails.logger.debug "Could not check Ferrum downloads: #{e.message}"
        end

        if csv_files.any?
          Rails.logger.info "Download complete: #{csv_files.first}"
          return
        elsif partial_files.any?
          Rails.logger.info "Download in progress... (attempt #{attempt + 1}/#{max_attempts})"
        else
          Rails.logger.info "Waiting for download to start... (attempt #{attempt + 1}/#{max_attempts})"
        end

        sleep(2)
      end

      # Log directory contents for debugging
      all_files = Dir.glob(File.join(DOWNLOAD_DIR, "*"))
      Rails.logger.error "Download failed. Files in #{DOWNLOAD_DIR}: #{all_files.inspect}"
      raise "Download did not complete after #{max_attempts * 2} seconds"
    end

    def parse_ratings_csv
      # Find the most recent CSV file
      csv_files = Dir.glob(File.join(DOWNLOAD_DIR, "*.csv"))
      raise "No CSV files found in #{DOWNLOAD_DIR}" if csv_files.empty?

      latest_csv = csv_files.max_by { |f| File.mtime(f) }
      Rails.logger.info "Parsing ratings from #{latest_csv}"

      ratings = []

      CSV.foreach(latest_csv, headers: true) do |row|
        tconst = row["Const"] || row["tconst"]
        rating = row["Your Rating"] || row["rating"]

        next unless tconst && rating

        ratings << {
          tconst: tconst,
          rating: rating.to_i
        }
      end

      # Cleanup downloaded file
      File.delete(latest_csv)

      ratings
    end
  end
end
