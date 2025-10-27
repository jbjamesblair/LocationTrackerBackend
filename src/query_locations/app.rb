# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'time'

# Load common helpers
require_relative 'common/user_helper'
require_relative 'common/response_helper'

##
# QueryLocations Lambda Handler (STUB FOR FUTURE IMPLEMENTATION)
#
# This endpoint is included in the infrastructure but returns 501 Not Implemented
# When ready to implement, uncomment the full implementation below
#
# Expected query parameters:
#   ?startDate=2025-10-01T00:00:00Z&endDate=2025-10-26T23:59:59Z
#   OR
#   ?days=7
def lambda_handler(event:, context:)
  puts "Query locations request received (NOT YET IMPLEMENTED)"
  puts "Event: #{JSON.pretty_generate(event)}"

  # Return 501 Not Implemented for now
  ResponseHelper.error('Query endpoint not yet implemented. Coming soon!', 501)

  # FUTURE IMPLEMENTATION (uncomment when ready):
  # query_locations(event, context)
end

# FUTURE: Full implementation of query functionality
# Uncomment this method when ready to enable querying
def query_locations(event, context)
  # Get user ID
  user_id = UserHelper.get_user_id(event)

  # Parse query parameters
  params = event['queryStringParameters'] || {}

  # Determine date range
  if params['days']
    # Query last N days
    days = params['days'].to_i
    end_date = Time.now.utc
    start_date = end_date - (days * 24 * 60 * 60)
  elsif params['startDate'] && params['endDate']
    # Query specific date range
    start_date = Time.iso8601(params['startDate'])
    end_date = Time.iso8601(params['endDate'])
  else
    # Default: last 30 days
    end_date = Time.now.utc
    start_date = end_date - (30 * 24 * 60 * 60)
  end

  # Query DynamoDB
  locations = fetch_locations(user_id, start_date, end_date)

  # Return results
  ResponseHelper.success({
    success: true,
    count: locations.length,
    locations: locations,
    summary: {
      totalLocations: locations.length,
      dateRange: {
        start: start_date.iso8601,
        end: end_date.iso8601
      }
    }
  })

rescue ArgumentError => e
  ResponseHelper.error('Invalid date format', 400)
rescue StandardError => e
  ResponseHelper.server_error(e)
end

# FUTURE: Fetch locations from DynamoDB
def fetch_locations(user_id, start_date, end_date)
  result = dynamodb_client.query({
    table_name: table_name,
    key_condition_expression: 'userId = :uid AND #ts BETWEEN :start AND :end',
    expression_attribute_names: {
      '#ts' => 'timestamp'
    },
    expression_attribute_values: {
      ':uid' => user_id,
      ':start' => start_date.iso8601,
      ':end' => end_date.iso8601
    },
    scan_index_forward: false  # Most recent first
  })

  # Convert DynamoDB items to simple hash
  result.items.map do |item|
    {
      locationId: item['locationId'],
      timestamp: item['timestamp'],
      latitude: item['latitude'].to_f,
      longitude: item['longitude'].to_f,
      accuracy: item['accuracy'].to_f,
      altitude: item['altitude'].to_f,
      speed: item['speed'].to_f
    }
  end
end

def dynamodb_client
  @dynamodb_client ||= Aws::DynamoDB::Client.new
end

def table_name
  ENV['TABLE_NAME'] || raise('TABLE_NAME environment variable not set')
end
