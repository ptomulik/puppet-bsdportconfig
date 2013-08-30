module Puppet::Util::Bsdportconfig

  PACKAGE_RE      = /[a-zA-Z0-9][\w\.+-]*/
  VERSION_RE      = /[A-Za-z0-9][\w\.,]*/
  PORT_RE         = /#{PACKAGE_RE}-#{VERSION_RE}/
  ORIGIN_RE       = /#{PACKAGE_RE}\/#{PACKAGE_RE}/
  VERSION_PATTERN = '[A-Za-z0-9][A-Za-z0-9\\.,_]*'
  ONOFF_OPTION_RE = /^\s*OPTIONS_FILE_((?:UN)?SET)\s*\+=(\w+)\s*$/

  PORT_OPTION_GROUPS = [
      # NOTE: uncomment if you decide to use option groups
      # :ALL_OPTIONS,
      # :COMPLETE_OPTIONS_LIST,
      # :PORT_OPTIONS,
      # :NEW_OPTIONS,
      # :OPTIONS_MULTI,
      # :OPTIONS_GROUP,
      # :OPTIONS_SINGLE,
      # :OPTIONS_RADIO,
  ]
  PORT_OPTION_FILES = [
    # NOTE: they must be in proper order (cf. /usr/ports/Mk/bsd.options.mk
    # to see in what order options files are sourced).
    :OPTIONSFILE,
    :OPTIONS_FILE,
  ]
  PORT_VARIABLES = PORT_OPTION_GROUPS + PORT_OPTION_FILES

  def escape_pattern(pattern)
    pattern.gsub(/([\.])/) {|c| '\\' + c}
  end

  def pkgstuff_to_pattern(arg)
    if arg.is_a?(Enumerable)
      '(' + arg.map{|p| escape_pattern(p)}.join('|') + ')' 
    else
      escape_pattern(arg)
    end
  end

  def ports_to_pattern(ports)
    "^#{pkgstuff_to_pattern(ports)}$"
  end

  def packages_to_pattern(packages)
    "^#{pkgstuff_to_pattern(packages)}-#{VERSION_PATTERN}$"
  end

  def origins_to_pattern(portsdir, origins)
    "^#{portsdir}/#{pkgstuff_to_pattern(origins)}$"
  end

  def split_port(port)
    parts = port.split('-')
    package = parts.size >= 2 ? parts[0..-2].join('-') : parts.first
    version = parts.size >= 2 ? parts.last : nil
    [package, version]
  end

  def read_options_file(file)
    options = {}
    debug "Scanning file #{file} for port options"
    content = File.open(file) {|f| f.read}
    hash = Hash[content.scan(ONOFF_OPTION_RE).map {|pair|
      [pair[1], pair[0] == 'SET' ? 'on' : 'off']
    }]
    options.merge!(hash)
    options
  end

  def query_port_variables(portdir, variables)
    variables = [variables] unless variables.is_a?(Array)
    varflags = variables.flat_map {|v| ['-V', v] }
    output = make '-C', portdir, varflags
    values = output.lines.map {|s| s.chomp.strip }
    Hash[variables.zip(values)]
  end

  def parse_package_records(string)
    begin
      paragraphs = string.split(/\n\n+/)
    rescue ArgumentError => err
      # try handle non-ascii descriptions ('fr-belote' has them for example)
      raise err unless err.message =~ /invalid byte sequence/
      inenc = 'UTF-8' # assumed ad-hoc
      string.encode!('ASCII', inenc, {:invalid=>:replace, :undef=>:replace})
      paragraphs = string.split(/\n\n+/)
    end

    fn_re = /[A-Za-z0-9_-]+/ # field name
    fv_re = /\S?.*\S/ # field value
    re = /^\s*(#{fn_re})\s*:\s*(#{fv_re})\s*$/

    records = paragraphs.select {|par|
      par.match(/^Port:/) and par.match(/^Path:/) and (not par.match(/^Moved:/))
    }.map {|par|
      par.scan(re)
    }.map {|pairs|
      Hash[pairs.map {|pair| [pair[0].downcase.intern, pair[1]]}]
    }

    array = []
    records.each do |record|
      package, version = split_port(record[:port])
      path = record[:path]
      # origin is same as the tail of port's path (verified on 24360 ports)
      origin = path.split(/\/+/).slice(-2..-1).join('/')

      variables_hash = query_port_variables(path, PORT_VARIABLES)
      PORT_OPTION_GROUPS.each do |key|
        variables_hash[key] = variables_hash[key].split(/\s+/).sort
      end

      options_files = PORT_OPTION_FILES.map{|key|
        variables_hash[key]
      }.reject{|f| f.empty?}.flat_map {|f| [f,"#{f}.local"]}

      if options_files.empty?
        raise Puppet::Error, "failed to determine options_file for '#{record[:origin]}'"
      end

      options_file = options_files.last
      variables_hash[:OPTIONS_FILES] = options_files

      options = {} # options_file doesn't exist yet, treat as empty
      options_files.each do |file|
        if File.file?(file) and File.readable?(file)
          options.merge!(read_options_file(file))
        end
      end

      record.merge!({
        :version       => version,
        :package       => package,
        :origin        => origin,
        :options       => options,
        :options_file  => options_file,
      })
      record.merge!(variables_hash)

      array << record
    end
    array
  end

  def search_ports(key, pattern, portsdir)
    output = make '-C', portsdir, 'search', "#{key}=#{pattern}"
    parse_package_records(output)
  end

  def search_ports_by_port(ports, portsdir)
    ports = [ports] unless ports.is_a?(Enumerable)
    array = ports.each_slice(20).flat_map {|pslice|
      # query in chunks to keep command-line of reasonable length
      search_ports('name', ports_to_pattern(pslice), portsdir)
    }
    search_result_to_hash(array, :port)
  end

  def search_ports_by_package(packages, portsdir)
    packages = [packages] unless packages.is_a?(Enumerable)
    array = packages.each_slice(20).flat_map {|pslice|
      # query in chunks to keep command-line of reasonable length
      search_ports('name', packages_to_pattern(pslice), portsdir)
    }
    search_result_to_hash(array, :package)
  end

  def search_ports_by_origin(origins, portsdir)
    origins = [origins] unless origins.is_a?(Enumerable)
    array = origins.each_slice(20).flat_map {|pslice|
      # query in chunks to keep command-line of reasonable length
      search_ports('path', origins_to_pattern(portsdir, pslice), portsdir)
    }
    search_result_to_hash(array, :origin)
  end

  def search_result_to_hash(array, key)
    hash = {}
    array.each do |record|
      hash[record[key]] ||= []
      hash[record[key]] << record
    end
    hash
  end

  def detect_ambiguous_search_results(records)
    ambiguous = records.select  {|k,records| records.size>1}
    ambiguous.map {|name, records|
      list = records.map{|record| "'#{record[:origin]}'"}.join(', ')
      "#{records.length} ports with name '#{name}': #{list}"
    }
  end

  def scan_options_file_for_port(file)
    debug "Scanning file #{file} for port"
    content = File.open(file,'r') {|f| f.read }
    re1 = /^\s*_OPTIONS_READ\s*=\s*(#{PORT_RE})\s*$/
    re2 = /^#\s*Options for (#{PORT_RE})\s*$/
    port = (m=re1.match(content)).nil? ? nil : m.captures[0]
    port = (m=re2.match(content)).nil? ? nil : m.captures[0] if port.nil?
    port
  end

  def scan_dbdir_for_ports(port_dbdir)
    files = Dir.glob("#{port_dbdir}/*/options") + Dir.glob("#{port_dbdir}/*/options.local")
    ports = Hash[files.map {|file|
      [file, scan_options_file_for_port(file)]
    }.reject {|file,port|
      port.nil?
    }]
  end

  def search_dbdir_for_records(port_dbdir, portsdir)
    hash = scan_dbdir_for_ports(port_dbdir)
    ports = hash.values.uniq
    result = search_ports_by_port(ports, portsdir)

    errors = detect_ambiguous_search_results(result)
    unless errors.empty?
      # It should never happen (unless there is something wrong with search method).
      msg = "Ports search failed (internal error?): found " + errors.join(" and ")
      raise Puppet::Error, msg
    end

    # transpose records to have origins as keys
    result = Hash[ result.map{|k,recs| [recs.first[:origin],recs.first] } ]

    # 'foo-x.y.z' strings stored in options files are often outdated;
    # the corresponding ports may already have different version; 
    # such ports do not appear in 'result' above and we need to perform
    # additional search here to find their updated versions
    missing_ports = ports - result.keys
    missing = hash.select {|file,port| missing_ports.include?(port) }

    packages = missing_ports.map {|port| split_port(port).first }.uniq
    extra_records = search_ports_by_package(packages, portsdir)

    missing.each do |file,port|
      package = split_port(port).first
      if extra_records.include?(package)
        extra_records[package].delete_if {|record|
          cond = record[:OPTIONS_FILES].include?(file)
          result[record[:origin]] = record if cond 
          cond
        }
        if extra_records[package].empty?
          extra_records.delete(package)
        end
      end
    end
    result
  end

  def build_property_hash(record)
    { 
      :provider     => name, 
      :name         => record[:origin], 
      :port         => record[:port], 
      :options      => record[:options],
      :options_file => record[:options_file],
      :origin       => record[:origin],
      :portdir      => record[:path],
    }
  end

  # names must be unique
  def prefetch_property_hashes(names, portsdir)
    names = [names] unless names.is_a?(Array)

    origins = names.select{|name| name=~/^#{ORIGIN_RE}$/}
    ports_or_packages = names - origins

    records_by_origin = search_ports_by_origin(origins, portsdir)
    origins -= records_by_origin.keys

    records_by_port = search_ports_by_port(ports_or_packages, portsdir)
    ports_or_packages -= records_by_port.keys 

    records_by_package = search_ports_by_package(ports_or_packages, portsdir)
    ports_or_packages -= records_by_package.keys

    array = records_by_package.to_a + records_by_port.to_a + records_by_origin.to_a

    errors = []
    missing = origins + ports_or_packages # what's left was not found
    unless missing.empty?
      list = missing.map{|m| "'#{m}'"}.join(', ')
      errors << "the following packages could not be found: #{list}"
    end
    detected = detect_ambiguous_search_results(array)
    unless detected.empty?
      detected[0] = "found #{detected[0]}"
      errors += detected
    end
    unless errors.empty?
      msg = errors.join(' and ')
      raise Puppet::Error, msg
    end

    # at this point we know, that array[i][1].length == 1 for each i
    Hash[ array.map{|key,records| [key, build_property_hash(records[0])]} ]
  end

  def save_options(file, options, port)
    content = "# This file is auto-generated by puppet\n"
    content = "# Options for #{port}\n"
    options.each do |k,v|
      if v =~ /^on$/i
        content += "OPTIONS_FILE_SET+=#{k}\n"
      elsif v =~ /^off$/i
        content += "OPTIONS_FILE_UNSET+=#{k}\n"
      else
        raise Puppet::Error, "Unsupported value #{v} for option #{k}"
      end
    end

    dir = File.dirname(file)
    if not File.exists?(dir)
      dbdir = File.dirname(dir)
      if not File.exists?(dbdir)
        raise Puppet::Error, "Port DB directory #{dbdir}/ does not exist, "
          "check your ports installation"
      elsif not File.directory?(dbdir)
        raise Puppet::Error, "#{dbdir} is not a directory"
      end
      Dir.mkdir(dir,755)
    end
    File.open(file,'w') {|f| f.write(content) }
  end

end
