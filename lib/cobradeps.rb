require 'set'
require 'pathname'
require 'graphviz'

module Cbradeps
  require_relative "cobradeps/gemfile_scraper"

  def self.output_text(root_path = nil)
    path = File.expand_path(root_path) || File.expand_path(current_path)
    app = GemfileScraper.new(path)

    outputs "APP"
    outputs app.to_s

    outputs "\n\nDEPENDENCIES"
    cobra_deps = app.cobra_dependencies.to_a

    i = 0
    while (i < cobra_deps.size) do
      dep = cobra_deps[i]
      outputs "\n#{dep[:options][:path]}"
      gem = GemfileScraper.new(dep[:options][:path])
      outputs gem.to_s

      cobra_deps += gem.cobra_dependencies
      i+=1
    end

    outputs "\n\n ALL PARTS"
    outputs cobra_deps.to_a
  end

  def self.output_graph(root_path = nil, filename)
    path = File.expand_path(root_path) || File.expand_path(current_path)
    graph(path).output(:png => "#{filename}.png")
  end

  def self.output_dot(root_path = nil, filename)
    path = File.expand_path(root_path) || File.expand_path(current_path)
    graph(path).output(:dot => "#{filename}.dot")
  end

  def self.current_path
    `pwd`.chomp
  end

  private_class_method :current_path

  def self.graph(path)
    g = GraphViz.new(:G, :type => :digraph, concentrate: true)
    gem_nodes = {}

    app = GemfileScraper.new(path)

    cobra_deps = app.cobra_dependencies.to_a
    around_g = g.add_graph("cluster0", label: app.name)
    start_g = around_g.add_graph("cluster1", { label: "", style: "invis", margin: "0,0" })
    
    i = 0
    cobra_deps.each do |dep|
      gem = GemfileScraper.new(dep[:options][:path])
      gem_nodes[gem.name] = g.add_nodes(gem.name)
      outputs "Added #{gem.name} node"
      if dep[:options][:direct]
        app_node = start_g.add_nodes(app.name + i.to_s)
        i  += 1
        gem_nodes[app.name] = app_node
        app_node.set do |node|
          node.shape = "box"
          node.fixedsize = true;
          node.height = 0
          node.margin = "0,0"
          node.label = ""
          node.style = "invis"
        end
        outputs "Added #{app.name} app"

        # if !has_edge?(g, app_node, gem_nodes[gem.name])
          around_g.add_edges(app_node, gem_nodes[gem.name])
          outputs "Added edge from #{app.name} to #{gem.name}"
        # end
        
      end
    end

    i = 0
    while (i < cobra_deps.size) do
      dep = cobra_deps[i]
      gem = GemfileScraper.new(dep[:options][:path])
      if !gem_nodes.has_key? gem.name
          gem_nodes[gem.name] = around_g.add_nodes(gem.name)
          outputs "Added #{gem.name} node"
      end

      gem_cobra_deps = gem.cobra_dependencies
      gem_cobra_deps.each do |nest_dep|
        nest_gem = GemfileScraper.new(nest_dep[:options][:path])
        if !gem_nodes.has_key? nest_gem.name
          gem_nodes[nest_gem.name] = around_g.add_nodes(nest_gem.name)
          outputs "Added to #{nest_gem.name} node"
        end
        if !has_edge?(g, gem_nodes[gem.name], gem_nodes[nest_gem.name])
          around_g.add_edges(gem_nodes[gem.name], gem_nodes[nest_gem.name]) 
          outputs "Added edge from #{gem.name} to #{nest_gem.name}"
        end
      end
      cobra_deps += gem.cobra_dependencies
      i+=1
    end
    g
  end

  private_class_method :graph

  def self.outputs(arg)
    puts arg
  end

  private_class_method :outputs

  def self.has_edge?(g, node1, node2)
    g.each_edge do |edge|
      if edge.node_one == node1.id && edge.node_two == node2.id
        return true 
      end
    end
    return false
  end
  
  private_class_method :has_edge?
  
  
end
