class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  IMPORT_PREFIX = "import_in_progress_".freeze

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
  end
end
