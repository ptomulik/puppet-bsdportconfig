module Puppet::Util::Bsdportconfig

  PACKAGE_RE      = /[a-zA-Z0-9][\w\.+-]*/
  VERSION_RE      = /[A-Za-z0-9][\w\.,]*/
  PORT_RE         = /#{PACKAGE_RE}-#{VERSION_RE}/
  ORIGIN_RE       = /#{PACKAGE_RE}\/#{PACKAGE_RE}/
  VERSION_PATTERN = '[A-Za-z0-9][A-Za-z0-9\\.,_]*'
  ONOFF_OPTION_RE = /^\s*OPTIONS_FILE_((?:UN)?SET)\s*\+=(\w+)\s*$/

  PORT_SEARCH_FIELDS = 'name,path'

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

  def parse_package_records(string)

    paragraphs = string.split(/\n\n+/)

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
      record.merge!({:version=>version, :package=>package, :origin=>origin})
      array << record
    end
    array
  end

  def search_ports(key, pattern, portsdir, port_dbdir)
    output = make '-C', portsdir, 'search', "#{key}=#{pattern}", "display=#{PORT_SEARCH_FIELDS}"
    array = parse_package_records(output)
    # augment array with options
    array.each do |record|
      options_files = [ 
        # keep these in proper order ...
        record[:package],               # OPTIONSFILE
        record[:origin].gsub(/\//,'_'), # OPTIONS_FILE
      ].flat_map{|x|
        f = File.join(port_dbdir,x,"options")
        [f,"#{f}.local"]
      }
      options_file = options_files.last
      options = {}
      options_files.each do|f| 
        if File.exists?(f) and File.readable?(f)
          options.merge!(read_options_file(f))
        end
      end
      record[:options_files] = options_files
      record[:options_file] = options_file
      record[:options] = options
    end
    array
  end

  def search_ports_by_port(ports, portsdir, port_dbdir)
    ports = [ports] unless ports.is_a?(Enumerable)
    array = ports.each_slice(20).flat_map {|pslice|
      # query in chunks to keep command-line of reasonable length
      search_ports('name', ports_to_pattern(pslice), portsdir, port_dbdir)
    }
    search_result_to_hash(array, :port)
  end

  def search_ports_by_package(packages, portsdir, port_dbdir)
    packages = [packages] unless packages.is_a?(Enumerable)
    array = packages.each_slice(20).flat_map {|pslice|
      # query in chunks to keep command-line of reasonable length
      search_ports('name', packages_to_pattern(pslice), portsdir, port_dbdir)
    }
    search_result_to_hash(array, :package)
  end

  def search_ports_by_origin(origins, portsdir, port_dbdir)
    origins = [origins] unless origins.is_a?(Enumerable)
    array = origins.each_slice(20).flat_map {|pslice|
      # query in chunks to keep command-line of reasonable length
      search_ports('path', origins_to_pattern(portsdir, pslice), portsdir, port_dbdir)
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

  def build_property_hash(record)
    { 
      :provider     => name, 
      :name         => record[:origin], 
      :port         => record[:port], 
      :options      => record[:options],
      :options_file => record[:options_file],
      :origin       => record[:origin],
    }
  end

  # names must be unique
  def prefetch_property_hashes(names, portsdir, port_dbdir)
    names = [names] unless names.is_a?(Array)

    origins = names.select{|name| name=~/^#{ORIGIN_RE}$/}
    ports_or_packages = names - origins

    records_by_origin = search_ports_by_origin(origins, portsdir, port_dbdir)
    origins -= records_by_origin.keys

    records_by_port = search_ports_by_port(ports_or_packages, portsdir, port_dbdir)
    ports_or_packages -= records_by_port.keys 

    records_by_package = search_ports_by_package(ports_or_packages, portsdir, port_dbdir)
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

  def prefetch_property_hashes_with_options(portsdir, port_dbdir)
    array = search_ports('path', "^#{portsdir}", portsdir, port_dbdir)
    Hash[array.reject{|record| 
      record[:options].empty?
    }.map{|record| 
      [record[:origin], build_property_hash(record)]
    }]
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
