class HomeController < ApplicationController
  def index
    @job_statuses = Setting.all_job_statuses
  end
end
