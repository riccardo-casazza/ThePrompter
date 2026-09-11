class ProductionRegionMapper
  REGIONS = {
    english: {
      name: "English",
      countries: %w[US GB CA AU NZ IE]
    },
    latin_europe: {
      name: "Latin Europe",
      countries: %w[FR IT ES PT],
      # Multi-lingual countries mapped by language
      languages: %w[fr it es pt]
    },
    northern_europe: {
      name: "Northern Europe",
      countries: %w[DE AT CH SE NO DK FI IS NL LU],
      languages: %w[de nl sv no da fi is]
    },
    eastern_europe: {
      name: "Eastern Europe",
      countries: %w[RU PL CZ HU RO UA BG SK HR SI RS BA MK AL BY EE LV LT MD GE AM AZ KZ]
    },
    latin_america: {
      name: "Latin America",
      countries: %w[MX BR AR CO CL PE VE EC UY PY BO CR PA DO CU PR GT HN SV NI HT JM]
    },
    turkey_middle_east: {
      name: "Turkey & Middle East",
      countries: %w[TR SA AE EG IR IQ IL JO LB SY KW QA BH OM YE PS MA DZ TN LY]
    },
    south_asia: {
      name: "South Asia",
      countries: %w[IN PK BD LK NP BT MM]
    },
    china: {
      name: "China",
      countries: %w[CN HK TW MO]
    },
    korea_japan: {
      name: "Korea & Japan",
      countries: %w[KR JP]
    }
  }.freeze

  # Multi-lingual countries that need language-based resolution
  MULTI_LINGUAL_COUNTRIES = {
    "BE" => { "fr" => :latin_europe, "nl" => :northern_europe, default: :northern_europe },
    "CH" => { "fr" => :latin_europe, "it" => :latin_europe, "de" => :northern_europe, default: :northern_europe },
    "CA" => { "fr" => :latin_europe, default: :english },
    "LU" => { "fr" => :latin_europe, "de" => :northern_europe, default: :northern_europe }
  }.freeze

  class << self
    def region_for(production_countries:, original_language:)
      return nil if production_countries.blank?

      # Parse countries (stored as comma-separated string)
      countries = production_countries.split(",").map(&:strip).map(&:upcase)
      primary_country = countries.first
      language = original_language&.downcase

      # Check multi-lingual countries first
      if MULTI_LINGUAL_COUNTRIES.key?(primary_country)
        mapping = MULTI_LINGUAL_COUNTRIES[primary_country]
        region_key = mapping[language] || mapping[:default]
        return REGIONS[region_key][:name]
      end

      # Find region by country
      REGIONS.each do |_key, config|
        if config[:countries].include?(primary_country)
          return config[:name]
        end
      end

      # Fallback: "Other"
      "Other"
    end

    def all_regions
      REGIONS.values.map { |r| r[:name] } + ["Other"]
    end

    def region_names
      REGIONS.transform_values { |v| v[:name] }
    end
  end
end
