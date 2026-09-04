class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  IMPORT_PREFIX = "import_in_progress_".freeze
  JOB_LAST_RUN_PREFIX = "job_last_run_".freeze
  JOB_LAST_STATUS_PREFIX = "job_last_status_".freeze

  class << self
    def get(key)
      find_by(key: key)&.value
    end

    def set(key, value)
      setting = find_or_initialize_by(key: key)
      setting.update!(value: value.to_s)
      value
    end

    def any_import_in_progress?
      where("key LIKE ?", "#{IMPORT_PREFIX}%").where(value: "true").exists?
    end

    def imports_in_progress
      where("key LIKE ?", "#{IMPORT_PREFIX}%")
        .where(value: "true")
        .pluck(:key)
        .map { |k| k.delete_prefix(IMPORT_PREFIX) }
    end

    def import_in_progress?(table_name)
      get("#{IMPORT_PREFIX}#{table_name}") == "true"
    end

    def import_started!(table_name)
      set("#{IMPORT_PREFIX}#{table_name}", true)
    end

    def import_finished!(table_name)
      set("#{IMPORT_PREFIX}#{table_name}", false)
    end

    # Job tracking methods
    def job_started!(job_name)
      set("#{JOB_LAST_RUN_PREFIX}#{job_name}", Time.current.iso8601)
      set("#{JOB_LAST_STATUS_PREFIX}#{job_name}", "running")
    end

    def job_completed!(job_name)
      set("#{JOB_LAST_STATUS_PREFIX}#{job_name}", "success")
    end

    def job_failed!(job_name, error_message = nil)
      set("#{JOB_LAST_STATUS_PREFIX}#{job_name}", "failed")
      set("#{JOB_LAST_STATUS_PREFIX}#{job_name}_error", error_message) if error_message
    end

    def job_last_run(job_name)
      time_str = get("#{JOB_LAST_RUN_PREFIX}#{job_name}")
      Time.parse(time_str) if time_str
    rescue ArgumentError
      nil
    end

    def job_last_status(job_name)
      get("#{JOB_LAST_STATUS_PREFIX}#{job_name}")
    end

    def all_job_statuses
      # Get all jobs with last run times
      where("key LIKE ?", "#{JOB_LAST_RUN_PREFIX}%")
        .pluck(:key, :value)
        .map do |key, time_str|
          job_name = key.delete_prefix(JOB_LAST_RUN_PREFIX)
          {
            name: job_name,
            last_run: (Time.parse(time_str) rescue nil),
            status: job_last_status(job_name)
          }
        end
        .sort_by { |job| job[:last_run] || Time.at(0) }
        .reverse
    end
  end
end
