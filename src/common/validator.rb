# frozen_string_literal: true

##
# Validator - Input validation for location data
module Validator
  # Validate location data from iOS app
  #
  # @param data [Hash] Location data to validate
  # @return [Array<String>] Array of error messages (empty if valid)
  def self.validate_location(data)
    errors = []

    # Required fields
    errors << 'Missing timestamp' unless data['timestamp']
    errors << 'Missing latitude' unless data.key?('latitude')
    errors << 'Missing longitude' unless data.key?('longitude')
    errors << 'Missing accuracy' unless data.key?('accuracy')
    errors << 'Missing altitude' unless data.key?('altitude')
    errors << 'Missing speed' unless data.key?('speed')

    # Validate latitude
    if data['latitude']
      lat = data['latitude']
      unless lat.is_a?(Numeric) && lat >= -90 && lat <= 90
        errors << 'Invalid latitude (must be between -90 and 90)'
      end
    end

    # Validate longitude
    if data['longitude']
      lon = data['longitude']
      unless lon.is_a?(Numeric) && lon >= -180 && lon <= 180
        errors << 'Invalid longitude (must be between -180 and 180)'
      end
    end

    # Validate timestamp format (ISO8601)
    if data['timestamp']
      begin
        Time.iso8601(data['timestamp'])
      rescue ArgumentError
        errors << 'Invalid timestamp format (expected ISO8601)'
      end
    end

    # Validate accuracy (should be positive or -1 for unknown)
    if data['accuracy'] && data['accuracy'].is_a?(Numeric)
      errors << 'Invalid accuracy (must be >= 0)' if data['accuracy'] < 0
    end

    # Validate altitude (reasonable range: -500 to 10000 meters)
    if data['altitude'] && data['altitude'].is_a?(Numeric)
      unless data['altitude'] >= -500 && data['altitude'] <= 10000
        errors << 'Invalid altitude (must be between -500 and 10000 meters)'
      end
    end

    # Validate speed (should be >= 0 or -1 for unknown)
    if data['speed'] && data['speed'].is_a?(Numeric)
      errors << 'Invalid speed (must be >= -1)' if data['speed'] < -1
    end

    errors
  end
end
