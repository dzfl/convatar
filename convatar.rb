#!/usr/bin/env ruby

require 'net/http'
require 'pit'
require 'shared-mime-info'


class Convatar
	def initialize(file)
		@image = File.open(file)
		@filename = File::basename(file)
		@extname = File::extname(file)
		@mimetype = MIME.check(file).type
	end

	def run
		twitter
	end

	def twitter
		boundary = Time.now.to_i.to_s(16)
		body = ""
		body << "--#{boundary}\r\n"
		body << "Content-Disposition: form-data; name=\"image\"; filename=\"#{@filename}\"\r\n"
		body << "Content-Type: #{@mimetype}\r\n\r\n"
		body << @image.read
		body << "\r\n"
		body << "--#{boundary}--\r\n\r\n"

		config = Pit.get("twitter.com", :require => {
			"username" => "your username in twitter",
			"password" => "your password in twitter",
		})

		url = URI.parse('http://twitter.com/account/update_profile_image.json')

		Net::HTTP.new(url.host, url.port).start do |http| 
			req = Net::HTTP::Post.new(url.request_uri)
			req.basic_auth(config["username"], config["password"])
			req.content_type="multipart/form-data; boundary=#{boundary}"
			req.body=body
			res = http.request(req)
		end
	end

end

if __FILE__ == $0
	if ARGV.size < 1
		puts "ex) convatar.rb /path/to/image.ext"
		exit
	end

	Convatar.new(ARGV[0]).run

end

