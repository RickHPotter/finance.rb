# frozen_string_literal: true

class Views::Audit::FilterForm < Views::Base
  INPUT_CLASS = "mt-1 block min-h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 " \
                "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100"
  CLEAR_CLASS = "inline-flex min-h-10 items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 " \
                "dark:border-slate-700 dark:text-slate-200"

  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :url, :filters, :current_user, :record_filter

  def initialize(url:, filters:, current_user:, record_filter: false)
    @url = url
    @filters = filters.to_h.stringify_keys
    @current_user = current_user
    @record_filter = record_filter
  end

  def view_template
    details(open: active_filters?, class: "border-b border-slate-200 pb-4 dark:border-slate-700") do
      summary(class: "cursor-pointer text-sm font-semibold text-slate-700 dark:text-slate-200") { I18n.t("audit.filters.title") }

      form_with(url:, method: :get, class: "mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4") do |form|
        select_field(form, :item_type, item_type_options) unless record_filter
        input_field(form, :item_id, type: :number) unless record_filter
        input_field(form, :operation_id)
        select_field(form, :event, enum_options(AuditVersion::EVENTS, "audit.events"))
        select_field(form, :source, enum_options(AuditOperation::ROOT_SOURCES, "audit.sources"))
        select_field(form, :mutation_source, enum_options(AuditVersion::MUTATION_SOURCES, "audit.sources"))
        input_field(form, :actor_id, type: :number)
        input_field(form, :owner_id, type: :number) if current_user.admin?
        input_field(form, :context_id, type: :number)
        input_field(form, :request_id)
        input_field(form, :created_from, type: :date)
        input_field(form, :created_to, type: :date)
        select_field(form, :per_page, [ [ "25", 25 ], [ "50", 50 ], [ "100", 100 ] ])

        div(class: "flex items-end gap-2") do
          form.submit(I18n.t("actions.search"),
                      class: "min-h-10 flex-1 rounded-md bg-slate-950 px-4 py-2 text-sm font-semibold text-white dark:bg-slate-100 dark:text-slate-950")
          link_to(I18n.t("filters.summary.clear"), url, class: CLEAR_CLASS)
        end
      end
    end
  end

  private

  def input_field(form, name, type: :text)
    label(class: "block text-xs font-semibold uppercase text-slate-500 dark:text-slate-400") do
      span { I18n.t("audit.fields.#{name}") }
      form.public_send(:"#{type}_field", name, value: filters[name], class: INPUT_CLASS)
    end
  end

  def select_field(form, name, options)
    label(class: "block text-xs font-semibold uppercase text-slate-500 dark:text-slate-400") do
      span { I18n.t("audit.fields.#{name}") }
      form.select(name, options, { selected: filters[name], include_blank: I18n.t("actions.all") },
                  class: INPUT_CLASS)
    end
  end

  def item_type_options
    Audit::VersionQuery::ITEM_TYPES.map do |type|
      model = type.safe_constantize
      [ model&.model_name&.human || type, type ]
    end.sort_by(&:first)
  end

  def enum_options(values, prefix)
    values.map { |value| [ I18n.t("#{prefix}.#{value}", default: value.humanize), value ] }
  end

  def active_filters?
    ignored_filters = %w[page per_page]
    ignored_filters.push("item_type", "item_subtype", "item_id") if record_filter
    filters.except(*ignored_filters).values.any?(&:present?)
  end
end
