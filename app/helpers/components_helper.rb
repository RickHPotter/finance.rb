# frozen_string_literal: true

# Helper for Components
module ComponentsHelper
  def input_class
    # 'block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 placeholder-gray-400 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm'
    'peer border-0 rounded-[7px] shadow-md outline-none w-full px-2.5 pb-2.5 pt-3 appearance-none text-sm text-gray-900 transition-all focus:ring-1 focus:ring-indigo-600'
  end

  def label_class
    # 'block text-sm font-medium text-gray-700'
    'absolute top-1 px-2 z-10 bg-white text-sm text-gray-500 duration-300 transform -translate-y-4 scale-75 origin-[0] start-1 peer-focus:text-indigo-600 peer-focus:top-1 peer-focus:scale-100 peer-focus:-translate-y-4 peer-placeholder-shown:scale-100 peer-placeholder-shown:-translate-y-1/2 peer-placeholder-shown:top-2 peer-placeholder-shown:text-sm'
  end

  def form_button_class
    'flex w-full justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2'
  end

  def data_attributes(data)
    data&.map do |key, value|
      "data-#{key.to_s.gsub('_', '-')}=\"#{value}\""
    end&.join(' ')&.html_safe
  end
end
