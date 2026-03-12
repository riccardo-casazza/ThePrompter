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

    link_to titles_path(link_params) do
      "#{label} <span class='sort-indicator'>#{indicator}</span>".html_safe
    end
  end
end
