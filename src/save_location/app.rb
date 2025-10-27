# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'securerandom'
require 'time'

# Load common helpers
require_relative 'common/user_helper'
require_relative 'common/response_helper'
require_relative 'common/validator'

##
# SaveLocation Lambda Handler
#
# Receives location data from iOS app and saves to DynamoDB
#
# Expected request body:
# {
#   "timestamp": "2025-10-26T15:30:00Z",
#   "latitude": 37.7749,
#   "longitude": -122.4194,
#   "accuracy": 10.0,
#   "altitude": 15.0,
#   "speed": 0.0
# }
def lambda_handler(event:, context:)
  puts "Processing location save request"
  puts "Event: #{JSON.pretty_generate(event)}"

  # Parse request body
  body = parse_body(event)
  return ResponseHelper.error('Invalid JSON in request body', 400) unless body

  # Get device ID from request body
  device_id = UserHelper.get_device_id(event)
  puts "Device ID: #{device_id}"

  # Validate input
  errors = Validator.validate_location(body)
  return ResponseHelper.validation_error(errors) unless errors.empty?

  # Save to DynamoDB
  location_id = save_location(device_id, body)

  # Return success response
  ResponseHelper.success({
    success: true,
    message: 'Location recorded',
    locationId: location_id
  })

rescue Aws::DynamoDB::Errors::ServiceError => e
  puts "DynamoDB error: #{e.message}"
  ResponseHelper.error('Failed to save location', 500)
rescue StandardError => e
  ResponseHelper.server_error(e)
end

##
# Parse JSON body from event
#
# @param event [Hash] Lambda event
# @return [Hash, nil] Parsed body or nil if invalid
def parse_body(event)
  return nil unless event['body']

  JSON.parse(event['body'])
rescue JSON::ParserError => e
  puts "JSON parse error: #{e.message}"
  nil
end

##
# Save location data to DynamoDB
#
# @param device_id [String] Device identifier
# @param data [Hash] Location data
# @return [String] Location ID (UUID)
def save_location(device_id, data)
  # Generate unique location ID if not provided
  location_id = SecureRandom.uuid

  # Get current server timestamp
  received_at = Time.now.utc.iso8601

  # Prepare DynamoDB item
  item = {
    'userId' => device_id,  # userId field now stores device identifier
    'timestamp' => data['timestamp'],
    'locationId' => location_id,
    'latitude' => data['latitude'],
    'longitude' => data['longitude'],
    'accuracy' => data['accuracy'],
    'altitude' => data['altitude'],
    'speed' => data['speed'],
    'receivedAt' => received_at
  }

  # Add optional geocoding fields if present
  item['city'] = data['city'] if data['city']
  item['state'] = data['state'] if data['state']
  item['country'] = data['country'] if data['country']
  item['countryCode'] = data['countryCode'] if data['countryCode']

  puts "Saving location: #{item}"

  # Write to DynamoDB
  dynamodb_client.put_item({
    table_name: table_name,
    item: item,
    # Prevent overwrites - only insert if this exact timestamp doesn't exist
    condition_expression: 'attribute_not_exists(userId) AND attribute_not_exists(#ts)',
    expression_attribute_names: {
      '#ts' => 'timestamp'
    }
  })

  puts "Location saved successfully: #{location_id}"
  location_id

rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
  # Location with this timestamp already exists - this is OK (idempotent)
  puts "Location with timestamp #{data['timestamp']} already exists (idempotent)"
  location_id
end

##
# Get DynamoDB client (singleton)
#
# @return [Aws::DynamoDB::Client]
def dynamodb_client
  @dynamodb_client ||= Aws::DynamoDB::Client.new
end

##
# Get table name from environment variable
#
# @return [String] DynamoDB table name
def table_name
  ENV['TABLE_NAME'] || raise('TABLE_NAME environment variable not set')
end
