class CredX

    def initialize(settings)
        @breachcompilation_path = settings["breachcompilation_path"]
        @session_id = settings["session_id"]
        @data = {}
        @data["scanned"] = 0
        @emails = {}
        @summary = {}
        @driver = Selenium::WebDriver.for :firefox
        
        @driver.navigate.to "https://weleakinfo.com/"
        
        wait = Selenium::WebDriver::Wait.new(timeout: 30)
        wait.until { @driver.find_element(name: "query") }
        if @session_id
            self.login(@session_id)
        end
    end

    def login(session_id)
        cookies = @driver.manage.all_cookies()
        cookies.each do |cookie|
            if cookie[:name] == "PHP_SESSION"
                cookie[:value] = session_id
                @driver.manage.delete_cookie("PHP_SESSION")
                @driver.manage.add_cookie(opts = cookie)
            end
        end
        @driver.navigate.to "https://weleakinfo.com/"
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

    def ingest_emails(emails)
        emails.each do |email|
            @emails[email] = []
        end
    end

    def scan_all()
        progressbar = ProgressBar.create(:format => '%a %e %B %p%% %t')
        @data["total"] = @emails.length
        @emails.each do |email, data|
            if @session_id
                res = self.logged_in_search(email, "email")
            else
                res = self.search(email, "email")
            end
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
        sleep 0.2
        @driver.execute_script("window.scrollTo(0,0)")
        sleep 0.5
        @driver.find_element(name: "query").send_keys query
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

    def logged_in_search(query, type)
        element = @driver.find_element(name: "query")
        sleep 0.2
        @driver.execute_script("window.scrollTo(0,0)")
        sleep 0.5

        element.send_keys query

        @driver.find_element(:name, "type").find_element(:css,"option[value='#{type}']").click
        @driver.find_element(:name, "search").click

        src = @driver.page_source
        results = Nokogiri::HTML(src).css(".result")

        breaches = []

        results.each do |result|
            breach = {}
            title = result.css(".panel-title").text.split("Copy to Clipboard")[0]
            breach["title"] = title
            items = result.css("pre").text.split("\n")
            items.each do |item|
                key, value = item.split(": ")
                breach[key] = value
            end
            breaches.push(breach)
        end

        return breaches
    end

end