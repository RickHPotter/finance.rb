# frozen_string_literal: true

class Views::Investments::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Views::Investments

  include CacheHelper

  attr_reader :index_context, :current_user, :mobile

  def initialize(index_context: {}, mobile: false)
    @index_context = index_context
    @current_user = index_context[:current_user]
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full" do
          turbo_frame_tag :card_transactions do
            div class: "min-h-screen", data: { controller: "datatable" } do
              div class: "mb-8 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render IndexSearchForm.new(index_context:, mobile:)
              end

              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :user_bank_account_id, :investment_type_id, :active_month_years))
            end

            render Views::Shared::MobileFloatingNav.new(new_href: new_investment_path(format: :turbo_stream))
          end
        end
      end
    end
  end
end
