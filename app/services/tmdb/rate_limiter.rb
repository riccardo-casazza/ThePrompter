module Tmdb
  class RateLimiter
    MAX_REQUESTS_PER_SECOND = 40
    WINDOW_SIZE = 1.0 # seconds

    # Use a class-level mutex and timestamps for cross-instance coordination
    @mutex = Mutex.new
    @request_timestamps = []

    class << self
      attr_reader :mutex, :request_timestamps

      def throttle
        mutex.synchronize do
          now = Time.now.to_f
          cutoff = now - WINDOW_SIZE

          # Remove timestamps older than the window
          request_timestamps.reject! { |ts| ts < cutoff }

          # If at limit, sleep until oldest request exits the window
          if request_timestamps.size >= MAX_REQUESTS_PER_SECOND
            sleep_time = request_timestamps.first - cutoff
            if sleep_time > 0
              mutex.unlock
              sleep(sleep_time)
              mutex.lock
              # Clean up again after sleeping
              now = Time.now.to_f
              cutoff = now - WINDOW_SIZE
              request_timestamps.reject! { |ts| ts < cutoff }
            end
          end

          # Record this request
          request_timestamps << Time.now.to_f
        end
      end

      def reset!
        mutex.synchronize do
          request_timestamps.clear
        end
      end

      def current_rate
        mutex.synchronize do
          now = Time.now.to_f
          cutoff = now - WINDOW_SIZE
          request_timestamps.count { |ts| ts >= cutoff }
        end
      end
    end
  end
end
