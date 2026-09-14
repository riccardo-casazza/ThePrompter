class TitlesController < ApplicationController
  MAX_YEAR_RANGE = 10

  def index
    @title_types = available_title_types
    @title_type = params[:title_type].presence
    @sort_by = params[:sort_by].presence || "original_title"
    @sort_direction = params[:sort_direction].presence || "asc"

    parse_common_filters
    parse_show_filters(default_show_already_watched: "no", default_show_wip: "no", default_show_documentaries: "no")

    @titles = []
    @error = nil

    if filters_valid?
      @titles = fetch_titles
      @preferences_by_tconst = fetch_preferences_for_titles(@titles)
    elsif params[:start_year].present? || params[:title_type].present?
      @error = validation_error_message
    end
  end

  def awards
    @title_type = "movie"
    @sort_by = params[:sort_by].presence || "start_year"
    @sort_direction = params[:sort_direction].presence || "desc"

    parse_common_filters
    parse_show_filters(default_show_already_watched: "yes", default_show_wip: "yes", default_show_documentaries: "yes")

    @titles = []
    @awards_by_tconst = {}
    @error = nil

    if awards_filters_valid?
      @titles = fetch_award_titles
      @preferences_by_tconst = fetch_preferences_for_titles(@titles)
      @awards_by_tconst = fetch_awards_for_titles(@titles)
    elsif params[:start_year].present?
      @error = awards_validation_error_message
    end
  end

  private

  def parse_common_filters
    @start_year = params[:start_year].presence&.to_i
    @end_year = params[:end_year].presence&.to_i
    @min_rating = params[:min_rating].presence&.to_f
    @max_rating = params[:max_rating].presence&.to_f
    @min_votes = params[:min_votes].presence&.to_i
    @language = params[:language].presence&.strip&.downcase
    @require_language_data = params[:require_language_data] == "1"
    @production_regions = Array(params[:production_regions]).reject(&:blank?)
    @available_regions = ProductionRegionMapper.all_regions
  end

  def parse_show_filters(default_show_already_watched:, default_show_wip:, default_show_documentaries:)
    @show_in_french_theaters = params[:show_in_french_theaters].presence || "yes"
    @show_in_italian_theaters = params[:show_in_italian_theaters].presence || "yes"
    @show_at_home = params[:show_at_home].presence || "yes"
    @show_in_plex = params[:show_in_plex].presence || "yes"
    @show_already_watched = params[:show_already_watched].presence || default_show_already_watched
    @show_wip = params[:show_wip].presence || default_show_wip
    @show_with_preferences = params[:show_with_preferences].presence || "yes"
    @show_in_collection = params[:show_in_collection].presence || "yes"
    @show_documentaries = params[:show_documentaries].presence || default_show_documentaries
  end

  def available_title_types
    TitleBasic.distinct.pluck(:title_type).sort
  end

  def filters_valid?
    return false unless @title_type.present?

    if @start_year && @end_year
      return false unless @start_year <= @end_year
      unless @show_in_plex == "only"
        return false if (@end_year - @start_year) > MAX_YEAR_RANGE
      end
    end

    true
  end

  def validation_error_message
    return "Please select a title type" if @title_type.blank?
    if @start_year && @end_year
      return "End year must be greater than or equal to start year" if @end_year < @start_year
      return "Year range cannot exceed #{MAX_YEAR_RANGE} years" if @show_in_plex != "only" && (@end_year - @start_year) > MAX_YEAR_RANGE
    end
    nil
  end

  def awards_filters_valid?
    return true unless @start_year && @end_year
    @start_year <= @end_year
  end

  def awards_validation_error_message
    "End year must be greater than or equal to start year" if @start_year && @end_year && @end_year < @start_year
  end

  def base_title_query
    TitleBasic
      .select(
        "title_basics.tconst",
        "title_basics.original_title",
        "title_basics.start_year",
        "title_ratings.average_rating",
        "title_ratings.num_votes",
        "title_movie_tmdb.theater_air_date_fr",
        "title_movie_tmdb.theater_air_date_it",
        "title_movie_tmdb.home_air_date",
        "title_movie_tmdb.languages",
        "title_movie_tmdb.production_region",
        "CASE WHEN plex_library_items.tconst IS NOT NULL THEN true ELSE false END AS in_plex",
        "plex_library_items.collections AS plex_collections",
        "my_ratings.rating AS my_rating"
      )
      .joins("LEFT JOIN title_ratings ON title_basics.tconst = title_ratings.tconst")
      .joins("LEFT JOIN title_movie_tmdb ON title_basics.tconst = title_movie_tmdb.tconst")
      .joins("LEFT JOIN plex_library_items ON title_basics.tconst = plex_library_items.tconst")
      .joins("LEFT JOIN my_ratings ON title_basics.tconst = my_ratings.tconst")
  end

  def apply_common_filters(titles)
    titles = titles.where(start_year: @start_year..@end_year) if @start_year && @end_year
    titles = titles.where("title_ratings.average_rating >= ?", @min_rating) if @min_rating
    titles = titles.where("title_ratings.average_rating < ?", @max_rating) if @max_rating
    titles = titles.where("title_ratings.num_votes >= ?", @min_votes) if @min_votes
    titles = titles.where.not(tconst: BlacklistedTitle.select(:tconst))

    titles = apply_in_french_theaters_filter(titles)
    titles = apply_in_italian_theaters_filter(titles)
    titles = apply_at_home_filter(titles)
    titles = apply_in_plex_filter(titles)
    titles = apply_already_watched_filter(titles)
    titles = apply_wip_filter(titles)
    titles = apply_with_preferences_filter(titles)
    titles = apply_in_collection_filter(titles)
    titles = apply_documentaries_filter(titles)
    titles = apply_language_filter(titles)
    titles = apply_production_region_filter(titles)

    titles.distinct
  end

  def fetch_titles
    titles = base_title_query.where(title_type: @title_type)
    titles = apply_common_filters(titles)
    apply_sorting(titles).limit(500)
  end

  def fetch_award_titles
    titles = base_title_query
      .joins("INNER JOIN title_awards ON title_basics.tconst = title_awards.tconst")
      .where(title_type: "movie")
    titles = apply_common_filters(titles)
    apply_sorting(titles).limit(500)
  end

  def apply_sorting(scope)
    allowed_sort_columns = %w[original_title start_year average_rating theater_air_date_fr theater_air_date_it home_air_date in_plex]
    allowed_directions = %w[asc desc]

    column = allowed_sort_columns.include?(@sort_by) ? @sort_by : "original_title"
    direction = allowed_directions.include?(@sort_direction) ? @sort_direction : "asc"

    scope.order(column => direction)
  end

  def apply_in_french_theaters_filter(scope)
    return scope if @show_in_french_theaters == "yes"
    @show_in_french_theaters == "only" ? scope.where.not("title_movie_tmdb.theater_air_date_fr": nil) : scope.where("title_movie_tmdb.theater_air_date_fr": nil)
  end

  def apply_in_italian_theaters_filter(scope)
    return scope if @show_in_italian_theaters == "yes"
    @show_in_italian_theaters == "only" ? scope.where.not("title_movie_tmdb.theater_air_date_it": nil) : scope.where("title_movie_tmdb.theater_air_date_it": nil)
  end

  def apply_at_home_filter(scope)
    return scope if @show_at_home == "yes"
    @show_at_home == "only" ? scope.where.not("title_movie_tmdb.home_air_date": nil) : scope.where("title_movie_tmdb.home_air_date": nil)
  end

  def apply_in_plex_filter(scope)
    return scope if @show_in_plex == "yes"
    @show_in_plex == "only" ? scope.where.not("plex_library_items.tconst": nil) : scope.where("plex_library_items.tconst": nil)
  end

  def apply_already_watched_filter(scope)
    return scope if @show_already_watched == "yes"
    watched_condition = "EXISTS (SELECT 1 FROM my_ratings WHERE my_ratings.tconst = title_basics.tconst)"
    @show_already_watched == "only" ? scope.where(watched_condition) : scope.where("NOT #{watched_condition}")
  end

  def apply_with_preferences_filter(scope)
    return scope if @show_with_preferences == "yes"
    has_preferences_condition = "EXISTS (SELECT 1 FROM title_principals INNER JOIN my_preferences ON title_principals.nconst = my_preferences.nconst WHERE title_principals.tconst = title_basics.tconst)"
    @show_with_preferences == "only" ? scope.where(has_preferences_condition) : scope.where("NOT #{has_preferences_condition}")
  end

  def apply_wip_filter(scope)
    return scope if @show_wip == "yes"

    released_condition = "(title_ratings.num_votes > 0 AND (" \
      "(title_movie_tmdb.home_air_date <= :today OR title_movie_tmdb.theater_air_date_fr <= :today OR title_movie_tmdb.theater_air_date_it <= :today) OR " \
      "(title_movie_tmdb.home_air_date IS NULL AND title_movie_tmdb.theater_air_date_fr IS NULL AND title_movie_tmdb.theater_air_date_it IS NULL AND title_basics.start_year < :current_year)))"
    filter_params = { today: Date.current, current_year: Date.current.year }

    @show_wip == "only" ? scope.where("NOT (#{released_condition})", filter_params) : scope.where(released_condition, filter_params)
  end

  def apply_in_collection_filter(scope)
    return scope if @show_in_collection == "yes"
    @show_in_collection == "only" ? scope.where("plex_library_items.collections IS NOT NULL AND plex_library_items.collections != ''") : scope.where("plex_library_items.collections IS NULL OR plex_library_items.collections = ''")
  end

  def apply_documentaries_filter(scope)
    return scope if @show_documentaries == "yes"
    @show_documentaries == "only" ? scope.where("title_basics.genres LIKE ?", "%Documentary%") : scope.where("title_basics.genres NOT LIKE ? OR title_basics.genres IS NULL", "%Documentary%")
  end

  def apply_language_filter(scope)
    scope = scope.where("title_movie_tmdb.languages IS NOT NULL AND title_movie_tmdb.languages != ''") if @require_language_data
    return scope unless @language.present?
    scope.where("title_movie_tmdb.languages LIKE ? OR title_movie_tmdb.languages LIKE ? OR title_movie_tmdb.languages LIKE ? OR title_movie_tmdb.languages = ?",
                "#{@language},%", "%, #{@language}", "%, #{@language},%", @language)
  end

  def apply_production_region_filter(scope)
    return scope if @production_regions.empty?
    scope.where("title_movie_tmdb.production_region": @production_regions)
  end

  def fetch_preferences_for_titles(titles)
    return {} if titles.empty?

    tconsts = titles.map(&:tconst)
    matches = TitlePrincipal
      .joins("INNER JOIN my_preferences ON title_principals.nconst = my_preferences.nconst")
      .where(tconst: tconsts)
      .select("DISTINCT title_principals.tconst, title_principals.nconst, my_preferences.primary_name, title_principals.category, title_principals.ordering")
      .order("title_principals.ordering")

    abbreviations = { "director" => "D", "actor" => "A", "actress" => "A", "writer" => "W", "composer" => "C" }

    matches.group_by(&:tconst).transform_values do |people|
      people.group_by(&:nconst).map do |_nconst, person_roles|
        name = person_roles.first.primary_name
        roles = person_roles.map { |p| abbreviations[p.category] || p.category[0].upcase }.uniq.join(", ")
        "#{name} (#{roles})"
      end.join(", ")
    end
  end

  def fetch_awards_for_titles(titles)
    return {} if titles.empty?

    award_labels = {
      oscar_best_picture: "Oscar",
      golden_globe_drama: "GG Drama",
      golden_globe_musical_comedy: "GG Comedy",
      golden_globe_foreign: "GG Foreign",
      golden_globe_animated: "GG Animated",
      tiff_peoples_choice: "TIFF",
      cannes_palme_dor: "Palme d'Or",
      cannes_un_certain_regard: "Un Certain Regard",
      venice_golden_lion: "Golden Lion",
      venice_grand_jury: "Venice Grand Jury"
    }

    TitleAward.where(tconst: titles.map(&:tconst)).each_with_object({}) do |award, hash|
      won_awards = TitleAward::AWARD_COLUMNS.select { |col| award.send(col) }
      hash[award.tconst] = won_awards.map { |col| award_labels[col] }.join(", ")
    end
  end
end
