# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-ses'
require 'time'

# Load common helpers
require_relative 'common/email_template'

##
# SendDailySummary Lambda Handler
#
# Sends a daily email summary of location activity
# Triggered by EventBridge schedule (daily at 8 AM PT)
def lambda_handler(event:, context:)
  puts "Daily summary email job starting"
  puts "Event: #{JSON.pretty_generate(event)}"

  send_daily_summary(event, context)
end

def send_daily_summary(event, context)
  # Configuration
  recipient_email = ENV['RECIPIENT_EMAIL'] || 'james.blair@gmail.com'
  sender_email = ENV['SENDER_EMAIL'] || 'noreply@locationtracker.com'
  device_id = ENV['DEVICE_ID']

  unless device_id
    puts "ERROR: DEVICE_ID environment variable not set"
    return error_response('DEVICE_ID not configured', 500)
  end

  # Calculate date range (last 24 hours in Pacific Time)
  pacific_time = Time.now.getlocal('-08:00')  # Pacific Time
  end_time = pacific_time
  start_time = end_time - (24 * 60 * 60)  # 24 hours ago

  puts "Fetching locations from #{start_time} to #{end_time} (Pacific Time)"

  # Fetch locations for the past 24 hours
  locations = fetch_locations(device_id, start_time.utc, end_time.utc)

  puts "Found #{locations.length} locations in the past 24 hours"

  # Generate summary statistics
  summary = generate_summary(locations, start_time, end_time)

  # Generate email HTML
  email_html = EmailTemplate.generate(summary)
  email_text = EmailTemplate.generate_text(summary)

  # Send email via SES
  send_email(
    sender: sender_email,
    recipient: recipient_email,
    subject: "📍 Daily Location Summary - #{pacific_time.strftime('%B %d, %Y')}",
    html_body: email_html,
    text_body: email_text
  )

  {
    statusCode: 200,
    body: JSON.generate({
      success: true,
      message: 'Daily summary email sent',
      locations_count: locations.length,
      recipient: recipient_email
    })
  }

rescue StandardError => e
  puts "ERROR: #{e.message}"
  puts e.backtrace.join("\n")
  error_response(e.message, 500)
end

def fetch_locations(device_id, start_time, end_time)
  result = dynamodb_client.query({
    table_name: table_name,
    key_condition_expression: 'userId = :deviceId AND #ts BETWEEN :start AND :end',
    expression_attribute_names: {
      '#ts' => 'timestamp'
    },
    expression_attribute_values: {
      ':deviceId' => device_id,
      ':start' => start_time.iso8601,
      ':end' => end_time.iso8601
    },
    scan_index_forward: false  # Most recent first
  })

  result.items.map do |item|
    {
      location_id: item['locationId'],
      timestamp: Time.iso8601(item['timestamp']),
      latitude: item['latitude'].to_f,
      longitude: item['longitude'].to_f,
      accuracy: item['accuracy'].to_f,
      altitude: item['altitude'].to_f,
      speed: item['speed'].to_f,
      city: item['city'],
      state: item['state'],
      country: item['country'],
      country_code: item['countryCode']
    }
  end
end

def generate_summary(locations, start_time, end_time)
  # Filter to only geocoded locations
  geocoded = locations.select { |loc| loc[:country] || loc[:city] }

  # Group by state/country
  by_location = geocoded.group_by { |loc| "#{loc[:state] || 'Unknown'}, #{loc[:country] || 'Unknown'}" }

  # Calculate statistics
  locations_visited = by_location.map do |location_name, locs|
    {
      name: location_name,
      visit_count: locs.length,
      first_seen: locs.map { |l| l[:timestamp] }.min,
      last_seen: locs.map { |l| l[:timestamp] }.max
    }
  end.sort_by { |l| -l[:visit_count] }

  {
    start_time: start_time,
    end_time: end_time,
    total_locations: locations.length,
    geocoded_locations: geocoded.length,
    locations_visited: locations_visited,
    primary_location: locations_visited.first
  }
end

def send_email(sender:, recipient:, subject:, html_body:, text_body:)
  ses_client.send_email({
    source: sender,
    destination: {
      to_addresses: [recipient]
    },
    message: {
      subject: {
        data: subject,
        charset: 'UTF-8'
      },
      body: {
        html: {
          data: html_body,
          charset: 'UTF-8'
        },
        text: {
          data: text_body,
          charset: 'UTF-8'
        }
      }
    }
  })

  puts "✅ Email sent to #{recipient}"
rescue Aws::SES::Errors::ServiceError => e
  puts "⚠️  Failed to send email: #{e.message}"
  raise
end

def dynamodb_client
  @dynamodb_client ||= Aws::DynamoDB::Client.new
end

def ses_client
  @ses_client ||= Aws::SES::Client.new
end

def table_name
  ENV['TABLE_NAME'] || raise('TABLE_NAME environment variable not set')
end

def error_response(message, status_code)
  {
    statusCode: status_code,
    body: JSON.generate({
      success: false,
      error: message
    })
  }
end
