Puppet::Type.type(:bsdportconfig).provide(:ports) do

  commands :make => '/usr/bin/make'
  confine  :operatingsystem => [ :freebsd, :openbsd, :netbsd ]
  defaultfor :operatingsystem => [ :freebsd, :openbsd, :netbsd ]

  def apply_options
    validate_options
    cur_ops = make_showconfig
    alt_ops = altered_options
    if not alt_ops.empty?
      new_ops = cur_ops.merge alt_ops
      write_config(new_ops)
    end
  end

  def revert_defaults
    run_make('rmconfig')
  end

  def write_config(ops)
    pkg = make_package_name
    opt_names = ops.keys.join(' ')

    content  = "# This file is auto-generated by puppet\n"
    content += "# Options for #{pkg}\n"
    content += "_OPTIONS_READ=#{pkg}\n"
    content += "_FILE_COMPLETE_OPTIONS_LIST=#{opt_names}\n"
    ops.each do |k,v|
      if v =~ /^on$/i
        content += "OPTIONS_FILE_SET+=#{k}\n"
      elsif v =~ /^off$/i
        content += "OPTIONS_FILE_UNSET+=#{k}\n"
      else
        raise Puppet::Error, "Unsupported value #{v} for option #{k}"
      end
    end

    dir = pkgdbdir
    if not File.exists?(dir)
      Dir.mkdir(dir,755)
    end
    File.open("#{dir}/options",'w') { |f| f.write(content) }
  end

  def pkgportdir
    portsdir = @resource[:portsdir]
    name = @resource[:name]
    dir = "#{portsdir}/#{name}"
    if not File.exists?(dir) 
      raise Puppet::Error, "Port directory #{dir}/ does not exist. " + \
        "Check your ports installation."
    elsif not File.directory?(dir)
      raise Puppet::Error, "#{dir} is not a directory."
    end
    return dir
  end

  def pkgdbdir
    dbdir = @resource[:port_dbdir]
    if not File.exists?(dbdir)
      raise Puppet::Error, "Port DB directory #{dbdir} does not exist." + \
        "Check your ports installation."
    end
    dir = dbdir + "/" + @resource[:name].sub(/[^a-zA-Z0-9_-]/,'_')
    return dir
  end

  # run "make -f path/to/port/Makefile target"
  def run_make(target)
    dir = pkgportdir
    cmd = "cd #{dir} && #{command(:make)} #{target}"
    out = execute(cmd)
  end

  # call "make package-name" in the port's directory and extract full name
  def make_package_name
    pkgname = run_make('package-name')
  end

  # call make showconfig on the port and extract current options for package
  def make_showconfig
    opt_str = run_make('showconfig')
    opt_re = /^\s+([a-zA-Z_][a-zA-Z0-9_]+)\s*=\s*([a-zA-Z0-9_]+)\s*:/
    cur_ops = {}
    opt_str.lines.each do |line|
      opt_re.match(line) { |m| cur_ops[m[1]] = m[2] }
    end
    cur_ops
  end

  # select only these user options that change the current settings
  def altered_options
    cur_ops = make_showconfig
    usr_ops = @resource[:options]
    usr_ops.select { |k, v| cur_ops.has_key? k and v != cur_ops[k] }
  end

  def validate_options
    cur_ops = make_showconfig
    usr_ops = @resource[:options]
    raise Puppet::Error, "The options parameter must be a Hash. " + \
      "#{usr_ops.class} provieded." if not usr_ops.is_a? Hash
    unless usr_ops.all? {|k,v| cur_ops.has_key? k}
      inv_ops = usr_ops.clone
      inv_ops = delete_if {|k,v| cur_ops.has_key? k}
      inv_ops = inv_ops.keys.join(", ")
      pkg = make_package_name
      fail ArgumentError, "Invalid option(s) #{inv_ops} for package '#{pkg}'"
    end
  end

end
