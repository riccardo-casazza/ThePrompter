module TitlesHelper
  def sort_link(label, column)
    direction = if params[:sort_by] == column && params[:sort_direction] == "asc"
                  "desc"
                else
                  "asc"
                end

    indicator = if params[:sort_by] == column
                  params[:sort_direction] == "asc" ? "▲" : "▼"
                else
                  ""
                end

    link_params = request.query_parameters.merge(sort_by: column, sort_direction: direction)

    # Use the current path (works for both titles and awards)
    target_path = request.path == "/awards" ? awards_path(link_params) : titles_path(link_params)

    link_to target_path do
      "#{label} <span class='sort-indicator'>#{indicator}</span>".html_safe
    end
  end
end
