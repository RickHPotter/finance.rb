# frozen_string_literal: true

class Views::Shared::MonthYearContainer < Views::Base
  attr_reader :active_month_years, :custom_params, :path_lambda, :frame_data

  def initialize(active_month_years:, custom_params:, path_lambda:, frame_data: {})
    @active_month_years = active_month_years
    @custom_params = custom_params
    @path_lambda = path_lambda
    @frame_data = frame_data
  end

  def view_template
    turbo_frame_tag :month_year_container, data: frame_data do
      active_month_years.sort.each do |month_year|
        turbo_frame_tag "month_year_container_#{month_year}", src: path_lambda.call(custom_params.merge(month_year:))
      end
    end
  end
end
