You will need to set two environment variables, GITHUB_ORG should be the name of your orginization (github.com/orgname/) and GITHUB_TOKEN, follow the steps below to generate a token.

`GITHUB_ORG=your_org GITHUB_TOKEN=your_token ruby git_org_stats.rb`

Generate a token at https://github.com/settings/tokens, give it the full set of repo permissions (Full control of private repositories).

You can also optionally pass the number of weeks to run against, by default its set at 2.

`GITHUB_ORG=your_org GITHUB_TOKEN=your_token ruby git_org_stats.rb 3`
