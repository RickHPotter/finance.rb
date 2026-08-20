# frozen_string_literal: true

class Logic::Conversations::Page
  DEFAULT_SIZE = 20
  MAX_SIZE = 50
  Result = Data.define(:records, :next_cursor)

  attr_reader :scope, :cursor, :size

  def self.call(...)
    new(...).call
  end

  def initialize(scope:, cursor: nil, size: DEFAULT_SIZE)
    @scope = scope
    @cursor = cursor
    @size = normalize_size(size)
  end

  def call
    rows = paginated_scope.limit(size + 1).to_a
    has_more = rows.length > size
    records = rows.first(size)

    Result.new(records:, next_cursor: has_more ? cursor_for(records.last) : nil)
  end

  private

  def paginated_scope
    ordered_scope = scope.distinct.reorder(last_message_at: :desc, id: :desc)
    return ordered_scope if cursor.blank?

    value = Logic::KeysetCursor.load(cursor)
    ordered_scope.where(
      "conversations.last_message_at < :timestamp OR (conversations.last_message_at = :timestamp AND conversations.id < :id)",
      timestamp: value.timestamp,
      id: value.id
    )
  end

  def cursor_for(conversation)
    Logic::KeysetCursor.dump(timestamp: conversation.last_message_at, id: conversation.id)
  end

  def normalize_size(value)
    Integer(value).clamp(1, MAX_SIZE)
  rescue ArgumentError, TypeError
    DEFAULT_SIZE
  end
end
