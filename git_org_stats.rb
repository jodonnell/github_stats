require 'json'
require 'byebug'
require 'date'
require 'net/http'

token = ENV['GITHUB_TOKEN']
org = ENV['GITHUB_ORG']

if ARGV.length > 0
  weeks = ARGV[0].to_i
else
  weeks = 2
end


def make_api_call token, path
  uri = URI("https://api.github.com#{path}")
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "token #{token}"
  puts uri.to_s
  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = true
  http.start
  http.request(req)
end

def make_api_call_and_save_fixture token, path, filename
  status_code = 0
  while status_code != 200 do
    response = make_api_call token, path

    status_code = response.code.to_i
    if status_code == 202
      sleep(5)
    end
  end

  stats = JSON.parse(response.body)
  save_fixture stats, filename
  stats
end

def save_fixture json, filename
  File.open("fixtures/#{filename}", 'w') do |f|
    f.write(json.to_json)
  end
end

def load_fixture filename
  JSON.parse(File.read("fixtures/#{filename}"))
end

def find_all_current_repos token, org
  two_weeks_ago = Date.today - 14
  page_num = 0
  repos_to_check = []

  while true
    page_num += 1
    path = "/orgs/#{org}/repos?page=#{page_num}"
    all_repos = make_api_call_and_save_fixture token, path, "repos-#{page_num}.json"
    # all_repos = load_fixture "repos-#{page_num}.json"

    return repos_to_check if all_repos.length == 0

    all_repos.each do |repo|
      last_pushed = Date.strptime(repo['pushed_at'])

      puts repo['name']
      puts last_pushed
      if last_pushed > two_weeks_ago
        repos_to_check.push(repo['name'])
      end
    end
  end
end


all_stats = {}
repos_stats = {}
total_repo_stats = {}
all_repos = find_all_current_repos token, org
all_repos.each do |repo|
  path = "/repos/#{org}/#{repo}/stats/contributors"
  stats = make_api_call_and_save_fixture token, path, "contributors-#{repo}.json"
  # stats = load_fixture "contributors-#{repo}.json"

  stats.each do |stat|
    author = stat["author"]["login"]
    last_x_weeks = stat["weeks"].last(weeks)

    if not all_stats.key?(author)
      all_stats[author] = { "a" => 0, "d" => 0, "c" => 0 }
    end

    if not total_repo_stats.key?(repo)
      total_repo_stats[repo] = { "a" => 0, "d" => 0, "c" => 0 }
    end

    if not repos_stats.key?(author)
      repos_stats[author] = {}
    end

    if not repos_stats[author].key?(repo)
      repos_stats[author][repo] = last_x_weeks
    end

    weeks.times do |week|
      break if last_x_weeks.length < week + 1
      all_stats[author]["a"] += last_x_weeks[week]["a"]
      all_stats[author]["d"] += last_x_weeks[week]["d"]
      all_stats[author]["c"] += last_x_weeks[week]["c"]

      total_repo_stats[repo]["a"] += last_x_weeks[week]["a"]
      total_repo_stats[repo]["d"] += last_x_weeks[week]["d"]
      total_repo_stats[repo]["c"] += last_x_weeks[week]["c"]
    end
  end
end

all_stats.each { |key, value| value["t"] = value["a"] + value["d"] }
total_repo_stats.each { |key, value| value["t"] = value["a"] + value["d"] }

(total_repo_stats.sort_by {|key, value| value["t"]}).reverse.each do |stat_array|
  repo = stat_array[0]
  stat = stat_array[1]

  puts
  puts repo
  puts "  #{stat['t']}  +#{stat['a']} -#{stat['d']} commits: #{stat['c']}"
end

(all_stats.sort_by {|key, value| value["t"]}).reverse.each do |stat_array|
  author = stat_array[0]
  stat = stat_array[1]

  next if author == 'orcdjenkins'
  next if stat["t"] == 0
  puts
  puts author
  puts "  #{stat['t']}  +#{stat['a']} -#{stat['d']} commits: #{stat['c']}"

  repos_stats[author].each do |repo, weeks|
    weeks_with_commits = weeks.reject do |week|
      week["c"] == 0
    end

    if weeks_with_commits.length > 0
      puts "     #{repo}"

      weeks_with_commits.each do |week|

        parsed_date = Time.at(week["w"]).to_datetime.strftime('%B %d, %Y')
        puts "         #{parsed_date}"
        puts "            +#{week['a']} -#{week['d']} commits: #{week['c']}"
      end
    end
  end
end
