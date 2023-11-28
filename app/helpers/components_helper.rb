# frozen_string_literal: true

# Helper for Components
module ComponentsHelper
  # @return [String] tailwind class for input
  def input_class
    # 'block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 placeholder-gray-400 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm'
    'peer border-0 rounded-[7px] shadow-md outline-none w-full px-2.5 pb-2.5 pt-3 appearance-none text-sm text-gray-900 transition-all focus:ring-1 focus:ring-indigo-600'
  end

  # @return [String] tailwind class for label
  def label_class
    # 'block text-sm font-medium text-gray-700'
    'absolute top-1 px-2 z-10 bg-white text-sm text-gray-500 duration-300 transform -translate-y-4 scale-75 origin-[0] start-1 peer-focus:text-indigo-600 peer-focus:top-1 peer-focus:scale-100 peer-focus:-translate-y-4 peer-placeholder-shown:scale-100 peer-placeholder-shown:-translate-y-1/2 peer-placeholder-shown:top-2 peer-placeholder-shown:text-sm'
  end

  # @return [String] tailwind class for form button
  def form_button_class
    'flex w-full justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2'
  end

  # This method takes a variable number of hash arguments and converts them into
  # HTML-safe data attributes. It adds the "data-" prefix to keys, replaces
  # underscores with hyphens, and HTML-escapes the values to prevent potential
  # security vulnerabilities related to cross-site scripting (XSS) attacks.
  #
  # @example Generate HTML-safe data attributes
  #   options[:data] = { action: 'click->modal#close' }
  #   data = data_attributes({ form_validate_target: 'field' }, options[:data])
  #
  #   `<div <%= data %>>`
  #   produces
  #   `<div data-form-validate-target="field" data-action="click->modal#close">`
  #
  # @note The resulting String is to be used dynamically in HTML tags for rendering.
  # @note The elements of latter args override elements of former args in case of repetition.
  #
  # @param args [Hash] Variable number of hash arguments containing data attributes.
  #
  # @return [String] HTML_SAFE data attributes converted from hash
  def data_attributes(*args)
    args.compact!
    return {} if args.empty?

    args.flatten!
    data = args.reduce({}, :update)

    data&.map do |key, value|
      "data-#{key.to_s.gsub('_', '-')}=\"#{value}\""
    end&.join(' ')&.html_safe
  end
end
