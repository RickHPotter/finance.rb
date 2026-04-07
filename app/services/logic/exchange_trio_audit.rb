# frozen_string_literal: true

module Logic
  class ExchangeTrioAudit # rubocop:disable Metrics/ClassLength
    attr_reader :connected_user_id, :current_user

    def initialize(current_user: nil, connected_user_id: nil)
      @current_user = current_user
      @connected_user_id = connected_user_id.presence&.to_i
    end

    def call
      candidate_messages.filter_map do |message|
        build_row(message)
      end
    end

    private

    def candidate_messages
      scope = Message.includes(:user, :reference_transactable, conversation: :users)
                     .joins(:conversation)
                     .merge(Conversation.assistant)
                     .where(superseded_by_id: nil)
                     .where(body: %w[notification:create notification:update])
                     .order(created_at: :desc)

      scope = scope.where(conversation_id: visible_conversation_scope.select(:id)) if current_user.present?

      messages = scope.to_a
      preload_reference_transactable_categories(messages)
      messages
    end

    def visible_conversation_scope
      return @visible_conversation_scope if defined?(@visible_conversation_scope)

      scope = Conversation.assistant.joins(:conversation_participants)
                          .where(conversation_participants: { user_id: current_user.id })
      scope = scope.for_users([ current_user.id, connected_user_id ]) if connected_user_id.present?

      @visible_conversation_scope = scope.distinct
    end

    def build_row(message)
      return unless message.notification_payload_v2?

      context = build_message_context(message)
      return if context.blank?

      payload = build_row_payload(message, context)
      context[:status] = payload[:issues].empty? ? "done" : "pending"

      payload.merge(status: context[:status])
    end

    def build_row_payload(message, context) # rubocop:disable Metrics/AbcSize
      source_transaction = context[:source_transaction]
      source_intent = context[:source_intent]
      row_chain = build_row_chain(
        source_transaction:,
        receiver_reference: context[:receiver_reference],
        receiver_candidates: context[:receiver_candidates],
        intent: source_intent
      )
      row_issues = issues_for(row_chain)

      {
        message: serialize_message(message, receiver_context: context[:receiver_context]),
        sender: serialize_user(message.user),
        receiver: serialize_user(context[:receiver], context: context[:receiver_context]),
        chain_kind: chain_kind_for(source_transaction, source_intent),
        source: row_chain[:source_node],
        middle: row_chain[:middle_node],
        middle_candidates: serialize_middle_candidates(row_chain[:middle_candidates], source_transaction:),
        middle_candidates_count: row_chain[:middle_candidates].size,
        receiver_candidates: serialize_receiver_candidates(row_chain[:receiver_candidates], middle_transaction: row_chain[:middle_candidates].first),
        receiver_candidates_count: row_chain[:receiver_candidates].size,
        end_kind: end_kind_for(source_transaction, source_intent),
        end_transactions: row_chain[:end_nodes],
        intent: source_intent,
        issues: row_issues,
        proposed_changes: proposed_changes_for(row_chain[:source_node], row_chain[:middle_node], row_chain[:end_nodes])
      }
    end

    def build_row_chain(source_transaction:, receiver_reference:, receiver_candidates:, intent:)
      middle_candidates = shared_return_candidates_for(source_transaction)
      middle_transaction = middle_candidates.first
      receiver_end_transactions = receiver_end_transactions_for(
        source_transaction:,
        receiver_reference:,
        intent:
      )

      {
        source_transaction:,
        intent:,
        middle_candidates:,
        receiver_reference:,
        receiver_candidates:,
        source_node: serialize_transaction(source_transaction, expected_reference: nil, node_key: "source"),
        middle_node: serialize_transaction(middle_transaction, expected_reference: source_transaction, node_key: "middle"),
        end_nodes: serialize_end_transactions(
          source_transaction:,
          intent:,
          middle_transaction:,
          receiver_reference:,
          receiver_end_transactions:
        )
      }
    end

    def build_message_context(message)
      receiver = message.conversation.friend_for(message.user)
      return if receiver.blank?

      receiver_context = receiver_context_for(receiver, message.conversation.scenario_key)
      return if receiver_context.blank?

      source_transaction = source_transaction_for(message.reference_transactable)
      return if source_transaction.blank?
      return unless linked_to_receiver?(source_transaction, receiver)

      source_intent = exchange_intent_for(message, source_transaction, receiver_context:)
      receiver_resolution = receiver_reference_resolution_for(
        message:,
        receiver_context:,
        source_transaction:,
        intent: source_intent
      )

      {
        receiver:,
        receiver_context:,
        receiver_reference: receiver_resolution[:reference],
        receiver_candidates: receiver_resolution[:candidates],
        source_transaction:,
        source_intent:,
        status: nil
      }
    end

    def receiver_context_for(receiver, scenario_key)
      return receiver.ensure_main_context! if scenario_key.blank?

      receiver.contexts.find_by(scenario_key:)
    end

    def source_transaction_for(reference_transactable, visited = [])
      return if reference_transactable.blank?

      visit_key = [ reference_transactable.class.name, reference_transactable.id ]
      return if visited.include?(visit_key)

      visited << visit_key

      case reference_transactable
      when CardTransaction
        return reference_transactable if exchange_source_transaction?(reference_transactable)
      when CashTransaction
        return reference_transactable if exchange_source_transaction?(reference_transactable)

        direct_reference = load_reference_transactable_for(reference_transactable)
        direct_reference = source_transaction_for(direct_reference, visited)
        return direct_reference if direct_reference.present?

        projection_source = projection_source_transaction_for(reference_transactable)

        return source_transaction_for(projection_source, visited)
      end

      nil
    end

    def exchange_source_transaction?(transaction)
      category_names_for(transaction).include?("EXCHANGE")
    end

    def linked_to_receiver?(transaction, receiver)
      transaction.entity_transactions.joins(:entity).where(entities: { entity_user_id: receiver.id }).exists?
    end

    def exchange_intent_for(message, source_transaction, receiver_context: nil)
      message.replay_payload&.fetch("intent", nil).presence ||
        inferred_exchange_intent_for(source_transaction, receiver_context:) ||
        historical_exchange_intent_for(source_transaction)
    end

    def historical_exchange_intent_for(source_transaction)
      headers = Message.where(reference_transactable: source_transaction)
                       .where(body: %w[notification:create notification:update])
                       .where(superseded_by_id: nil)
                       .where.not(headers: [ nil, "" ])
                       .order(created_at: :desc)
                       .pick(:headers)
      return if headers.blank?

      payload = JSON.parse(headers)
      payload["intent"] || payload.dig("replay", "intent")
    rescue JSON::ParserError
      nil
    end

    def inferred_exchange_intent_for(source_transaction, receiver_context:)
      return if receiver_context.blank?
      return if source_transaction.is_a?(CardTransaction)

      receiver_descendants = receiver_family_descendants_for(source_transaction, receiver_context:)
      descendant_categories = receiver_descendants.flat_map { |transaction| category_names_for(transaction) }.uniq

      return "reimbursement" if descendant_categories.include?("BORROW RETURN") && !descendant_categories.include?("EXCHANGE")
      return "loan" if descendant_categories.include?("EXCHANGE")

      nil
    end

    def receiver_reference_resolution_for(message:, receiver_context:, source_transaction:, intent:)
      strict_reference = message.local_reference_for(context: receiver_context)
      return { reference: strict_reference, candidates: [] } if strict_reference.present?

      descendant_reference = descendant_receiver_reference_for(
        receiver_context:,
        source_transaction:,
        intent:
      )
      return { reference: descendant_reference, candidates: [] } if descendant_reference.present?

      receiver_candidates = manual_receiver_reference_candidates(
        receiver_context:,
        sender_user_id: message.user_id,
        middle_candidates: shared_return_candidates_for(source_transaction),
        end_kind: end_kind_for(source_transaction, intent)
      )

      legacy_reference = legacy_receiver_reference_for(
        message:,
        receiver_context:,
        source_transaction:,
        intent:
      )

      {
        reference: legacy_reference,
        candidates: receiver_candidates
      }
    end

    def receiver_reference_for(message:, receiver_context:, source_transaction:, intent:)
      receiver_reference_resolution_for(
        message:,
        receiver_context:,
        source_transaction:,
        intent:
      )[:reference]
    end

    def descendant_receiver_reference_for(receiver_context:, source_transaction:, intent:)
      expected_categories = expected_receiver_category_names(end_kind_for(source_transaction, intent))
      descendants = receiver_family_descendants_for(source_transaction, receiver_context:)

      matching_descendants = descendants.select do |candidate|
        expected_categories.intersect?(category_names_for(candidate))
      end

      matching_descendants.min_by { |candidate| [ candidate.created_at || Time.at(0), candidate.id || 0 ] }
    end

    def receiver_family_descendants_for(source_transaction, receiver_context:)
      receiver_ids = receiver_context.cash_transactions.pluck(:id)

      CashTransaction.reference_descendants_for(source_transaction).select do |candidate|
        receiver_ids.include?(candidate.id)
      end
    end

    def legacy_receiver_reference_for(message:, receiver_context:, source_transaction:, intent:)
      signature_reference = receiver_signature_reference_for(message.reference_transactable, source_transaction)
      return if signature_reference.blank?

      candidates = legacy_receiver_reference_candidates(
        receiver_context:,
        sender_user_id: message.user_id,
        signature_reference:,
        end_kind: end_kind_for(source_transaction, intent)
      )
      return if candidates.blank?

      candidates.min_by do |candidate|
        [
          receiver_reference_distance(candidate, message),
          -(candidate.created_at || Time.at(0)).to_i,
          -(candidate.id || 0)
        ]
      end
    end

    def manual_receiver_reference_candidates(receiver_context:, sender_user_id:, middle_candidates:, end_kind:)
      return [] if middle_candidates.blank?

      signature_keys = middle_candidates.map { |candidate| transaction_signature_key(candidate) }.uniq
      candidates = receiver_context.cash_transactions
                                   .includes(:categories, :cash_installments, :entities)
                                   .joins(:entities, :categories)
                                   .where(entities: { entity_user_id: sender_user_id })
                                   .where(categories: { category_name: expected_receiver_category_names(end_kind) })
                                   .distinct

      matching_candidates = candidates.select do |candidate|
        signature_keys.include?(transaction_signature_key(candidate))
      end

      matching_candidates.sort_by { |candidate| [ candidate.created_at || Time.at(0), candidate.id || 0 ] }
    end

    def receiver_signature_reference_for(message_reference, source_transaction)
      return message_reference if message_reference.is_a?(CashTransaction)
      return shared_return_candidates_for(source_transaction).first if message_reference.is_a?(CardTransaction)

      source_transaction if source_transaction.is_a?(CashTransaction)
    end

    def legacy_receiver_reference_candidates(receiver_context:, sender_user_id:, signature_reference:, end_kind:)
      receiver_context.cash_transactions
                      .includes(:categories, :cash_installments, :entities)
                      .joins(:entities, :categories)
                      .where(entities: { entity_user_id: sender_user_id })
                      .where(categories: { category_name: expected_receiver_category_names(end_kind) })
                      .distinct
                      .select do |candidate|
        candidate.description == signature_reference.description &&
          candidate.price.abs == signature_reference.price.abs &&
          installment_signature(candidate) == installment_signature(signature_reference)
      end
    end

    def expected_receiver_category_names(end_kind)
      return [ "EXCHANGE" ] if end_kind == "loan_receiver_combo"

      [ "BORROW RETURN", "EXCHANGE RETURN" ]
    end

    def installment_signature(transaction)
      return [] unless transaction.respond_to?(:cash_installments)

      transaction.cash_installments.to_a.sort_by { |installment| [ installment.number, installment.date ] }.map do |installment|
        [ installment.number, installment.price.abs ]
      end
    end

    def transaction_signature_key(transaction)
      [ transaction.price.abs, installment_signature(transaction) ]
    end

    def receiver_reference_distance(candidate, message)
      return Float::INFINITY if candidate.created_at.blank? || message.created_at.blank?

      (candidate.created_at - message.created_at).abs
    end

    def shared_return_candidates_for(transaction)
      return [] if transaction.blank?

      CashTransaction.includes(:categories, :cash_installments, :entities, :reference_transactable)
                     .joins(exchanges: :entity_transaction)
                     .where(entity_transactions: { transactable_type: transaction.class.name, transactable_id: transaction.id })
                     .where(exchanges: { exchange_type: Exchange.exchange_types.fetch(:monetary) })
                     .distinct
                     .select(&:exchange_return?)
                     .sort_by { |candidate| [ candidate.created_at || Time.at(0), candidate.id || 0 ] }
    end

    def load_reference_transactable_for(transaction)
      load_polymorphic_reference(transaction.reference_transactable_type, transaction.reference_transactable_id)
    end

    def projection_source_transaction_for(transaction)
      reference_type, reference_id = Exchange.joins(:entity_transaction)
                                             .where(cash_transaction_id: transaction.id)
                                             .pick("entity_transactions.transactable_type", "entity_transactions.transactable_id")

      load_polymorphic_reference(reference_type, reference_id)
    end

    def load_polymorphic_reference(reference_type, reference_id)
      return if reference_type.blank? || reference_id.blank?

      case reference_type
      when "CashTransaction"
        CashTransaction.includes(:reference_transactable, :categories).find_by(id: reference_id)
      when "CardTransaction"
        CardTransaction.includes(:reference_transactable, :categories).find_by(id: reference_id)
      end
    end

    def preload_reference_transactable_categories(messages)
      references_by_class = messages.filter_map(&:reference_transactable).group_by(&:class)

      references_by_class.each_value do |references|
        ActiveRecord::Associations::Preloader.new(records: references, associations: :categories).call
      end
    end

    def receiver_end_transactions_for(source_transaction:, receiver_reference:, intent:)
      return [ receiver_reference ] if source_transaction.is_a?(CardTransaction)
      return [ receiver_reference ] if intent == "reimbursement"

      receiver_exchange_return = shared_return_candidates_for(receiver_reference).first if receiver_reference.present?

      [ receiver_reference, receiver_exchange_return ]
    end

    def end_kind_for(source_transaction, intent)
      return "shared_return" if source_transaction.is_a?(CardTransaction)
      return "shared_return" if intent == "reimbursement"

      "loan_receiver_combo"
    end

    def chain_kind_for(source_transaction, intent)
      return "loan_chain" if end_kind_for(source_transaction, intent) == "loan_receiver_combo"

      "shared_return_chain"
    end

    def serialize_end_transactions(source_transaction:, intent:, middle_transaction:, receiver_reference:, receiver_end_transactions:)
      if end_kind_for(source_transaction, intent) == "loan_receiver_combo"
        [
          serialize_transaction(receiver_reference, expected_reference: middle_transaction, node_key: "receiver_exchange"),
          serialize_transaction(receiver_end_transactions.second, expected_reference: receiver_reference, node_key: "receiver_exchange_return")
        ]
      else
        [ serialize_transaction(receiver_end_transactions.first, expected_reference: middle_transaction, node_key: "receiver_shared_return") ]
      end
    end

    def issues_for(row_chain)
      issues = []
      issues.concat(reference_issues_for(row_chain[:source_node]))
      issues << "multiple_middle_candidates" if row_chain[:middle_candidates].size > 1
      issues << "missing_middle" if row_chain[:middle_candidates].empty?
      issues.concat(reference_issues_for(row_chain[:middle_node]))
      issues << "missing_receiver_reference" if row_chain[:receiver_reference].blank?

      issues.concat(reference_issues_for(row_chain[:end_nodes].first))
      if end_kind_for(row_chain[:source_transaction], row_chain[:intent]) == "loan_receiver_combo"
        issues << "missing_receiver_exchange_return" if row_chain[:end_nodes].second.blank?
        issues.concat(reference_issues_for(row_chain[:end_nodes].second))
      end

      issues
    end

    def serialize_message(message, receiver_context:)
      {
        id: message.id,
        conversation_id: message.conversation_id,
        scenario_key: message.conversation.scenario_key,
        created_at: message.created_at,
        applied_at: message.applied_at,
        actionable: message.actionable_for?(context: receiver_context),
        action: message.action_button_key(local_reference_exists: message.local_reference_for(context: receiver_context).present?).to_s,
        body: message.preview_body
      }
    end

    def serialize_user(user, context: nil)
      return if user.blank?

      {
        id: user.id,
        first_name: user.first_name,
        email: user.email,
        context_id: context&.id,
        context_name: context&.name
      }.compact
    end

    def serialize_transaction(transaction, expected_reference: :__unspecified__, node_key: nil)
      return unless transaction.present?

      expected_reference = nil if expected_reference == :__unspecified__
      current_reference = serialize_reference(transaction.reference_transactable)
      desired_reference = serialize_reference(expected_reference)

      {
        id: transaction.id,
        type: transaction.class.name,
        node_key:,
        user_id: transaction.user_id,
        context_id: transaction.context_id,
        description: transaction.description,
        price: transaction.price,
        date: transaction.date,
        month_year: transaction.try(:month_year),
        category_names: category_names_for(transaction),
        entity_names: transaction.entities.to_a.sort_by(&:entity_name).map(&:entity_name),
        entity_user_ids: transaction.entities.to_a.filter_map(&:entity_user_id).uniq,
        installment_signature: installment_signature(transaction),
        reference_transactable_type: transaction.reference_transactable_type,
        reference_transactable_id: transaction.reference_transactable_id,
        current_reference: current_reference,
        expected_reference: desired_reference,
        reference_status: reference_status_for(current_reference:, expected_reference: desired_reference)
      }
    end

    def serialize_reference(reference)
      return unless reference.present?

      {
        id: reference.id,
        type: reference.class.name,
        description: reference.try(:description),
        user_id: reference.try(:user_id)
      }.compact
    end

    def category_names_for(transaction)
      transaction.categories.to_a.map(&:category_name)
    end

    def reference_status_for(current_reference:, expected_reference:)
      return "ok" if current_reference.blank? && expected_reference.blank?
      return "unexpected" if current_reference.present? && expected_reference.blank?
      return "missing" if current_reference.blank? && expected_reference.present?
      return "ok" if same_reference?(current_reference, expected_reference)

      "mismatch"
    end

    def same_reference?(left, right)
      left.present? &&
        right.present? &&
        left[:type] == right[:type] &&
        left[:id] == right[:id]
    end

    def reference_issues_for(node)
      return [] if node.blank?

      case node[:reference_status]
      when "ok"
        []
      when "missing"
        [ "#{node[:node_key]}_reference_missing" ]
      when "unexpected"
        [ "#{node[:node_key]}_reference_should_be_blank" ]
      else
        [ "#{node[:node_key]}_reference_mismatch" ]
      end
    end

    def serialize_middle_candidates(candidates, source_transaction:)
      candidates.map do |candidate|
        serialize_transaction(candidate, expected_reference: source_transaction, node_key: "middle_candidate")
      end
    end

    def serialize_receiver_candidates(candidates, middle_transaction:)
      candidates.map do |candidate|
        serialize_transaction(candidate, expected_reference: middle_transaction, node_key: "receiver_candidate")
      end
    end

    def proposed_changes_for(*nodes)
      nodes.flatten.compact.filter_map do |node|
        next if node[:reference_status] == "ok"

        {
          node_key: node[:node_key],
          transaction: {
            id: node[:id],
            type: node[:type],
            description: node[:description],
            user_id: node[:user_id]
          }.compact,
          from_reference: node[:current_reference],
          to_reference: node[:expected_reference],
          action: node[:expected_reference].present? ? "set_reference" : "clear_reference"
        }
      end
    end
  end
end
