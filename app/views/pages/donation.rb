# frozen_string_literal: true

class Views::Pages::Donation < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag

  include CacheHelper

  def options
    [
      { title: I18n.t("donation.water_title"), subtitle: I18n.t("donation.water_subtitle"), icon: :water, price: "R$ 2.00", qr_code: 2, pix_key: "00020126710014br.gov.bcb.pix013629b7e080-9dc3-40c7-ad5e-6d98ca82182c020930fev.fun52040000530398654042.005802BR5924Luis Henrique da Silva B6008Brasilia62230519daqr1040553619053116304A279" }, # rubocop:disable Layout/LineLength
      { title: I18n.t("donation.coffee_title"), subtitle: I18n.t("donation.coffee_subtitle"), icon: :coffee, price: "R$ 5.00", qr_code: 5, pix_key: "00020126710014br.gov.bcb.pix013629b7e080-9dc3-40c7-ad5e-6d98ca82182c020930fev.fun52040000530398654045.005802BR5924Luis Henrique da Silva B6008Brasilia62230519daqr1040553611954286304B113" }, # rubocop:disable Layout/LineLength
      { title: I18n.t("donation.juice_title"), subtitle: I18n.t("donation.juice_subtitle"), icon: :juice, price: "R$ 10.00", qr_code: 10, pix_key: "00020126710014br.gov.bcb.pix013629b7e080-9dc3-40c7-ad5e-6d98ca82182c020930fev.fun520400005303986540510.005802BR5924Luis Henrique da Silva B6008Brasilia62230519daqr1040553612226516304F748" }, # rubocop:disable Layout/LineLength
      { title: I18n.t("donation.wine_title"), subtitle: I18n.t("donation.wine_subtitle"), icon: :wine, price: "R$ 15.00", qr_code: 15, pix_key: "00020126710014br.gov.bcb.pix013629b7e080-9dc3-40c7-ad5e-6d98ca82182c020930fev.fun520400005303986540515.005802BR5924Luis Henrique da Silva B6008Brasilia62230519daqr10405536124494963042C5F" },  # rubocop:disable Layout/LineLength
      { title: I18n.t("donation.meal_title"), subtitle: I18n.t("donation.meal_subtitle"), icon: :meal, price: "R$ 25.00", qr_code: 25, pix_key: "00020126710014br.gov.bcb.pix013629b7e080-9dc3-40c7-ad5e-6d98ca82182c020930fev.fun520400005303986540525.005802BR5924Luis Henrique da Silva B6008Brasilia62230519daqr10405536128946463046744" },  # rubocop:disable Layout/LineLength
      { title: I18n.t("donation.restaurant_title"), subtitle: I18n.t("donation.restaurant_subtitle"), icon: :restaurant, price: "R$ 50.00", qr_code: 50, pix_key: "00020126710014br.gov.bcb.pix013629b7e080-9dc3-40c7-ad5e-6d98ca82182c020930fev.fun520400005303986540550.005802BR5924Luis Henrique da Silva B6008Brasilia62230519daqr1040553613076856304A164" } # rubocop:disable Layout/LineLength
    ]
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "max-w-4xl mx-auto") do
        div(class: "text-center mb-12") do
          div(class: "inline-flex items-center justify-center w-16 h-16 rounded-full bg-blue-100 text-blue-600 mb-4") do
            cached_icon :support
          end
          h1(class: "text-3xl font-bold text-gray-900 mb-3") do
            I18n.t("donation.title")
          end
          p(class: "text-xl text-gray-600 max-w-2xl mx-auto") do
            I18n.t("donation.subtitle")
          end
        end

        div(class: "mb-8") do
          div(class: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4") do
            options.each do |option|
              div(class: "relative p-6 rounded-xl cursor-pointer bg-white border-2 border-gray-100 hover:border-blue-200 hover:shadow-sm") do
                Sheet do
                  SheetTrigger do
                    div(class: "flex items-center mb-3") do
                      div(class: "w-10 h-10 flex items-center justify-center rounded-full bg-blue-100 text-blue-600 mr-3") do
                        cached_icon option[:icon]
                      end
                      h3(class: "text-lg font-medium text-gray-800") { option[:title] }
                      h3(class: "text-xl font-semibold text-gray-900 ml-auto") { option[:price] }
                    end
                    p(class: "text-gray-600 mb-3 text-sm") do
                      option[:subtitle]
                    end
                  end

                  SheetContent(side: :middle, data: { action: "close->reactive-form#submit" }) do
                    SheetHeader do
                      SheetTitle { I18n.t("donation.complete_donation") }
                    end

                    SheetMiddle do
                      qr_code(option)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def qr_code(option)
    div(class: "min-w-96 hidden md:block p-2") do
      div(class: "text-center mb-6") do
        p(class: "text-gray-600 mb-2") { I18n.t("donation.youre_donating") }

        div(class: "flex items-center justify-center gap-2 mb-1") do
          span(class: "text-2xl font-bold text-blue-600") { option[:price] }
          span(class: "text-lg text-gray-500") { "-" }
          span(class: "text-lg text-gray-700") { option[:title] }
        end
        p(class: "text-gray-500 text-sm") { I18n.t("donation.thank_you") }
      end

      div(class: "flex justify-center") do
        div(class: "flex flex-col items-center") do
          div(class: "w-60 h-60 bg-white p-1 rounded-xl shadow-sm mb-4") do
            cache(option[:qr_code], expires_in: 7.days) do
              render partial "shared/pix_qr_codes/#{option[:qr_code]}"
            end
          end

          div(
            class: "bg-gray-50 p-4 rounded-xl border border-gray-200 shadow-sm mb-4",
            data: { controller: :clipboard, clipboard_success_content_value: I18n.t("donation.copied") }
          ) do
            div(class: "flex items-center gap-3") do
              code(class: "text-lg font-mono text-blue-600 tracking-wider truncate max-w-56", data: { clipboard_target: :source }) do
                option[:pix_key]
              end

              button(
                class: "flex items-center gap-1 p-2 rounded-lg transition-colors bg-gray-100 text-gray-600 hover:bg-gray-200", aria_label: "Copy donation key",
                data: { clipboard_target: :button, action: "clipboard#copy" }
              ) do
                cached_icon :copy
                span { I18n.t("donation.copy") }
              end
            end
          end

          p(class: "text-gray-500 text-sm") { I18n.t("donation.scan_qr_code_or_copy") }
        end
      end
    end
  end
end
