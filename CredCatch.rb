#!/usr/bin/env ruby

require 'selenium-webdriver'
require 'nokogiri'
require 'json'
require 'optparse'
require 'ruby-progressbar'


class WeLeakInfo

	def initialize(breachcompilation_path)
		@breachcompilation_path = breachcompilation_path
		@data = {}
		@data["scanned"] = 0
		@emails = {}
		@summary = {}
		@driver = Selenium::WebDriver.for :firefox
		
		@driver.navigate.to "https://weleakinfo.com/"
		
		wait = Selenium::WebDriver::Wait.new(timeout: 30)
		wait.until { @driver.find_element(name: "query") }
	end

	def end()
		@driver.close()
	end

	def load_emails(filename)
		@filename = filename
		f = File.open(filename).read()
		f.split("\n").each do |email|
			@emails[email.gsub("'", "")] = []
		end
	end

	def scan_all()
		progressbar = ProgressBar.create(:format => '%a %e %B %p%% %t')
		@data["total"] = @emails.length
		@emails.each do |email, data|
  			res = self.search(email, "email")
  			@data["scanned"] += 1
  			# puts "Scanned = #{@data["scanned"]} total = #{@data["total"]}"
  			percentage = (@data["scanned"].to_f / @data["total"].to_f) * 100
  			
  			progressbar.progress = percentage
  			@emails[email] = res
		end
	end	

	def get_results_raw()
		return @emails
	end

	def get_summary()
		@emails.each do |email, results|
			if results.length > 0
				@summary[email] = results
			end
		end

		puts "---- Results for #{@filename} ----"

		@summary.each do |email, results|
			puts "\n#{email}"
			results.each do |result|
				puts "--> #{result}"
			end
		end
		puts "-----------------------------------"
	end

	def get_creds(email)

		script = @breachcompilation_path + "/query.sh"
		res = `#{script} #{email} 2>/dev/null`

		creds = []

		res.split("\n").each do | cred |
			creds.push(cred)
		end

		if creds.length < 1
			creds = ""
		end

		return creds
	end

	def search(query, type)
		element = @driver.find_element(name: "query")
		element.send_keys query

		@driver.find_element(:name, "type").find_element(:css,"option[value='#{type}']").click
		@driver.find_element(:name, "search").click

		src = @driver.page_source
		res = Nokogiri::HTML(src).css(".poorfag")
	
		results = []

		res.each do |breach|
			database = breach.css(".database").text

			results.push(database)
		end


		if @breachcompilation_path
			creds = self.get_creds(query)
			if creds != ""
				results.push(creds)
			end
		end

		return results
	end
end

trap "SIGINT" do
  puts "\nBye Bye, thanks for using CredCatch :)"
  exit 130
end

ARGV << '-h' if ARGV.empty?

options = {}
optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: CredCatch.rb [options] emails.txt"
  # Define the options, and what they do
  options[:breachpath] = false
  opts.on( '-l', '--breachpath FILE', 'Path of BreachCompliation Location' ) do|file|
    options[:breachpath] = file
  end
  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

filename = ARGV[0]

if options[:breachpath]
	if File.exist?("settings.json")
		@settings = JSON.parse(File.open("settings.json").read())
		if !File.exist?(@settings["breachcompilation_path"] + "/query.sh")
			@settings["breachcompilation_path"] = false
			puts "That breach compilation path doesn't exist or query.sh doesn't exist. Please check the readme."
		end 
	else
		@settings = {}
		@settings["breachcompilation_path"] = false
	end

else
	@settings = {}
	@settings["breachcompilation_path"] = false
end



if File.exist?(filename)
	puts "[*] Initializing CredGet...."
	if @settings["breachcompilation_path"]
		thebot = WeLeakInfo.new(@settings["breachcompilation_path"])
	else
		thebot = WeLeakInfo.new(false)
	end
	
	puts "[+] Loading #{filename}"
	thebot.load_emails(filename)
	puts "[*] Beginning scan"
	thebot.scan_all()
	puts "[*] Scan complete!"
	thebot.get_summary()
	thebot.end()
else
	puts "Whoops that file doesn't exit..."
end