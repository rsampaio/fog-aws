module Fog
  module Parsers
    module CDN
      module AWS
        class GetDistributionList < Fog::Parsers::Base
          def reset
            @distribution_summary = { 'CNAME' => [], 'Aliases' => [], 'TrustedSigners' => [], 'Origins' => [] }
            @response = { 'DistributionSummary' => [] }
          end

          def start_element(name, attrs = [])
            super
            case name
            when 'CustomOriginConfig', 'S3Origin'
              @origin = name
              @distribution_summary[@origin] = {}
            when 'Origins'
              @origin_id = true
            when 'Aliases'
              @alias_id = true
            end
          end

          def end_element(name)
            puts "<< #{name}"
            case name
            when 'DistributionSummary'
              @response['DistributionSummary'] << @distribution_summary
              @distribution_summary = { 'CNAME' => [], 'Aliases' => [], 'TrustedSigners' => [], 'Origins' => [] }
            when 'Comment', 'Status', 'DomainName'
              @distribution_summary[name] = value
            when 'Origin'
              @distribution_summary['Origins'] << @origins
              @origins = {}
            when 'Aliases'
              @distribution_summary['Aliases'] << @aliases
              @aliases = []
            when 'Id'
              puts ">> #{name} #{value} #{@origins} << #{origin_id} #{@alias_id}"
              if @origin_id
                @origins[name] = value
              elsif @alias_id
                @aliases[name] = value
              else
                @distribution_summary[name] = value
              end
            when 'CNAME'
              @distribution_summary[name] << value
            when 'DNSName', 'OriginAccessIdentity', 'OriginProtocolPolicy'
              @origins[name] = value
            when 'Enabled'
              if value == 'true'
                @distribution_summary[name] = true
              else
                @distribution_summary[name] = false
              end
            when 'HTTPPort', 'HTTPSPort'
              @origins[name] = value.to_i
            when 'LastModifiedTime'
              @distribution_summary[name] = Time.parse(value)
            when 'IsTruncated'
              if value == 'true'
                @response[name] = true
              else
                @response[name] = false
              end
            when 'Marker', 'NextMarker'
              @response[name] = value
            when 'MaxItems'
              @response[name] = value.to_i
            end
          end
        end
      end
    end
  end
end
