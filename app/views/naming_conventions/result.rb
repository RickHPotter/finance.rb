# frozen_string_literal: true

class Views::NamingConventions::Result < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include TranslateHelper

  attr_reader :results, :dry_run

  def initialize(results:, dry_run:)
    @results = results
    @dry_run = dry_run
  end

  def view_template
    turbo_frame_tag :naming_convention_content do
      div(class: "w-[min(56rem,88vw)] text-black", data: { controller: "naming-tabs", naming_tabs_current_value: tab_names.first }) do
        p(class: "text-sm text-gray-700") { summary_text }

        if changed_results.any?
          div(class: "mt-4 flex flex-wrap gap-2") do
            grouped_results.each_key do |name|
              button(
                type: :button,
                class: "rounded-full px-3 py-1 text-sm font-semibold transition-colors bg-gray-200 text-gray-700",
                data: { action: "click->naming-tabs#select", naming_tabs_target: "tab", naming_tabs_name: name }
              ) { "#{convention_label(name)} (#{grouped_results[name].count})" }
            end
          end

          div(class: "mt-4 h-[min(26rem,55vh)] overflow-hidden rounded-lg border border-gray-400 bg-gray-200") do
            grouped_results.each do |name, convention_results|
              div(class: "h-full overflow-y-auto hidden", data: { naming_tabs_target: "panel", naming_tabs_name: name }) do
                name == :exchange_return ? render_exchange_return_results(convention_results) : render_standard_results(convention_results)
              end
            end
          end
        end

        div(class: "mt-4 flex justify-between gap-3") do
          form_with(url: preview_naming_convention_path, method: :post, data: { turbo_frame: :naming_convention_content }) do |form|
            form.submit(dry_run ? I18n.t("naming_conventions.refresh_preview") : I18n.t("naming_conventions.preview_again"), class: secondary_button_class)
          end

          if dry_run && changed_results.any?
            form_with(url: naming_convention_path, method: :patch, data: { turbo_stream: true, turbo_frame: :naming_convention_content }) do |form|
              form.submit I18n.t("confirmation.confirm"), class: primary_button_class
            end
          end
        end
      end
    end
  end

  private

  def changed_results
    @changed_results ||= results.select { |result| result[:changes].present? }
  end

  def grouped_results
    @grouped_results ||= changed_results.group_by { |result| result[:convention] }
  end

  def tab_names
    grouped_results.keys
  end

  def summary_text
    if changed_results.empty?
      dry_run ? I18n.t("naming_conventions.no_changes_found") : I18n.t("naming_conventions.no_changes_applied")
    elsif dry_run
      I18n.t("naming_conventions.will_update", count: changed_results.count)
    else
      I18n.t("naming_conventions.did_update", count: changed_results.count)
    end
  end

  def record_label(result)
    model_name = result.dig(:record, :type).to_s.safe_constantize&.model_name&.human || result.dig(:record, :type)
    "#{model_name} ##{result.dig(:record, :id)}"
  end

  def render_standard_results(convention_results)
    ul(class: "divide-y divide-gray-200") do
      convention_results.each do |result|
        li(class: "px-4 py-3 text-sm") do
          render_result_diff(result)
        end
      end
    end
  end

  def render_exchange_return_results(convention_results)
    grouped_exchange_results(convention_results).each_value do |exchange_results|
      exchange_metadata = exchange_results.first[:metadata] || {}
      card_transaction = exchange_metadata[:card_transaction] || {}

      div(class: "border-b border-gray-400 last:border-b-0") do
        div(class: "sticky top-0 z-10 border-b border-gray-400 bg-white/95 px-4 py-3 backdrop-blur-sm") do
          div(class: "text-sm font-semibold text-gray-900") do
            plain "#{I18n.t('naming_conventions.group.card_transaction')} ##{card_transaction[:id] || '-'}"
            plain " · #{card_transaction[:description]}" if card_transaction[:description].present?
          end

          div(class: "mt-1 text-xs text-gray-600") do
            plain "#{I18n.t('naming_conventions.group.installments_count')}: #{card_transaction[:installments_count] || '-'}"
            plain " · #{I18n.t('naming_conventions.group.exchanges_count')}: #{card_transaction[:exchanges_count] || '-'}"
            plain " · #{I18n.t('naming_conventions.group.entity')}: #{card_transaction[:entity_name] || '-'}"
          end
        end

        ul(class: "divide-y divide-gray-200") do
          exchange_results.each do |result|
            li(class: "px-4 py-3 text-sm") do
              render_result_diff(result)
            end
          end
        end
      end
    end
  end

  def grouped_exchange_results(convention_results)
    convention_results.group_by { |result| result.dig(:metadata, :group_key) || "ungrouped" }
  end

  def render_result_diff(result)
    div(class: "font-semibold text-gray-900") { record_label(result) }
    div(class: "mt-1 text-red-700 line-through break-words") { result.dig(:previous_attributes, :description) }
    div(class: "mt-1 text-green-700 break-words") { result.dig(:changes, :description) }
  end

  def convention_label(name)
    I18n.t("naming_conventions.conventions.#{name}")
  end

  def primary_button_class
    "bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded cursor-pointer"
  end

  def secondary_button_class
    "bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded cursor-pointer"
  end
end
