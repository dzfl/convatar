#!/usr/bin/env ruby

require 'net/http'
require 'pit'
require 'shared-mime-info'
require 'xmlrpc/client'
require 'base64'
require 'digest/md5'
require 'httpclient'


class Convatar
	def initialize(file)
		@image = File.open(file)
		@filename = File::basename(file)
		@extname = File::extname(file)
		@mimetype = MIME.check(file).type
	end

	def run
		twitter
		#gravatar
		hatena
	end

	# hatena.ne.jp
	def hatena
		config = Pit.get("hatena.ne.jp", :require => {
			'username' => "your username in hatena",
			'password' => "your password in hatena",
		})
		c = HTTPClient.new
		c.debug_dev=STDOUT

		# login
		body = { 'name' => config['username'], 'password' => config['password'] }
		res = c.post('https://www.hatena.ne.jp/login', body)

		# delete
		body = { 'delete_profile_image' => 1 }
		res = c.post("https://www.hatena.ne.jp/#{config['username']}/config/profile", body)

		# upload
		body = { 'profile_image' => @image }
		res = c.post("https://www.hatena.ne.jp/#{config['username']}/config/profile", body)

	end

	# don't run
	def gravatar
		config = Pit.get("gravatar.com", :require => {
			'email'    => "your username in gravatar",
			'password' => "your password in gravatar",
		})

		mailhash = Digest::MD5.hexdigest( config["email"].strip.downcase )
		base64 = XMLRPC::Base64.new(@image.readlines.join(''))

		filehash = {
			:name => @filename,
			:bits => base64
		}

		server = XMLRPC::Client.new3("host"=>"secure.gravatar.com", "path"=>"/xmlrpc?user=#{mailhash}", "use_ssl"=>true)
		begin
			#res = server.call2("grav.saveData", { "data" => filehash, "rating" => 0, "password" => config['password'] })
			res = server.call("grav.saveData", { "data" => base64, "rating" => 0, "password" => config['password'] })
			#res = server.call("grav.userimages", { "password" => config['password'] })
		rescue XMLRPC::FaultException => e
			p e.faultCode
			p e.faultString
		end
		puts res
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
			req.basic_auth(config['username'], config['password'])
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

