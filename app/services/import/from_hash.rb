# frozen_string_literal: true

module Import
  class FromHash
    attr_reader :hash_collection, :collection

    def initialize(hash_collection)
      @hash_collection = hash_collection
      @collection = []
    end

    def import
      create_user

      @hash_collection.each do |card, transactions|
        Rails.logger.info "STARTING data creation for card: #{card}"

        user_card_id = create_user_card(card)
        create_transactions(user_card_id, transactions)
      end
    end

    private

    def create_user
      @user = User.find_or_create_by(first_name: "Rikki", last_name: "Potteru", email: "rikki.potteru@mail.com") do |user|
        user.password = "123123"
        user.confirmed_at = Date.current
      end
    end

    def create_user_card(card_name)
      bank = Bank.find_or_create_by(bank_name: card_name, bank_code: card_name.upcase)
      card = Card.find_or_create_by(card_name: card_name, bank:)

      user_card = UserCard.new(user: @user, card:)
      @user.user_cards << user_card

      user_card
    end

    def create_transactions(user_card, transactions)
      transactions.each do |transaction|
        next if transaction[:status] == :finished

        create_params(transaction, user_card)
      end

      # @collection.each { |params| CardTransaction.create(params) }
    end

    def create_params(transaction, user_card)
      if transaction[:installments_count] == 1
        { count: 1 }
      else
        prepare_installments(user_card, transaction)
      end => installments

      price = transaction[:price]
      price = installments.pluck(:price).sum if installments.is_a? Array

      @collection << Params::CardTransactionParamsService.new(card_transaction: { price:, date: transaction[:date], user_id: @user.id, user_card_id: user_card.id },
                                                              installments:,
                                                              category_transactions: [],
                                                              entity_transactions: [])
    end

    def prepare_installments(user_card, transaction_zero)
      installments_count = transaction_zero[:installments_count]

      indexes = @hash_collection[user_card.user_card_name].each_with_index.map do |transaction, index|
        next if transaction[:installments_count] == 1
        next if transaction[:installments_count] != installments_count
        next if transaction[:ct_description] != transaction_zero[:ct_description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:category2] != transaction_zero[:category2]

        index
      end.compact

      case indexes.count <=> installments_count
      when -1
        debugger
        raise StandardError, "There are #{installments_count} installments declared, but only #{indexes.count} were found for #{transaction_zero[:ct_description]}."
      when 0
        indexes.map do |index|
          @hash_collection[user_card.user_card_name][index][:status] = :finished

          transaction = @hash_collection[user_card.user_card_name][index]

          { number: transaction[:installment_id], price: transaction[:price], month: transaction[:ref_month], year: transaction[:ref_year], date: transaction[:date] }
        end
      when 1
        debugger if indexes.count == 32
        indexes.map do |index|
          transaction = @hash_collection[user_card.user_card_name][index]

          next if transaction[:price] - transaction_zero[:price] <= transaction_zero[:price] * 0.06
          next if transaction[:price] - transaction_zero[:price] >= transaction_zero[:price] * 0.06 * -1

          @hash_collection[user_card.user_card_name][index][:status] = :finished

          { number: transaction[:installment_id], price: transaction[:price], month: transaction[:ref_month], year: transaction[:ref_year], date: transaction[:date] }
        end.compact
      end => installments

      @old_installments = installments

      if installments.count != installments_count
        transaction_zero_date = transaction_zero[:date]
        transaction_zero_reference = Date.new(2000 + transaction_zero[:ref_year], transaction_zero[:ref_month])

        new_installments = [ installments.shift ]
        installments.each do |installment|
          pos = new_installments.count
          next_pos = pos + 1

          installment_date = installment[:date]
          installment_reference = Date.new(2000 + installment[:year], installment[:month])

          next if installment[:number] != next_pos
          next if installment_date != transaction_zero_date.next_month(pos)
          next if installment_reference != transaction_zero_reference.next_month(pos)

          new_installments << installment
        end

        installments = new_installments
      end

      installments = installments.sort_by { |installment| installment[:number] }
      debugger if transaction_zero[:ct_description] == "SENDAS" && transaction_zero[:price] == -73.69
      validate_installments(transaction_zero, installments)

      installments
    end

    def validate_installments(transaction_zero, installments)
      if transaction_zero[:installments_count] != installments.count
        debugger
        raise StandardError, "Unable to decipher these installments: #{transaction_zero}\n#{installments}"
      end

      installments.each_with_index do |installment, index|
        raise StandardError, "Installment no. #{installment[:number]} is not #{index + 1}: #{transaction_zero}\n#{installment}" if installment[:number] != index + 1
      end
    end
  end
end
