# frozen_string_literal: true

class Views::Shared::FilterSummary < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :summary

  def initialize(summary:)
    @summary = summary
  end

  def view_template
    return unless summary[:active]

    fieldset(class: container_class) do
      legend(class: "text-xs font-bold uppercase tracking-[0.20em] text-sky-900") { I18n.t("filters.summary.active") }

      div(class: "grid gap-3 lg:grid-cols-[auto,1fr] lg:items-start") do
        div(class: "flex flex-wrap justify-center items-center gap-2") do
          summary[:items].each do |item|
            render_filter(item)
          end
        end
      end
    end
  end

  private

  def container_class
    "rounded-lg border border-sky-200 bg-sky-50 px-3 py-2 text-xs text-slate-700"
  end

  def render_filter(item)
    link_to(
      remove_filter_path(item),
      class: "inline-flex items-center gap-2 rounded-sm ring px-2 py-1 text-xs transition-colors ring-slate-400 bg-white text-slate-700
              hover:ring-slate-600 hover:bg-slate-50",
      title: item[:label],
      aria: { label: "#{I18n.t('filters.summary.clear')}: #{item[:label]}" }
    ) do
      span(class: "text-xs md:text-sm") { item[:label] }
      span(class: "rounded bg-slate-200 px-1 text-[10px] font-semibold leading-4 text-slate-600") { "x" }
    end
  end

  def remove_filter_path(item)
    query = request.query_parameters.deep_dup

    Array(item[:remove]).each do |path|
      delete_param!(query, Array(path).map(&:to_s))
    end

    prune_empty_values!(query)

    return request.path if query.blank?

    "#{request.path}?#{query.to_query}"
  end

  def delete_param!(hash, path)
    key = path.first
    return if key.blank? || !hash.is_a?(Hash) || !hash.key?(key)

    if path.one?
      hash.delete(key)
      return
    end

    child = hash[key]
    delete_param!(child, path.drop(1))
    hash.delete(key) if child.respond_to?(:empty?) && child.empty?
  end

  def prune_empty_values!(value)
    case value
    when Hash
      value.each_key do |key|
        child = value[key]
        prune_empty_values!(child)
        value.delete(key) if child.blank?
      end
    when Array
      value.each { |child| prune_empty_values!(child) }
      value.reject!(&:blank?)
    end
  end
end
