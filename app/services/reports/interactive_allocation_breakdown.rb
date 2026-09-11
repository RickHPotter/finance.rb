# frozen_string_literal: true

module Reports
  class InteractiveAllocationBreakdown
    DIMENSIONS = %i[category entity].freeze
    BASE_CATEGORY_EXCLUSIONS = [ "EXCHANGE", "EXCHANGE RETURN" ].freeze
    GROUP_CATEGORY_EXCLUSIONS = [ "EXCHANGE RETURN" ].freeze

    attr_reader :rows, :query_state, :primary_dimension

    def initialize(rows:, query_state:, primary_dimension:)
      @rows = rows
      @query_state = query_state
      @primary_dimension = primary_dimension.to_sym

      raise ArgumentError, "unsupported interactive allocation dimension" unless primary_dimension.in?(DIMENSIONS)
    end

    def call
      entries = {}
      rows.each { |row| append_row(entries, row) }

      {
        primary_kind: primary_dimension,
        secondary_kind: secondary_dimension,
        granularity: query_state.granularity,
        periods: period_keys,
        items: serialize_entries(entries.values)
      }
    end

    private

    def append_row(entries, row)
      categories = row.transaction.categories.uniq(&:id).sort_by { |category| [ category.name, category.id ] }
      entities = row.transaction.entities.uniq(&:id).sort_by { |entity| [ entity.name, entity.id ] }

      if primary_dimension == :category
        append_category_row(entries, row, categories, entities)
      else
        append_entity_row(entries, row, categories, entities)
      end
    end

    def append_category_row(entries, row, categories, entities)
      base_categories = categories.reject { |category| base_category_excluded?(category) }
      return if base_categories.empty? || entities.empty?

      base_categories.each do |base_category|
        entry = ensure_primary_entry(entries, base_category)
        extra_categories = categories.reject { |category| category.id == base_category.id || group_category_excluded?(category) }
        group = extra_categories.empty? ? exact_group(entry, base_category) : combination_group(entry, base_category, extra_categories)
        secondary = ensure_secondary_entry(group, entities, :entity)
        append_amount(secondary, row)
      end
    end

    def append_entity_row(entries, row, categories, entities)
      visible_categories = categories.reject { |category| group_category_excluded?(category) }
      return if visible_categories.empty? || entities.empty?

      entities.each do |base_entity|
        entry = ensure_primary_entry(entries, base_entity)
        extra_entities = entities.reject { |entity| entity.id == base_entity.id }
        group = extra_entities.empty? ? exact_group(entry, base_entity) : combination_group(entry, base_entity, extra_entities)
        secondary = ensure_secondary_entry(group, visible_categories, :category)
        append_amount(secondary, row)
      end
    end

    def ensure_primary_entry(entries, record)
      entries[record.id] ||= { id: record.id.to_s, name: record.name, groups: {} }
    end

    def exact_group(entry, record)
      entry[:groups]["__all__"] ||= {
        id: "__all__",
        label: I18n.t("reports.interactive_breakdown.only", name: record.name),
        rank: -1,
        secondary_items: {}
      }
    end

    def combination_group(entry, base_record, extra_records)
      records = [ base_record, *extra_records ].sort_by { |record| [ record.name, record.id ] }
      id = records.map(&:id).join("-")
      entry[:groups][id] ||= {
        id:,
        label: "+ #{extra_records.map(&:name).join(' & ')}",
        rank: 1,
        secondary_items: {}
      }
    end

    def ensure_secondary_entry(group, records, dimension)
      ids = records.map(&:id)
      id = ids.join("-")
      group[:secondary_items][id] ||= secondary_payload(records, dimension).merge(
        id:,
        rank: records.length,
        total_cents: 0,
        points: Hash.new(0)
      )
    end

    def secondary_payload(records, dimension)
      payload = { name: records.map(&:name).join(" / ") }
      return payload.merge(avatar_paths: records.filter_map { |entity| avatar_path(entity) }) if dimension == :entity

      presentation = CategoryColours::Presentation.bundle(records).chart_payload
      payload.merge(chart_presentation: presentation.except(:segments), swatches: presentation[:segments].first(3))
    end

    def avatar_path(entity)
      return if entity.avatar_name.blank?

      ActionController::Base.helpers.asset_path("avatars/#{entity.avatar_name}")
    end

    def append_amount(secondary, row)
      secondary[:total_cents] += row.amount_cents
      secondary[:points][point_key(row)] += row.amount_cents
    end

    def point_key(row)
      query_state.granularity == "day" ? row.occurred_on.iso8601 : "#{row.period_key}-01"
    end

    def period_keys
      query_state.periods.map do |period|
        query_state.granularity == "day" ? period.iso8601 : period.strftime("%Y-%m-01")
      end
    end

    def serialize_entries(entries)
      entries.sort_by { |entry| [ entry[:name], entry[:id] ] }.map do |entry|
        groups = entry[:groups].values
        entry.except(:groups).merge(
          groups: serialize_groups(groups),
          all_secondary_items: serialize_secondary_items(combine_secondary_items(groups))
        )
      end
    end

    def combine_secondary_items(groups)
      groups.each_with_object({}) do |group, combined|
        group[:secondary_items].each_value do |item|
          target = combined[item[:id]] ||= item.except(:total_cents, :points).merge(total_cents: 0, points: Hash.new(0))
          target[:total_cents] += item[:total_cents]
          item[:points].each { |key, amount_cents| target[:points][key] += amount_cents }
        end
      end.values
    end

    def serialize_groups(groups)
      groups.sort_by { |group| [ group[:rank], group[:label], group[:id] ] }.map do |group|
        group.except(:rank, :secondary_items).merge(secondary_items: serialize_secondary_items(group[:secondary_items].values))
      end
    end

    def serialize_secondary_items(items)
      items.sort_by { |item| [ item[:rank], -item[:total_cents].abs, item[:name], item[:id] ] }.map do |item|
        item.except(:rank).merge(points: item[:points].sort.map { |key, amount_cents| { x: key, amount_cents: } })
      end
    end

    def base_category_excluded?(category)
      category.built_in? && category.category_name.in?(BASE_CATEGORY_EXCLUSIONS)
    end

    def group_category_excluded?(category)
      category.built_in? && category.category_name.in?(GROUP_CATEGORY_EXCLUSIONS)
    end

    def secondary_dimension
      primary_dimension == :category ? :entity : :category
    end
  end
end
