#!/usr/bin/env ruby
# Returns a network of projects based on shared developers.
# If two projects share a developer, they are connected with an edge

require 'rubygems'
require 'mongo'
require 'yaml'
require 'github-analysis'

analysis = GithubAnalysis.new
$commits = analysis.commits_col

project_authors = Hash.new
i = 0

# Go through all commits and index authors by project
$commits.find({'commit.id' => {'$exists' => 'true'}},
              :fields => ['commit.url']).each do |c|
  author, project = c['commit']['url'].split(/\//)[1,2]

  if not project_authors.has_key?(author) then
    project_authors[author] = Array.new
  end

  if not project_authors[author].include?(project)
    project_authors[author].push(project) 
  end
  $stderr.print "\rParsing #{i} commits"
  i += 1
end

# Get a list of owners per project
pr_owners = Hash.new
project_authors.each_value do |x|
  x.map do |p|
    pr_owners[p] = analysis.get_project_owner p
  end
end

# Construct adjacency matrix for projects based on author
# sharing. If two projects share an author, they are 'connected',
# except if the owner is the same
project_pairs = Hash.new
project_authors.each_value do |v|
  v.combination(2).to_a.each do |x|
    project_pairs[x[0]] = x[1] if not (project_pairs[x[1]] == x[0] or pr_owners[x[0]] == pr_owners[x[1]])
  end
end

# Index the adjacency matrix, for compatibility with existing
# network processing projects
project_idx = Hash.new
i = 0
project_pairs.each do |k, v|
  (project_idx[k] = i && i+= 1) if not project_idx.has_key? k
  (project_idx[v] = i && i+= 1) if not project_idx.has_key? v
  $stderr.print "\rIndexing #{i}"
end

# Write the index and the adjacency matrix to files
File.open('project-net.pairs', 'w') do |f|
  project_pairs.each do |k, v|
    f.puts "#{project_idx[k]} #{project_idx[v]}"
  end
end

File.open('project-idx.txt', 'w') do |f|
  project_idx.each do |k, v|
    f.puts "#{v} #{k}"
  end
end

File.open('project.dot', 'w') do |f|
  f.puts "graph g{"
  project_pairs.each do |k, v|
    f.puts "\"#{project_idx[k]}\" -- \"#{project_idx[v]}\";"
  end
  f.puts "}"
end