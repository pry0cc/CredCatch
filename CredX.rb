#!/usr/bin/env ruby

require 'selenium-webdriver'
require 'nokogiri'
require 'json'
require 'optparse'
require 'mechanize'
require 'ruby-progressbar'
require './lib/x.rb'
require './lib/e.rb'

trap "SIGINT" do
  puts "\nBye Bye, thanks for using CredX :)"
  exit 130
end

ARGV << '-h' if ARGV.empty?

options = {}
optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: CredX.rb [options] emails.txt"
  # Define the options, and what they do
  options[:breachpath] = false
  opts.on( '-l', '--breachpath FILE', 'Path of BreachCompliation Location' ) do|file|
    options[:breachpath] = file
  end
    options[:session_id] = false
  opts.on( '-s', '--session TOKEN', 'PHP_SESSION Cookie Value' ) do|session_id|
    options[:session_id] = session_id
  end

  options[:find] = false
  opts.on('--find', 'Scrape Emails using CredE' ) do
    options[:find] = true 
  end

  # Options that are used with the --find flag

    options[:company] = false
    opts.on( '-c', '--company "Company, Inc"', 'Name of Company on LinkedIn' ) do|company|
        options[:company] = company
    end

    options[:domain] = false
    opts.on( '-d', '--domain company.com', 'Domain name used with Email' ) do|domain|
        options[:domain] = domain
    end

    options[:format] = false
    opts.on( '-f', '--format "{first}.{last}@{domain}"', 'Format of email' ) do|email_format|
        options[:format] = email_format
    end

    options[:outfile] = false
    opts.on( '-o', '--outfile emails.txt', 'File to save the results' ) do|outfile|
        options[:outfile] = outfile
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

if options[:session_id]
    @settings["session_id"] = options[:session_id]
    puts "[+] Session key specified! Will pull from WeLeakInfo rather than from BreachCompliation"
else
    @settings["session_id"] = false
end

if options[:find]
    if options[:domain] and options[:company] and options[:format]
        puts "[*] Email Generation Option Selected..."
        puts "[*] Initializing CredE..."
        credE = CredE.new(options[:domain], options[:company], options[:format])
        puts "[+] Starting scan against #{options[:company]}"
        emails = credE.scan()
        puts ""

        # Do Scan with these emails
        if emails.length > 0
            puts "[*] Scan complete! Generated #{emails.length} emails!"
            puts "[*] Initializing CredX...."
            thebot = CredX.new(@settings)   
            puts "[+] Loading #{filename}"
            thebot.ingest_emails(emails)
            puts "[*] Beginning scan"
            thebot.scan_all()
            puts "[*] Scan complete!"
            thebot.get_summary()
            thebot.end()
        else
            puts "[-] Sorry... We couldn't find any emails. Try tweaking the company name."
        end

        if options[:outfile]
            file = File.open(options[:outfile], "w+")
            emails.each do |email|
                file.write(email + "\n")
            end
            file.close
            puts "[+] Emails saved to #{options[:outfile]}"
        end
    else
        puts "[-] You didn't specify enough args"
    end
else
    if File.exist?(filename)
        puts "[*] Initializing CredGet...."
        thebot = CredX.new(@settings)   
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
end
