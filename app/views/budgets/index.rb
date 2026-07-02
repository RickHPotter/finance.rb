# frozen_string_literal: true

class Views::Budgets::Index < Views::Base
  include Views::Budgets
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag

  include CacheHelper
  include TranslateHelper

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

              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id, :active_month_years, :sort, :direction))
              render_budget_bulk_forms
              render_budget_bulk_action_bar
            end

            render Views::Shared::MobileFloatingNav.new(new_href: new_budget_path(format: :turbo_stream))
          end
        end
      end
    end
  end

  private

  def render_budget_bulk_forms
    budget_bulk_actions.each_key do |action|
      form_with url: bulk_update_budgets_path, method: :patch, class: "hidden", data: { turbo: true }, id: "bulk_budget_#{action}_form" do
        hidden_field_tag :ids, "", data: { bulk_ids_input: true, bulk_ids_kind: "budget" }
        hidden_field_tag :bulk_action, action
        hidden_field_tag :return_to, request.fullpath
      end
    end

    form_with url: bulk_destroy_budgets_path, method: :delete, class: "hidden", data: { turbo: true }, id: "bulk_budget_destroy_form" do
      hidden_field_tag :ids, "", data: { bulk_ids_input: true, bulk_ids_kind: "budget" }
      hidden_field_tag :return_to, request.fullpath
    end
  end

  def render_budget_bulk_action_bar
    BulkActionBar(
      selected_label: action_message(:selected),
      selection_kind: "budget",
      actions: [
        *budget_bulk_action_groups.map do |group|
          {
            name: group[:name],
            ids_kind: "budget",
            selection_kind: "budget",
            title: group[:title],
            label: group[:label],
            menu_items: group[:actions].map do |action, attrs|
              {
                label: attrs[:label],
                title: attrs[:title],
                data: { action: "click->datatable#submitBulkAction", bulk_form_id: "bulk_budget_#{action}_form" }
              }
            end
          }
        end,
        {
          name: "destroy",
          ids_kind: "budget",
          selection_kind: "budget",
          title: I18n.t("bulk_actions.budgets.destroy_title"),
          label: action_message(:destroy),
          data: { action: "click->datatable#submitBulkAction", bulk_form_id: "bulk_budget_destroy_form" }
        }
      ]
    )
  end

  def budget_bulk_action_groups
    [
      {
        name: "exclusivity",
        label: I18n.t("bulk_actions.budgets.exclusivity"),
        title: I18n.t("bulk_actions.budgets.exclusivity_title"),
        actions: budget_bulk_actions.slice(:make_inclusive, :make_exclusive)
      },
      {
        name: "installments",
        label: I18n.t("bulk_actions.budgets.installments"),
        title: I18n.t("bulk_actions.budgets.installments_title"),
        actions: budget_bulk_actions.slice(:first_installment_only, :all_installments)
      }
    ]
  end

  def budget_bulk_actions
    {
      make_inclusive: {
        label: I18n.t("bulk_actions.budgets.make_inclusive"),
        title: I18n.t("bulk_actions.budgets.make_inclusive_title")
      },
      make_exclusive: {
        label: I18n.t("bulk_actions.budgets.make_exclusive"),
        title: I18n.t("bulk_actions.budgets.make_exclusive_title")
      },
      first_installment_only: {
        label: I18n.t("bulk_actions.budgets.first_installment_only"),
        title: I18n.t("bulk_actions.budgets.first_installment_only_title")
      },
      all_installments: {
        label: I18n.t("bulk_actions.budgets.all_installments"),
        title: I18n.t("bulk_actions.budgets.all_installments_title")
      }
    }
  end
end
