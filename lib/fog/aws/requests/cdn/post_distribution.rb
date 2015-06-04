module Fog
  module CDN
    class AWS
      class Real
        require 'fog/aws/parsers/cdn/distribution'

        # Create a new distribution in CloudFront.
        #
        # @param options [Hash] Config for distribution.
        #
        #   REQUIRED:
        #   * S3Origin [Hash]:
        #     * DNSName [String] Origin to associate with distribution, ie 'mybucket.s3.amazonaws.com'.
        #     * OriginAccessIdentity [String] Optional: used when serving private content.
        #   or
        #   * CustomOrigin [Hash]:
        #     * DNSName [String] Origin to associate with distribution, ie 'www.example.com'.
        #     * HTTPPort [Integer] Optional HTTP port of origin, in [80, 443] or (1024...65535), defaults to 80.
        #     * HTTPSPort [Integer] Optional HTTPS port of origin, in [80, 443] or (1024...65535), defaults to 443.
        #     * OriginProtocolPolicy [String] Policy on using http vs https, in ['http-only', 'match-viewer'].
        #   OPTIONAL:
        #   * CallerReference [String] Used to prevent replay, defaults to Time.now.to_i.to_s.
        #   * Comment [String] Optional comment about distribution.
        #   * CNAME [Array] Optional array of strings to set as CNAMEs.
        #   * DefaultRootObject [String] Optional default object to return for '/'.
        #   * Enabled [Boolean] Whether or not distribution should accept requests, defaults to true.
        #   * Logging [Hash]: Optional logging config.
        #     * Bucket [String] Bucket to store logs in, ie 'mylogs.s3.amazonaws.com'.
        #     * Prefix [String] Optional prefix for log filenames, ie 'myprefix/'.
        #   * OriginAccessIdentity [String] Used for serving private content, in format 'origin-access-identity/cloudfront/ID'.
        #   * RequiredProtocols [String] Optional, set to 'https' to force https connections.
        #   * TrustedSigners [Array] Optional grant of rights to up to 5 aws accounts to generate signed URLs for private content, elements are either 'Self' for your own account or an AWS Account Number.
        #   * ViewerCertificates [Hash]:
        #     * SSLSupportMethod [String] - SSL Method to support vip or sni-only
        #     * MinimumProtocolVersion [String] - Protocol version TLSv1 or SSLv3
        #     * IAMCertificateId [String] - IAM Certificate ID to use in this distribution
        #
        # @return [Excon::Response]
        #   * body [Hash]:
        #     * DomainName [String] - Domain name of distribution.
        #     * Id [String] - Id of distribution.
        #     * LastModifiedTime [String] - Timestamp of last modification of distribution.
        #     * Status [String] - Status of distribution.
        #     * DistributionConfig [Array]:
        #       * CallerReference [String] - Used to prevent replay, defaults to Time.now.to_i.to_s.
        #       * CNAME [Array] - Array of associated cnames.
        #       * Comment [String] - Comment associated with distribution.
        #       * Enabled [Boolean] - Whether or not distribution is enabled.
        #       * Logging [Hash]:
        #         * Bucket [String] - Bucket logs are stored in.
        #         * Prefix [String] - Prefix logs are stored with.
        #       * Origin [String] - S3 origin bucket.
        #       * TrustedSigners [Array] - Trusted signers.
        #       * DefaultCacheBehavior [Hash]:
        #         * ForwardedValues [Hash]: - Forward Values to distribution destination
        #           * Headers [Hash]:
        #             * Items[Array] - List of Headers to forward
        #           * Cookies [Hash]:
        #             * Forward [Boolean] - Enable cookie forward to the destination
        #           * QueryString [Boolean] - Forward query string to the destination
        #       * ViewerCertificates [Hash]:
        #         * SSLSupportMethod [String] - SSL Method to support vip or sni-only
        #         * MinimumProtocolVersion [String] - Protocol version TLSv1 or SSLv3
        #         * IAMCertificateId [String] - IAM Certificate ID to use in this distribution
        #
        # @see http://docs.amazonwebservices.com/AmazonCloudFront/latest/APIReference/CreateDistribution.html

        def post_distribution(options = {})
          default_cache_behavior = options.delete('DefaultCacheBehavior')
          viewer_certificate = options.delete('ViewerCertificate')
          allowed_methods = options.delete('AllowedMethods')

          options['CallerReference'] = Time.now.to_i.to_s
          data = '<?xml version="1.0" encoding="UTF-8"?>'
          data << "<DistributionConfig xmlns=\"http://cloudfront.amazonaws.com/doc/#{@version}/\">"
          data << ruby_to_xml(options)
          data << ruby_to_xml(default_cache_behavior) if not default_cache_behavior.nil?
          data << ruby_to_xml(viewer_certificate) if not viewer_certificate.nil?
          data << ruby_to_xml(allowed_methods) if not allowed_methods.nil?
          data << "</DistributionConfig>"
          puts data; return
          request({
            :body       => data,
            :expects    => 201,
            :headers    => { 'Content-Type' => 'text/xml' },
            :idempotent => true,
            :method     => 'POST',
            :parser     => Fog::Parsers::CDN::AWS::Distribution.new,
            :path       => "/distribution"
          })
        end

        # Helper function to parse multiple levels of XML
        def ruby_to_xml(options = {})
          data = ''
          for key, value in options
            case value
            when Array
              for item in value
                data << "<#{key}>#{item}</#{key}>"
              end
            when Hash
              data << "<#{key}>"
              for inner_key, inner_value in value
                data << "<#{inner_key}>#{inner_value}</#{inner_key}>"
              end
              data << "</#{key}>"
            else
              data << "<#{key}>#{value}</#{key}>"
            end
          end
          data
        end

      end

      class Mock
        require 'time'

        def post_distribution(options = {})
          if self.data[:distributions].values.any? { |d| (d['CNAME'] & (options['CNAME']||[])).empty? }
            Fog::CDN::AWS::Mock.error(:invalid_argument, 'CNAME is already in use')
          end

          response = Excon::Response.new

          response.status = 201
          options['CallerReference'] = Time.now.to_i.to_s

          dist_id = Fog::CDN::AWS::Mock.distribution_id

          distribution = {
            'DomainName' => Fog::CDN::AWS::Mock.domain_name,
            'Id' => dist_id,
            'Status' => 'InProgress',
            'LastModifiedTime' => Time.now.utc.iso8601,
            'InProgressInvalidationBatches' => 0,
            'DistributionConfig' => {
              'CallerReference' => options['CallerReference'],
              'CNAME' => options['CNAME'] || [],
              'Comment' => options['Comment'],
              'Enabled' => options['Enabled'],
              'Logging' => {
                'Bucket' => options['Bucket'],
                'Prefix' => options['Prefix']
              },
              'S3Origin' => options['S3Origin'],
              'CustomOrigin' => options['CustomOrigin'],
              'TrustedSigners' => options['TrustedSigners'] || [],
              'DefaultCacheBehavior' => options['DefaultCacheBehavior'],
              'ViewerCertificate' => options['ViewerCertificate'],
              'AllowedMethods' => options['AllowedMethods']
            }
          }

          self.data[:distributions][dist_id] = distribution

          response.body = distribution
          response
        end
      end
    end
  end
end
