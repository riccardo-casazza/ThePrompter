class TitlesController < ApplicationController
  MAX_YEAR_RANGE = 10

  def index
    @title_types = available_title_types
    @start_year = params[:start_year].presence&.to_i
    @end_year = params[:end_year].presence&.to_i
    @title_type = params[:title_type].presence
    @sort_by = params[:sort_by].presence || "original_title"
    @sort_direction = params[:sort_direction].presence || "asc"

    @min_rating = params[:min_rating].presence&.to_f
    @min_votes = params[:min_votes].presence&.to_i

    @show_in_french_theaters = params[:show_in_french_theaters].presence || "yes"
    @show_in_italian_theaters = params[:show_in_italian_theaters].presence || "yes"
    @show_at_home = params[:show_at_home].presence || "yes"
    @show_in_plex = params[:show_in_plex].presence || "yes"
    @show_already_watched = params[:show_already_watched].presence || "no"
    @show_wip = params[:show_wip].presence || "no"
    @show_with_preferences = params[:show_with_preferences].presence || "yes"

    @titles = []
    @error = nil

    if filters_valid?
      @titles = fetch_titles
      @preferences_by_tconst = fetch_preferences_for_titles(@titles)
    elsif params[:start_year].present? || params[:title_type].present?
      @error = validation_error_message
    end
  end

  private

  def available_title_types
    TitleBasic.distinct.pluck(:title_type).sort
  end

  def filters_valid?
    return false unless @start_year && @end_year && @title_type

    @start_year <= @end_year &&
      (@end_year - @start_year) <= MAX_YEAR_RANGE &&
      @title_type.present?
  end

  def validation_error_message
    return "Please select a title type" if @title_type.blank?
    return "Please select both start and end year" if @start_year.nil? || @end_year.nil?
    return "End year must be greater than or equal to start year" if @end_year < @start_year
    return "Year range cannot exceed #{MAX_YEAR_RANGE} years" if (@end_year - @start_year) > MAX_YEAR_RANGE

    nil
  end

  def fetch_titles
    titles = TitleBasic
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
        "CASE WHEN plex_library_items.tconst IS NOT NULL THEN true ELSE false END AS in_plex"
      )
      .joins("LEFT JOIN title_ratings ON title_basics.tconst = title_ratings.tconst")
      .joins("LEFT JOIN title_movie_tmdb ON title_basics.tconst = title_movie_tmdb.tconst")
      .joins("LEFT JOIN plex_library_items ON title_basics.tconst = plex_library_items.tconst")
      .where(title_type: @title_type)
      .where(start_year: @start_year..@end_year)

    titles = titles.where("title_ratings.average_rating >= ?", @min_rating) if @min_rating
    titles = titles.where("title_ratings.num_votes >= ?", @min_votes) if @min_votes

    titles = apply_in_french_theaters_filter(titles)
    titles = apply_in_italian_theaters_filter(titles)
    titles = apply_at_home_filter(titles)
    titles = apply_in_plex_filter(titles)
    titles = apply_already_watched_filter(titles)
    titles = apply_wip_filter(titles)
    titles = apply_with_preferences_filter(titles)

    titles = titles.distinct
    titles = apply_sorting(titles)
    titles.limit(500)
  end

  def apply_sorting(scope)
    allowed_sort_columns = %w[original_title start_year average_rating theater_air_date_fr theater_air_date_it home_air_date in_plex]
    allowed_directions = %w[asc desc]

    column = allowed_sort_columns.include?(@sort_by) ? @sort_by : "original_title"
    direction = allowed_directions.include?(@sort_direction) ? @sort_direction : "asc"

    scope.order(column => direction)
  end

  # In French Theaters filter: "yes" = show all, "no" = exclude, "only" = only with FR theater date
  def apply_in_french_theaters_filter(scope)
    return scope if @show_in_french_theaters == "yes"

    if @show_in_french_theaters == "only"
      scope.where.not("title_movie_tmdb.theater_air_date_fr": nil)
    else # "no"
      scope.where("title_movie_tmdb.theater_air_date_fr": nil)
    end
  end

  # In Italian Theaters filter: "yes" = show all, "no" = exclude, "only" = only with IT theater date
  def apply_in_italian_theaters_filter(scope)
    return scope if @show_in_italian_theaters == "yes"

    if @show_in_italian_theaters == "only"
      scope.where.not("title_movie_tmdb.theater_air_date_it": nil)
    else # "no"
      scope.where("title_movie_tmdb.theater_air_date_it": nil)
    end
  end

  # At Home filter: "yes" = show all, "no" = exclude, "only" = only with home air date
  def apply_at_home_filter(scope)
    return scope if @show_at_home == "yes"

    if @show_at_home == "only"
      scope.where.not("title_movie_tmdb.home_air_date": nil)
    else # "no"
      scope.where("title_movie_tmdb.home_air_date": nil)
    end
  end

  # In Plex filter: "yes" = show all, "no" = exclude in plex, "only" = only in plex
  def apply_in_plex_filter(scope)
    return scope if @show_in_plex == "yes"

    if @show_in_plex == "only"
      scope.where.not("plex_library_items.tconst": nil)
    else # "no"
      scope.where("plex_library_items.tconst": nil)
    end
  end

  # Already watched filter: "yes" = show all, "no" = exclude watched, "only" = only watched
  def apply_already_watched_filter(scope)
    return scope if @show_already_watched == "yes"

    watched_condition = "EXISTS (SELECT 1 FROM my_ratings WHERE my_ratings.tconst = title_basics.tconst)"

    if @show_already_watched == "only"
      scope.where(watched_condition)
    else # "no"
      scope.where("NOT #{watched_condition}")
    end
  end

  # Fetch preferences (favorite people) for the given titles
  # Returns a hash: { tconst => "Name (D), Name (A), ..." }
  def fetch_preferences_for_titles(titles)
    return {} if titles.empty?

    tconsts = titles.map(&:tconst)

    # Find all principals that match my preferences for these titles
    # Use title_principals.category (their role in this movie) not my_preferences.category
    # Use DISTINCT to avoid duplicates when a person is in my_preferences for multiple categories
    matches = TitlePrincipal
      .joins("INNER JOIN my_preferences ON title_principals.nconst = my_preferences.nconst")
      .where(tconst: tconsts)
      .select("DISTINCT title_principals.tconst, title_principals.nconst, my_preferences.primary_name, title_principals.category, title_principals.ordering")
      .order("title_principals.ordering")

    # Category abbreviations
    abbreviations = {
      "director" => "D",
      "actor" => "A",
      "actress" => "A",
      "writer" => "W",
      "composer" => "C"
    }

    # Group by tconst, then by person to combine roles
    matches.group_by(&:tconst).transform_values do |people|
      # Group by nconst to combine multiple roles for the same person
      people.group_by(&:nconst).map do |_nconst, person_roles|
        name = person_roles.first.primary_name
        roles = person_roles.map { |p| abbreviations[p.category] || p.category[0].upcase }.uniq.join(", ")
        "#{name} (#{roles})"
      end.join(", ")
    end
  end

  # With preferences filter: "yes" = show all, "no" = exclude with preferences, "only" = only with preferences
  def apply_with_preferences_filter(scope)
    return scope if @show_with_preferences == "yes"

    has_preferences_condition = "EXISTS (SELECT 1 FROM title_principals " \
      "INNER JOIN my_preferences ON title_principals.nconst = my_preferences.nconst " \
      "WHERE title_principals.tconst = title_basics.tconst)"

    if @show_with_preferences == "only"
      scope.where(has_preferences_condition)
    else # "no"
      scope.where("NOT #{has_preferences_condition}")
    end
  end

  # WIP filter: "yes" = show all, "no" = exclude WIP, "only" = only WIP
  # Released means: has votes AND (has past release date OR no dates and start_year < current year)
  def apply_wip_filter(scope)
    return scope if @show_wip == "yes"

    released_condition = "(title_ratings.num_votes > 0 AND (" \
      "(title_movie_tmdb.home_air_date <= :today OR " \
      "title_movie_tmdb.theater_air_date_fr <= :today OR " \
      "title_movie_tmdb.theater_air_date_it <= :today) OR " \
      "(title_movie_tmdb.home_air_date IS NULL AND " \
      "title_movie_tmdb.theater_air_date_fr IS NULL AND " \
      "title_movie_tmdb.theater_air_date_it IS NULL AND " \
      "title_basics.start_year < :current_year)))"

    params = { today: Date.current, current_year: Date.current.year }

    if @show_wip == "only"
      scope.where("NOT (#{released_condition})", params)
    else # "no"
      scope.where(released_condition, params)
    end
  end
end
