# frozen_string_literal: true

require 'json'

module Telegram
  module Bot
    class Client
      # Encodes nested hashes and arrays as json and extract File objects from them
      # to the top level. Top-level File objects are handled by httpclient.
      # More details: https://core.telegram.org/bots/api#sending-files
      module RequestBodyFormatter
        extend self

        def format(body, action)
          body = body.dup
          handlers = {
            'sendMediaGroup' => -> { extract_files_from_array!(body, :media) },
            'editMessageMedia' => -> { extract_and_merge!(body, :media) },
            'postStory' => -> { extract_and_merge!(body, :content) },
          }
          handlers[action.to_s]&.call

          body.transform_values! { |v| v.is_a?(Hash) || v.is_a?(Array) ? v.to_json : v }
        end

        private

        def extract_and_merge!(body, field)
          replace_field(body, field) do |value|
            files = {}
            extract_files_from_hash(value, files).tap { body.merge!(files) }
          end
        end

        # Detects field by symbol or string name and replaces it with mapped value.
        def replace_field(hash, field_name)
          field_name = [field_name.to_sym, field_name.to_s].find { |x| hash.key?(x) }
          hash[field_name] = yield hash[field_name] if field_name
        end

        def extract_files_from_array!(hash, field_name)
          replace_field(hash, field_name) do |value|
            break value unless value.is_a?(Array)
            files = {}
            value.map { |x| extract_files_from_hash(x, files) }.
              tap { hash.merge!(files) }
          end
        end

        # Replace File objects with `attach` URIs. File objects are added into `files` hash.
        def extract_files_from_hash(hash, files)
          return hash unless hash.is_a?(Hash)
          hash.transform_values do |value|
            if value.is_a?(File)
              arg_name = "_file#{files.size}"
              files[arg_name] = value
              "attach://#{arg_name}"
            else
              value
            end
          end
        end
      end
    end
  end
end
