# frozen_string_literal: true

class Audit::Rollback::ExecutionPlan
  class InvalidGraphError < StandardError
    attr_reader :code, :keys

    def initialize(code, keys: [])
      @code = code.to_s
      @keys = Array(keys).map(&:to_s).sort
      super([ @code, @keys.join(", ") ].compact_blank.join(": "))
    end
  end

  attr_reader :rows

  def initialize(rows:)
    @rows = rows
  end

  def ordered_rows
    @ordered_rows ||= begin
      validate_unique_keys!
      graph = build_graph
      topological_rows(graph)
    end
  end

  private

  def validate_unique_keys!
    duplicate_keys = rows.group_by(&:key).select { |_key, grouped_rows| grouped_rows.many? }.keys
    raise InvalidGraphError.new(:duplicate_keys, keys: duplicate_keys) if duplicate_keys.present?
  end

  def build_graph
    rows_by_key = rows.index_by(&:key)
    rows.each_with_object(rows.to_h { |row| [ row.key, Set.new ] }) do |row, graph|
      row.dependencies.select(&:included).each do |dependency|
        dependency_row = rows_by_key[dependency.key]
        raise InvalidGraphError.new(:missing_included_dependency, keys: [ row.key, dependency.key ]) unless dependency_row

        before_key, after_key = ordered_edge(row, dependency_row, dependency.relationship)
        graph.fetch(before_key) << after_key unless before_key == after_key
      end
    end
  end

  def ordered_edge(row, dependency_row, relationship)
    case relationship
    when "parent"
      parent_child_edge(parent: dependency_row, child: row)
    when "dependent"
      parent_child_edge(parent: row, child: dependency_row)
    else
      raise InvalidGraphError.new(:unknown_relationship, keys: [ row.key, dependency_row.key ])
    end
  end

  def parent_child_edge(parent:, child:)
    child.action == "destroy" ? [ child.key, parent.key ] : [ parent.key, child.key ]
  end

  def topological_rows(graph)
    rows_by_key = rows.index_by(&:key)
    ordered_keys = topological_keys(graph, incoming_counts_for(graph, rows_by_key.keys))
    ordered_keys.map { |key| rows_by_key.fetch(key) }
  end

  def topological_keys(graph, incoming_counts)
    available_keys = incoming_counts.select { |_key, count| count.zero? }.keys.sort
    ordered_keys = []
    until available_keys.empty?
      key = available_keys.shift
      ordered_keys << key
      graph.fetch(key).sort.each do |dependent_key|
        incoming_counts[dependent_key] -= 1
        insert_sorted(available_keys, dependent_key) if incoming_counts[dependent_key].zero?
      end
    end

    cyclic_keys = incoming_counts.select { |_key, count| count.positive? }.keys
    raise InvalidGraphError.new(:cyclic_dependencies, keys: cyclic_keys) if cyclic_keys.present?

    ordered_keys
  end

  def incoming_counts_for(graph, keys)
    keys.to_h { |key| [ key, 0 ] }.tap do |incoming_counts|
      graph.each_value do |dependent_keys|
        dependent_keys.each { |key| incoming_counts[key] += 1 }
      end
    end
  end

  def insert_sorted(keys, key)
    keys.insert(keys.bsearch_index { |candidate| candidate >= key } || keys.length, key)
  end
end
