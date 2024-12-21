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

      indexes = []
      installments = @hash_collection[user_card.user_card_name].each_with_index.map do |transaction, index|
        next if transaction[:installments_count] == 1
        next if transaction[:installments_count] != installments_count
        next if transaction[:ct_description] != transaction_zero[:ct_description]
        next if transaction[:category] != transaction_zero[:category]
        next if transaction[:category2] != transaction_zero[:category2]
        next if transaction[:category2] != transaction_zero[:category2]

        # (ruby) @hash_collection[user_card.user_card_name].select { |a| a[:ct_description] == "SHOPEE" && a[:installments_count] == 3 }.pluck(:category, :category2).uniq
        # [["NEEDS", "MOI"], ["LALA", "EXCHANGE"]]

        # raise StandardError, "Installments counts differ: #{transaction_zero}\n#{transaction}" if transaction[:installments_count] != installments_count

        indexes.push(index)
        # @hash_collection[user_card.user_card_name][index][:status] = :finished

        { number: transaction[:installment_id], price: transaction[:price], month: transaction[:ref_month], year: transaction[:ref_year], date: transaction[:date] }
      end.compact

      if installments.count != installments_count
        transaction_zero_date = transaction_zero[:date]
        transaction_zero_reference = Date.new(2000 + transaction_zero[:ref_year], transaction_zero[:ref_month])

        new_installments = [ installments.shift ]
        installments_count.times do |index|
          pos = new_installments.count
          next_pos = pos + 1
          installment = installments[index]
          installment_date = transaction_zero_date.next_month(next_pos)
          installment_reference = Date.new(2000 + installment[:year], installment[:month])

          next if installment[:number] != next_pos
          next if installment_date != transaction_zero_date.next_month(next_pos)
          next if installment_reference != transaction_zero_reference.next_month(pos)

          new_installments << installment
        end

        installments = new_installments
      end

      debugger if installments.count != installments_count

      indexes.each do |index|
        @hash_collection[user_card.user_card_name][index][:status] = :finished
      end

      validate_installments(transaction_zero, installments)

      installments
    end

    def validate_installments(transaction_zero, installments)
      if transaction_zero[:installments_count] == installments.count
        installments.each_with_index do |installment, index|
          next if installment[:number] == index + 1

          raise StandardError, "Installment number #{installment[:number]} is not #{index + 1}: #{transaction_zero}\n#{installment}"
        end
      else
        first_installment = installments[0]
        reference_date = Date.new(first_installment[:ref_year], first_installment[:ref_month])

        # installments_count.times do |index|
        #   installments <<
        # end

        reference_date.to_date
      end
    end
  end
end
