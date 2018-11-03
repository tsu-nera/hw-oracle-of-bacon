require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError; end
  class NetworkError < RuntimeError; end
  class InvalidKeyError < RuntimeError; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri

  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    errors.add(:from, 'From cannot be the same as To') if @from == @to
  end

  def initialize(api_key='')
    @errors = ActiveModel::Errors.new(self)
    @api_key = api_key
    @from = 'Kevin Bacon'
    @to = 'Kevin Bacon'
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
        Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
        Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      raise NetworkError
    end
    OracleOfBacon::Response.new(xml)
  end

  def make_uri_from_arguments
    api_key = CGI.escape(@api_key)
    from = CGI.escape(@from)
    to = CGI.escape(@to)
    @uri = "http://oracleofbacon.org/cgi-bin/xml?p=#{api_key}&a=#{from}&b=#{to}"
  end

  class Response
    attr_reader :type, :data
    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif ! @doc.xpath('//link').empty?
        @type = :graph
        movies = @doc.xpath('//link//movie').map {|x| x.content}
        actors = @doc.xpath('//link//actor').map {|x| x.content}
        @data = actors.zip(movies).flatten().compact()
      elsif ! @doc.xpath('//spellcheck').empty?
        @type = :spellcheck
        @data = @doc.xpath('//spellcheck//match').map {|x| x.content}
      else
        @type = :unknown
        @data = 'unknown response type'
      end
    end

    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end
  end
end
