# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def validate_phone_number(phone_number)
  # Remove all non-digit characters from the phone number
  phone_number = phone_number.gsub(/\D/, '')

  # Check the length of the phone number and act accordingly
  case phone_number.length
  when 10
    # If the phone number is 10 digits, assume it's good
    phone_number
  when 11
    # If the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10 digits
    phone_number[0] == '1' ? phone_number[1..] : 'bad number'
  else
    # Otherwise, assume it's a bad number
    'bad number'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_time = []
week_reg_time = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone = validate_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  reg_time << Time.strptime(row[:regdate], '%m/%d/%y %H:%M').hour
  week_reg_time << Time.strptime(row[:regdate], '%m/%d/%y %H:%M').wday
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

peak_day = week_reg_time.tally
p reg_time
hour_counts = reg_time.tally
# peak_hours = hour_counts.select { |_k, v| v == hour_counts.values.max }.keys

hour_counts. sort_by { |_hour_num, value| - value}.each do |hour, value|
  puts " Hour: #{hour} - #{value} registrations "
end

# puts "Peak registration hours: #{peak_hours}"

peak_day.sort_by { |_day_num, value| -value }.each do |day_num, value|
  day = Date::DAYNAMES
  puts "#{day[day_num]}: #{value}"
end

puts "Peak registration day was: #{peak_day}"
