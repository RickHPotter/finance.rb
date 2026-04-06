# frozen_string_literal: true

class Logic::ExchangeAuditConnections
  attr_reader :current_user, :rows, :selected_connected_user_id

  def initialize(rows:, current_user:, selected_connected_user_id: nil)
    @rows = rows
    @current_user = current_user
    @selected_connected_user_id = selected_connected_user_id.presence&.to_i
  end

  def call
    visible_rows = rows.select { |row| row_visible_to_current_user?(row) }
    connections = build_connections(visible_rows)
    selected_connection = selected_connection_for(connections)

    {
      connections:,
      selected_connected_user_id: selected_connection&.dig(:connected_user_id),
      selected_connection:,
      rows: selected_connection.present? ? selected_connection[:rows] : []
    }
  end

  private

  def build_connections(visible_rows)
    counterpart_users = users_by_id(visible_rows)
    grouped_rows = visible_rows.group_by { |row| counterpart_id_for(row) }
    connections = grouped_rows.filter_map do |connected_user_id, connection_rows|
      build_connection(connected_user_id:, connection_rows:, counterpart_users:)
    end

    connections.sort_by do |connection|
      [
        connection[:status] == "pending" ? 0 : 1,
        -connection[:pending_count],
        -connection[:row_count],
        connection.dig(:user, :first_name).to_s.downcase,
        connection.dig(:user, :id).to_i
      ]
    end
  end

  def build_connection(connected_user_id:, connection_rows:, counterpart_users:)
    counterpart = counterpart_users[connected_user_id]
    return if counterpart.blank?

    pending_count = connection_rows.count { |row| row[:status] == "pending" }

    {
      connected_user_id:,
      user: serialize_user(counterpart),
      row_count: connection_rows.size,
      pending_count:,
      done_count: connection_rows.count { |row| row[:status] == "done" },
      latest_message_at: connection_rows.filter_map { |row| row.dig(:message, :created_at) }.max,
      your_entity_names: entity_names_for(current_user, counterpart),
      their_entity_names: entity_names_for(counterpart, current_user),
      status: pending_count.positive? ? "pending" : "done",
      rows: sorted_connection_rows(connection_rows)
    }
  end

  def selected_connection_for(connections)
    return if connections.blank?

    connections.find { |connection| connection[:connected_user_id] == selected_connected_user_id } || connections.first
  end

  def users_by_id(visible_rows)
    connected_user_ids = visible_rows.map { |row| counterpart_id_for(row) }.uniq

    User.where(id: connected_user_ids).index_by(&:id)
  end

  def row_visible_to_current_user?(row)
    row.dig(:sender, :id) == current_user.id || row.dig(:receiver, :id) == current_user.id
  end

  def counterpart_id_for(row)
    row.dig(:sender, :id) == current_user.id ? row.dig(:receiver, :id) : row.dig(:sender, :id)
  end

  def serialize_user(user)
    {
      id: user.id,
      first_name: user.first_name,
      email: user.email
    }
  end

  def entity_names_for(owner, related_user)
    owner.entities.that_are_users.where(entity_user_id: related_user.id).order(:entity_name).pluck(:entity_name)
  end

  def sorted_connection_rows(connection_rows)
    connection_rows.sort_by do |row|
      [ row.dig(:message, :created_at) || Time.at(0), row.dig(:message, :id) || 0 ]
    end.reverse
  end
end
