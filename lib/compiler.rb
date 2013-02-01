require "fileutils"
require "find"
require "open-uri"
require "timeout"
require "uri"
require "yaml"

require "utils"

# TODO: user output to stdout, detailed logs to stderr

module SlugCompiler
  class CompileError < RuntimeError; end

  module_function

  def run(build_dir, buildpack_url, cache_dir)
    @compile_id = rand(2**64).to_s(36) # because UUIDs need a gem

    buildpack_dir = fetch_buildpack(buildpack_url)
    config = buildpack_config(buildpack_url)
    buildpack_name = detect(build_dir, buildpack_dir)
    compile(build_dir, buildpack_dir, cache_dir, config)

    prune(build_dir)
    process_types = parse_procfile(build_dir) || 
      buildpack_processes(build_dir, buildpack_dir)
    slug = archive(build_dir)
    log_size(build_dir, cache_dir, slug)

    slug
  end

  def fetch_buildpack(buildpack_url)
    buildpack_dir = "/tmp/buildpack_#{@compile_id}"

    Utils.log("fetch_buildpack") do
      FileUtils.mkdir_p(buildpack_dir)
      if buildpack_url =~ /\.(tgz|tar\.gz)($|\?)/
        Utils.message("-----> Fetching buildpack... ")
        fetch_tar(buildpack_url, buildpack_dir) rescue fetch_tar(buildpack_url, buildpack_dir)
      else
        Utils.message("-----> Cloning buildpack... ")
        url, treeish = buildpack_url.split("#")
        Utils.clear_var("GIT_DIR") do
          # TODO: sometimes this claims to succeed when it actually doesn't
          Utils.bash("cd #{buildpack_dir}; git clone '#{url}' .", 90)
          Utils.bash("cd #{buildpack_dir}; git checkout #{treeish}") if treeish
        end
      end

      bins = ["compile", "detect", "release"].map { |b|"#{buildpack_dir}/bin/#{b}" }
      FileUtils.chmod(0755, bins.select{|b| File.exists?(b)})
      Utils.message("done\n")
    end

    buildpack_dir
  rescue
    Utils.message("failed\n")
    raise(CompileError, "error fetching custom buildpack")
  end

  def fetch_tar(url, dir)
    Timeout.timeout(90) do
      IO.popen("tar xz -C #{dir}", "w") do |tar|
        IO.copy_stream(open(url), tar)
      end
    end
  end

  def buildpack_config(buildpack_url)
    config = {}
    if query = (buildpack_url && URI.parse(buildpack_url).query)
      query.split("&").each do |kv|
        next if kv.empty?
        k, v = kv.split("=", 2)
        config[k] = URI.unescape(v || "")
      end
    end
    config
  end

  def detect(build_dir, buildpack_dir)
    buildpack_name = Utils.bash("cd #{build_dir}; #{buildpack_dir}/bin/detect #{build_dir} 2>&1").strip
    Utils.message("-----> #{buildpack_name} app detected\n")
    return buildpack_name
  rescue
    raise(CompileError, "no compatible app detected")
  end

  def compile(build_dir, buildpack_dir, cache_dir, config)
    fork do
      # TODO: whilelist existing config
      config.each { |k,v| ENV[k] = v.to_s }
      bin_compile = File.join(buildpack_dir, 'bin', 'compile')
      retval = Utils.spawn("#{bin_compile} #{build_dir} #{cache_dir}", false, 100)
      exit retval
    end
    Process.wait
    raise(CompileError, "failed to compile") if ($?.exitstatus != 0)
  end

  def prune(build_dir)
    FileUtils.rm_rf(File.join(build_dir, ".git"))
    FileUtils.rm_rf(File.join(build_dir, "tmp"))

    Find.find(build_dir) do |path|
      File.delete(path) if File.basename(path) == ".DS_Store"
    end

    prune_slugignore(build_dir)
  end

  def prune_slugignore(build_dir)
    # general pattern format follows .gitignore:
    # http://www.kernel.org/pub/software/scm/git/docs/gitignore.html
    # blank => nothing; leading # => comment
    # everything else is more or less a shell glob
    slugignore_path = File.join(build_dir, ".slugignore")
    return if !File.exists?(slugignore_path)
    Utils.log("process_slugignore") do
      lines = File.read(slugignore_path).split
      total = lines.inject(0) do |total, line|
        line = (line.split(/#/).first || "").strip
        if line.empty?
          total
        else
          globs = if line =~ /\//
                    [File.join(build_dir, line)]
                  else
                    # 1.8.7 and 1.9.2 handle expanding ** differently,
                    # where in 1.9.2 ** doesn't match the empty case. So
                    # try empty ** explicitly
                    ["", "**"].map { |g| File.join(build_dir, g, line) }
                  end

          to_delete = Dir[*globs].uniq.map { |p| File.expand_path(p) }.select { |p| p.match(/^#{build_dir}/) }
          to_delete.each { |p| FileUtils.rm_rf(p) }
          total + to_delete.size
        end
      end
      Utils.message("-----> Deleting #{total} files matching .slugignore patterns.\n")
    end
  end
  
  def parse_procfile(build_dir)
    path = File.join(build_dir, "Procfile")
    return unless File.exists?(path)
    
    File.read(path).split("\n").inject({}) do |ps, line|
      if m = line.match(/^([a-zA-Z0-9_]+):?\s+(.*)/)
        ps[m[1]] = m[2]
      end
      ps
    end
    # TODO: message_procfile
  end

  def buildpack_processes(build_dir, buildpack_dir)
    release = `#{File.join(buildpack_dir, 'bin', 'release')} #{build_dir}`
    YAML.parse(release)["default_process_types"] || {}
  end

  def archive(build_dir)
    slug = "/tmp/slug_#{@compile_id}.tar.gz"
    Utils.log("create_tar_slug") do
      Utils.bash("tar czf #{slug} --xform s,^./,./app/, --owner=root --hard-dereference -C #{build_dir} .")
    end
    return slug
  end

  def log_size(build_dir, cache_dir, slug)
    Utils.log("check_sizes") do
      raw_size = Utils.bash("du -s -x #{build_dir}").split(" ").first.to_i*1024
      cache_size = Utils.bash("du -s -x #{cache_dir}").split(" ").first.to_i*1024 if File.exists? cache_dir
      slug_size = File.size(slug)
      Utils.log("check_sizes at=emit raw_size=#{raw_size} slug_size=#{slug_size} cache_size=#{cache_size}")
      Utils.message(sprintf("-----> Compiled slug size: %1.0fK\n", slug_size / 1024))
    end
  end
end

if __FILE__ == $0
  build_dir, buildpack_url, cache_dir = ARGV
  abort "USAGE: #{$0} BUILD_DIR BUILDPACK_DIR CACHE_DIR" unless ARGV.size == 3 and
    File.exists?(build_dir) and File.exists?(cache_dir) and 
    URI.parse(buildpack_url) rescue false
  SlugCompiler.run(*ARGV)
end
