require "rails_helper"

RSpec.describe "Titles", type: :request do
  describe "GET /titles" do
    before do
      create(:title_basic, tconst: "tt0000001", title_type: "movie", original_title: "Alpha Movie", start_year: 2020)
      create(:title_basic, tconst: "tt0000002", title_type: "movie", original_title: "Beta Movie", start_year: 2021)
      create(:title_basic, tconst: "tt0000003", title_type: "movie", original_title: "Gamma Movie", start_year: 2022)
      create(:title_basic, tconst: "tt0000004", title_type: "tvSeries", original_title: "Delta Series", start_year: 2021)
      create(:title_basic, tconst: "tt0000005", title_type: "movie", original_title: "Epsilon Movie", start_year: 2015)
    end

    context "without filters" do
      it "renders the page with instructions" do
        get titles_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Select a type and year range")
      end

      it "does not show any titles" do
        get titles_path

        expect(response.body).not_to include("Alpha Movie")
      end
    end

    context "with valid filters" do
      it "shows titles matching the filters" do
        get titles_path, params: { title_type: "movie", start_year: 2020, end_year: 2022 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alpha Movie")
        expect(response.body).to include("Beta Movie")
        expect(response.body).to include("Gamma Movie")
      end

      it "filters by title type" do
        get titles_path, params: { title_type: "tvSeries", start_year: 2020, end_year: 2022 }

        expect(response.body).to include("Delta Series")
        expect(response.body).not_to include("Alpha Movie")
      end

      it "filters by year range" do
        get titles_path, params: { title_type: "movie", start_year: 2020, end_year: 2021 }

        expect(response.body).to include("Alpha Movie")
        expect(response.body).to include("Beta Movie")
        expect(response.body).not_to include("Gamma Movie")
        expect(response.body).not_to include("Epsilon Movie")
      end

      it "sorts by title ascending by default" do
        get titles_path, params: { title_type: "movie", start_year: 2020, end_year: 2022 }

        expect(response.body).to match(/Alpha Movie.*Beta Movie.*Gamma Movie/m)
      end

      it "sorts by title descending" do
        get titles_path, params: { title_type: "movie", start_year: 2020, end_year: 2022, sort_by: "original_title", sort_direction: "desc" }

        expect(response.body).to match(/Gamma Movie.*Beta Movie.*Alpha Movie/m)
      end

      it "sorts by year" do
        get titles_path, params: { title_type: "movie", start_year: 2020, end_year: 2022, sort_by: "start_year", sort_direction: "desc" }

        expect(response.body).to match(/Gamma Movie.*Beta Movie.*Alpha Movie/m)
      end
    end

    context "with invalid filters" do
      it "shows error when year range exceeds maximum" do
        get titles_path, params: { title_type: "movie", start_year: 2000, end_year: 2020 }

        expect(response.body).to include("Year range cannot exceed")
      end

      it "shows error when end year is before start year" do
        get titles_path, params: { title_type: "movie", start_year: 2022, end_year: 2020 }

        expect(response.body).to include("End year must be greater than or equal to start year")
      end

      it "shows error when title type is missing" do
        get titles_path, params: { start_year: 2020, end_year: 2022 }

        expect(response.body).to include("Please select a title type")
      end

      it "shows error when years are missing" do
        get titles_path, params: { title_type: "movie" }

        expect(response.body).to include("Please select both start and end year")
      end
    end

    context "results limit" do
      before do
        501.times do |i|
          create(:title_basic, tconst: "tt1#{i.to_s.rjust(6, '0')}", title_type: "short", original_title: "Short #{i}", start_year: 2020)
        end
      end

      it "limits results to 500" do
        get titles_path, params: { title_type: "short", start_year: 2020, end_year: 2020 }

        expect(response.body).to include("limited to 500 results")
      end
    end
  end
end
